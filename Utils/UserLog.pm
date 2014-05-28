package Utils::UserLog;


=head1 NAME

UserLog.pm

=head1 DESCRIPTION

This non-OO package logs activity around useradmin, warn_contact,
register, usercertify, userupdate

=head1 SYNOPSIS

various

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use Exporter;
use base qw(Exporter);

use Utils;
use Utils::Time;


our @EXPORT = qw(__ul_log_event __ul_get_log_filename);

use Utils::Time;

# Logging (to same place as the 'register' app)
sub __ul_get_log_filename {
    my $date = iso_Time('date');
    my $log_filename = $ENV{SDRROOT} . '/logs/register/' . $date . '.log';

    return $log_filename;
}

sub __ul_log_event {
    my $msg_template = shift;
    my $message = shift;

    my $date = iso_Time('date');
    my $log_filename = __ul_get_log_filename();

    my $s = $msg_template;
    my $time = iso_Time();
    
    $s =~ s,__T__,$time,;
    $s =~ s,__E__,$message,;
    $s =~ s,\n,,g;
    
    open(my $fh, '>>', $log_filename);
    chmod 0666, $log_filename;
    print $fh "$s\n";
    close $fh;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2014 ©, The Regents of The University of Michigan, All Rights Reserved

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
