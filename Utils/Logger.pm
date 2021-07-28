package Utils::Logger;


=head1 NAME

Logger.pm

=head1 DESCRIPTION

This non-OO package logs indexing stats

=head1 VERSION

$Id: Logger.pm,v 1.6 2009/12/21 22:04:49 pfarber Exp $

=head1 SYNOPSIS

various

=head1 METHODS

=over 8

=cut

use strict;

use Utils;
use Utils::Time;

use Context;
use MdpConfig;
use Semaphore;

use Time::HiRes;


# ------- Configuration variables --------
our $logging_enabled = 1;

# ---------------------------------------------------------------------

=item __get_logdir_root

Description

=cut

# ---------------------------------------------------------------------
sub __get_logdir_root
{
    return $ENV{'SDRROOT'}; 
}


# ---------------------------------------------------------------------

=item __Log_string

Description

=cut

# ---------------------------------------------------------------------
use constant MAX_TRIES => 10;

sub __Log_string {
    my $C = shift;
    my $s = shift;
    my $logfile_key = shift;
    my $optional_dir_pattern = shift;
    my $optional_dir_key = shift;
    my $optional_logfile_pattern = shift;
    my $optional_logfile_key = shift;

    return unless ( $logging_enabled );

    my $config = ref($C) eq 'Context' ? $C->get_object('MdpConfig') : $C;

    my $logdir = __get_logdir_root() . $config->get('logdir');
    if (defined($optional_dir_key) && defined($optional_dir_pattern)) {
        $logdir =~ s,$optional_dir_pattern,$optional_dir_key,;
    }

    my $logfile = $config->get($logfile_key);
    my $date = Utils::Time::iso_Time('date');
    $logfile =~ s,___DATE___,-$date,;
    if (defined($optional_logfile_key) && defined($optional_logfile_pattern)) {
        $logfile =~ s,$optional_logfile_pattern,$optional_logfile_key,;
    }
    $logfile .= qq{.$ENV{SERVER_ADDR}};
    $logfile .= qq{.$$};
    
    Utils::mkdir_path($logdir);

    my $logfile_path = $logdir . '/' . $logfile;

    # # Obtain an exclusive lock to protect access to the logfile when
    # # multiple producers are writing to the logfile for the same shard
    # # my $lock_file = $logfile_path . '.sem';
    # my $lock_file = "/ram/" . $logfile . ".sem";

    # # --- BEGIN CRITICAL SECTION ---
    # my $sem;
    # my $tries = 0;
    # while (! ($sem = new Semaphore($lock_file))) {
    #     $tries++;
    #     return if ($tries > MAX_TRIES);
    #     Time::HiRes::sleep(0.5);
    # }

    if (open(LOG, ">>:encoding(UTF-8)", $logfile_path)) {
        LOG->autoflush(1);
        print LOG qq{$s\n};
        close(LOG);
        chmod(0666, $logfile_path) if (-o $logfile_path);
    }

    # $sem->unlock();
    # --- END CRITICAL SECTION ---
}

sub __Log_struct {
    my $C = shift;
    my $message = shift;
    my $logfile_key = shift;
    my $optional_dir_pattern = shift;
    my $optional_dir_key = shift;
    my $optional_logfile_pattern = shift;
    my $optional_logfile_key = shift;

    return unless ( $logging_enabled );

    # get the singleton
    unless ( ref $C ) { $C = new Context; }

    if ( $$message[0][0] ne 'datetime' ) {
        unshift @$message, ['datetime', Utils::Time::iso_Time()];
    }

    require JSON::XS;
    my $json = JSON::XS->new()->utf8(1)->allow_nonref(1);
    my $s = '{';
    while ( scalar @$message ) {
        my $kv = shift @$message;
        my ( $key, $value ) = @$kv;
        my $suffix = scalar @$message ? "," : "";
        $s .= sprintf(qq{%s:%s%s}, $json->encode($key), $json->encode($value), $suffix)
    }
    $s .= '}';

    __Log_string($C, $s, $logfile_key, $optional_dir_pattern, $optional_dir_key, $optional_logfile_pattern, $optional_logfile_key);

}

sub __Log_benchmark {
    my ( $C, $message, $app_name ) = @_;
    __Log_struct($C, 
        $message, 
        'benchmark_logfile', 
        qr(slip/run-___RUN___|___QUERY___), 'benchmark',
        qr(___APP_NAME___), $app_name);
}

# ---------------------------------------------------------------------

=item __Log_simple

Description

=cut

# ---------------------------------------------------------------------
sub __Log_simple {
    my $s = shift;
    return unless ( $logging_enabled );


    my $date = Utils::Time::iso_Time('date');
    my $time = Utils::Time::iso_Time('time');
    my $logfile = qq{MDP-generic-$date.log.$ENV{SERVER_ADDR}};

    my $logfile_path = Utils::get_tmp_logdir() . "/$logfile";
    if (open(LOG, ">>:encoding(UTF-8)", $logfile_path)) {
        LOG->autoflush(1);
        print LOG qq{$time: $s\n};
        close(LOG);
        chmod(0666, $logfile_path) if (-o $logfile_path);
    }
    
    return $logfile_path;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008 ©, The Regents of The University of Michigan, All Rights Reserved

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
