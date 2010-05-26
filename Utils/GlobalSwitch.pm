package Utils::GlobalSwitch;


=head1 NAME

Utils::GlobalSwitch

=head1 DESCRIPTION

This package encapsulates functions that (mostly cron) client code can
call to test whether to run or not.  Nasically, a switch to indicate
maintenence is in progress.

=head1 VERSION

$Id: GlobalSwitch.pm,v 1.11 2009/10/01 17:47:47 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

# Fast way to turn things off without touching files
my $CRON_JOBS_DISABLED = 0;
# Fast way to enable cron jobs if files have been touched
my $GlobalSwitch_ignore_STOP_files = 0;

sub Exit_If_cron_jobs_disabled {
    my $script = shift;

    my $SITE_ADDR = `hostname -i`;

    # clamato
    return
        if ($SITE_ADDR =~ m,141\.211\.175\.37,s);

    exit 0
        if (cron_jobs_disabled($script));
}

sub cron_jobs_disabled {    
    my $script = shift;
    
    # If the STOP files are ignored, cron jobs are enabled
    return 0
        if ($GlobalSwitch_ignore_STOP_files);
    
    return (
            $CRON_JOBS_DISABLED
            ||
            (
             (-e "/sdr1/etc/l/ls/$script")
             ||
             (-e "/l1/etc/l/ls/$script")
            )
           );
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2009 ©, The Regents of The University of Michigan, All Rights Reserved

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
