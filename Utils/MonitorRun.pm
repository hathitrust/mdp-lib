package Utils::MonitorRun;

=head1 NAME

Utils::MonitorRun

=head1 DESCRIPTION

Run a subprocess with IPC::Run and extract/report statistics as it runs and
as it exits.

=head1 SYNOPSIS

Utils::MonitorRun::run_with_stats(...)

This takes the same arguments as IPC::Run::run, but will periodically dump
stats about the process.

=head1 METHODS

=over 8

=cut

use strict;
use parent qw(IPC::Run);
use POSIX;

sub dumpstats {
  my $self = shift;

  my $total_utime;
  my $total_stime;

  foreach my $kid (@{$self->{KIDS}}) {
    my $pid = $kid->{PID};

    # don't clobber exit status in the calling context
    local $?;
    if (-e "/proc/$pid/stat") {
      open(my $statfh, "<", "/proc/$pid/stat") or warn("Can't open /proc/$pid/stat $!");
      # see proc(5) (man 5 proc) for field definitions
      my @fields = split(' ',<$statfh>);
      my $status = $fields[2];
      # only want to gather further stats if the process has just exited and we
      # need to wait for it
      next unless $status eq 'Z' and !$kid->{gotstats};

      my $clock_ticks = POSIX::sysconf( &POSIX::_SC_CLK_TCK );
      my $utime = $fields[13] / $clock_ticks;
      my $stime = $fields[14] / $clock_ticks;
      $self->{stats}{utime} += $utime;
      $self->{stats}{stime} += $stime;

      my $iostats = `sudo -n /usr/local/bin/catprocio $pid`;
      if($iostats) {
        foreach my $line (split("\n",$iostats)) {
          my ($k, $v) = split(": ",$line);
          if($self->{stats}{$k}) {
            $self->{stats}{$k} += $v;
          } else {
            $self->{stats}{$k} = $v;
          }
        }
      }

      $kid->{gotstats} = 1;
    }
  }

}

sub run_with_stats {
  my $h = IPC::Run::start(@_);
  # IPC::Run::start is not a real constructor and can't deal with subclasses,
  # but still returns an object, so do some monkey business here and re-bless
  # into the subclass
  bless($h, "Utils::MonitorRun");
  $h->{stats} = {};
  $h->{stats}{utime} = 0;
  $h->{stats}{stime} = 0;

  $h->dumpstats();
  $h->finish();
  return $h->{stats};
}

sub reap_nb {
  my $self = shift;

  $self->dumpstats();

  return $self->SUPER::reap_nb;
}

1;
