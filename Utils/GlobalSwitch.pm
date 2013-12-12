package Utils::GlobalSwitch;


=head1 NAME

Utils::GlobalSwitch

=head1 DESCRIPTION

This package encapsulates functions that (mostly cron) client code can
call to test whether to run or not.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut
umask 0000;

use strict;

# Fast way to turn things off without touching files
my $CRON_JOBS_DISABLED = 0;
# Fast way to enable cron jobs if files have been touched
my $GlobalSwitch_ignore_STOP_files = 0;

my %app2file_map =
  (
   'slip' => 'STOPSLIP',
  );

sub Exit_If_cron_jobs_disabled {
    my $app = shift;

    exit 0
        if (cron_jobs_disabled($app));
}

sub cron_jobs_disabled {
    my $app = shift;

    # If the STOP files are ignored, cron jobs are enabled
    return 0
        if ($GlobalSwitch_ignore_STOP_files);

    my $file = $app2file_map{$app};
    return (
            $CRON_JOBS_DISABLED
            ||
            (-e "$ENV{SDRROOT}/$app/etc/$file")
           );
}

sub stop_file_name {
    my $app = shift;

    my $file = $app2file_map{$app};
    return "$ENV{SDRROOT}/$app/etc/$file";
}

sub disable_cron_jobs {
    my $app = shift;

    # If the STOP files are ignored, cron jobs are enabled
    return 0
        if ($GlobalSwitch_ignore_STOP_files);

    my $file = $app2file_map{$app};
    `touch "$ENV{SDRROOT}/$app/etc/$file"`;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2009-12 ©, The Regents of The University of Michigan, All Rights Reserved

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
