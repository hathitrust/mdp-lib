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

  foreach my $kid (@{$self->{KIDS}}) {
    my $pid = $kid->{PID};
    print STDERR "DUMPING STATS for $kid->{PATH} $pid\n";

    # don't clobber exit status in the calling context
    local $?;
    if (-e "/proc/$pid/stat") {
      open(my $statfh, "<", "/proc/$pid/stat") or warn("Can't open /proc/$pid/stat $!");
      # see proc(5) (man 5 proc) for field definitions
      my @fields = split(' ',<$statfh>);
      my $status = $fields[2];
      my $clock_ticks = POSIX::sysconf( &POSIX::_SC_CLK_TCK );
      my $utime = $fields[13] / $clock_ticks;
      my $stime = $fields[14] / $clock_ticks;
      # only want to gather further stats if the process has just exited and we
      # need to wait for it
      print STDERR "$pid status $status utime $utime stime $stime\n";
      next unless $status eq 'Z';
      system("ls -l /proc/$pid/io");
      # TODO sudo cat /proc/$pid/io
      # TODO can we get better (cumulative child) user/system time via getrusage than via /proc?
    }
  }

}

sub run_with_stats {
  my $h = IPC::Run::start(@_);
  # IPC::Run::start is not a real constructor and can't deal with subclasses,
  # but still returns an object, so do some monkey business here and re-bless
  # into the subclass
  bless($h, "Utils::MonitorRun");

  $h->dumpstats();
  print STDERR "in run_with_stats; finishing\n";
  return $h->finish();
}

sub reap_nb {
  my $self = shift;

  print STDERR "in reap_nb, gathering io stats\n";
  $self->dumpstats();

  return $self->SUPER::reap_nb;
}

1;
