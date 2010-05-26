package Debug::Email;

=head1 NAME

Debug::Email

=head1 DESCRIPTION

This package implements a subroutine to send debug email.

=head1 VERSION

$Id: Email.pm,v 1.8 2007/11/15 17:43:39 pfarber Exp $

=head1 SYNOPSIS

use Debug::Email;

send_debug_email();

=head1 SUBROUTINES

=over 8

=cut


use Mail::Mailer;
use Debug::DUtils;

#
# Addresses
#
my $g_assert_email_to_addr   = q{dlxs-system@umich.edu};
my $g_assert_email_from_addr = q{"UMDL Mailer" <dlps-help@umich.edu>};

#
# Switch to enable email reports
#
my $g_email_enabled = (! defined($ENV{'UNAVAILABLE'}));

# ---------------------------------------------------------------------

=item send_debug_email

Send email consisting of the output of Carp::longmess, the
environment, the cgi parameters, with a client-supplied message.

=cut

# ---------------------------------------------------------------------
sub send_debug_email
{
    my $msg = shift;

    return if (! $g_email_enabled );

    my $hostname = Utils::get_hostname();
    ($hostname) = ($hostname =~ m,^(\w+)\..*,);

    my $email_subject = qq{[MAFR] MBooks assertion failure ($hostname)};
    my $email_body = Carp::longmess(qq{ASSERTION FAILURE: $msg});

    # CGI params
    $email_body .= qq{\n\nCGI:\n} . CGI::self_url();

    # Environment
    $email_body .= qq{\n\nEnvironment:\n} . Debug::DUtils::print_env();

    my $mailer = new Mail::Mailer('sendmail');
    $mailer->open({
                   'To'      => $g_assert_email_to_addr,
                   'From'    => $g_assert_email_from_addr,
                   'Subject' => $email_subject,
                  });
    print $mailer($email_body);
    $mailer->close;
}




1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007 ©, The Regents of The University of Michigan, All Rights Reserved

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


