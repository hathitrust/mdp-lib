package Debug::Email;

=head1 NAME

Debug::Email

=head1 DESCRIPTION

This package implements a subroutine to send debug email.

=head1 SYNOPSIS

use Debug::Email;

send_debug_email();

=head1 SUBROUTINES

=over 8

=cut

use Utils::Time;
use Mail::Mailer;
use Debug::DUtils;

#
# Addresses NOTE: Must coordinate with mdp-misc/scripts/email-monitor.pl
#
my $g_assert_email_to_addr   = q{hathitrust-system@umich.edu};
my $g_assert_email_from_addr = q{"HathiTrust Mailer" <dlps-help@umich.edu>};
my $g_email_archive_dir      = qq{$ENV{SDRROOT}/logs/assert};
my $g_email_file             = qq{$g_email_archive_dir/hathitrust-email-digest-current};
my $g_email_subject          = qq{[MAFR] HathiTrust assert fail};

#
# Switch to enable email reports
#
my $g_email_enabled = (! defined($ENV{'UNAVAILABLE'}));


# ---------------------------------------------------------------------

=item __email_msg_core

Description

=cut

# ---------------------------------------------------------------------
sub __email_msg_core {
    my $msg = shift;

    return (undef, undef) if (! $g_email_enabled );

    # Limit client message to 2K.
    $msg = substr($msg, 0, 2048);

    my $hostname = Utils::get_hostname();
    ($hostname) = ($hostname =~ m,^(.*?)\..*$,);
    my $when = Utils::Time::iso_Time();

    my $email_subject = $g_email_subject . qq{ ($hostname)($when)};
    my $email_body = Carp::longmess(qq{ASSERTION FAILURE: $msg});

    # CGI params
    $email_body .= qq{\n\nCGI:\n} . CGI::self_url();

    # Environment
    $email_body .= qq{\n\nEnvironment:\n} . Debug::DUtils::print_env();

    return ($email_subject, $email_body);
}

# ---------------------------------------------------------------------

=item send_debug_email

Send email consisting of the output of Carp::longmess, the
environment, the cgi parameters, with a client-supplied message.

=cut

# ---------------------------------------------------------------------
sub send_debug_email {
    my $msg = shift;

    my $return if (! $g_email_enabled );

    my ($email_subject, $email_body) = __email_msg_core($msg);
    if (defined($email_body)) {
        my $mailer = new Mail::Mailer('sendmail');
        $mailer->open({
                       'To'      => $g_assert_email_to_addr,
                       'From'    => $g_assert_email_from_addr,
                       'Subject' => $email_subject,
                      });
        print $mailer($email_body);
        $mailer->close;
    }
}


# ---------------------------------------------------------------------

=item buffer_debug_email

Buffer email consisting of the output of Carp::longmess, the
environment, the cgi parameters, with a client-supplied message.

=cut

# ---------------------------------------------------------------------
sub buffer_debug_email {
    my $msg = shift;

    return if (! $g_email_enabled );

    my ($email_subject, $email_body) = __email_msg_core($msg);
    if (defined($email_body)) {
        my $e = $email_subject . "\n\n" . $email_body . "\n";

        use File::Path;
        if (! -e $g_email_archive_dir) {
            File::Path::mkpath( $g_email_archive_dir );
        }

        if (open(OUTFILE, ">>:utf8", $g_email_file)) {
            print OUTFILE $e;
            close(OUTFILE);
        }
    }
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-11 ©, The Regents of The University of Michigan, All Rights Reserved

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


