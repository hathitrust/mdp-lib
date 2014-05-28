package JIRA;


=head1 NAME

JIRA

=head1 DESCRIPTION

This package supports JIRA ticket comments and creation

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


use strict;
use warnings;

use SOAP::Lite;
use MdpConfig;
use Utils::UserLog;

# ---------------------------------------------------------------------

=item __check_fault

Description

=cut

# ---------------------------------------------------------------------
sub __check_fault {
    my $res = shift;
    my $service = shift;
    
    if ( defined $res->fault() ) {
        my $s = "ERROR: \n" . $service->createIssueResponse . "\n" . $res->faultstring() . "\n";
        __log_event($s);
        die $s;
    }

    return $res->result();
}


# ---------------------------------------------------------------------

=item __get_JIRA_user_passwd

Description

=cut

# ---------------------------------------------------------------------
sub __get_JIRA_user_passwd {

    my $_prod_file = q{/htapps/babel/etc/ht_jira.conf};
    my $_test_file = q{/htapps/test.babel/etc/ht_jira.conf};

    my $JIRA_Conf_File = $ENV{HT_DEV} ? $_test_file : $_prod_file;

    unless (-e $JIRA_Conf_File) {
        my $s = "Config file=$JIRA_Conf_File missing";
        __log_event($s);
        die $s;
    }

    my $config = new MdpConfig($JIRA_Conf_File);

    my $jira_user   = $config->get('jira_user');
    my $jira_password = $config->get('jira_password');

    return ($jira_user, $jira_password);
}

# ---------------------------------------------------------------------

=item __get_JIRA_connection

Description

=cut

# ---------------------------------------------------------------------
sub __get_JIRA_connection {
    my $config = shift;
    
    my $endpoint = $config->get('jira_soap_endpoint');
    my $service = SOAP::Lite->proxy($endpoint);

    my ($user, $passwd) = __get_JIRA_user_passwd();

    my $token = __check_fault( $service->login($user, $passwd), $service );
    # POSSIBLY NOTREACHED

    return ($service, $token);
}

# ---------------------------------------------------------------------

=item comment_JIRA_ticket

Description

=cut

# ---------------------------------------------------------------------
sub comment_JIRA_ticket {
    my ($config, $ticket, $comment) = @_;

    my ($service, $token) = __get_JIRA_connection($config);
    # POSSIBLY NOTREACHED

    __check_fault( $service->addComment($token, $ticket, SOAP::Data->type( RemoteComment => {body => $comment} )), $service );
    # POSSIBLY NOTREACHED

   $service->logout;
}

# ---------------------------------------------------------------------

=item create_JIRA_ticket

Description

=cut

# ---------------------------------------------------------------------
sub create_JIRA_ticket {
    my ($config, $project, $ticket_summary, $description) = @_;

    my ($service, $token) = __get_JIRA_connection($config);
    # POSSIBLY NOTREACHED

    # Build JIRA RemoteIssue XML format (as below)
    use constant TYPE_GENERAL => 12;

    my $issue = {
                 'project'     => SOAP::Data->type('string' => $project),
                 'summary'     => SOAP::Data->type('string' => $ticket_summary),
                 'type'        => SOAP::Data->type('string' => TYPE_GENERAL),
                 'description' => SOAP::Data->type('string' => $description),
                };

    # Create issue, catch exceptions and logout
    my $ticket = __check_fault( $service->createIssue($token, $issue), $service );
    # POSSIBLY NOTREACHED
    
    my $ticket_number = $ticket->{key};

    $service->logout;

    return $ticket_number;
}


1;

__END__

=back

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
