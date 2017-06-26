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

use MdpConfig;
use Utils::UserLog;

use JSON::XS qw(encode_json decode_json);

{
    package JIRA::Client;
    use base qw(LWP::UserAgent);

    use JSON::XS qw(encode_json);
    use LWP::UserAgent;
    use HTTP::Request;
    use Data::Dumper;

    sub new {
        my $self = LWP::UserAgent::new(@_);
        $self->agent("lwp-request/$LWP::VERSION ");
        $self;
    }

    sub post {
        my $self = shift;
        my %options = @_;
        $options{method} = 'POST';
        return $self->request(%options);
    }

    sub request {
        my $self = shift;
        my %options = @_;

        my $uri = $options{service};
        $uri .= "/issue/" unless ( $options{action} eq 'search' );
        $uri .= "$options{ticket}" if ( $options{ticket} );
        $uri .= "/$options{action}" if ( $options{action} );
        my $method = $options{method} || 'GET';

        my $req = HTTP::Request->new($method, $uri);
        $req->authorization_basic($options{user}, $options{password});
        $req->header('Content-Type' => 'application/json');

        if ( $options{body} ) {
            my $json = encode_json($options{body});
            $req->content($json);
        }

        my $ua = LWP::UserAgent->new;
        return $ua->request($req);
    }

}

# ---------------------------------------------------------------------

=item __check_fault

Description

=cut

# ---------------------------------------------------------------------
sub __check_fault {
    my $res = shift;
    
    unless ( $res->is_success ) {
        my $s = "ERROR: " . $res->request->as_string . "\n";
        if ( $res->code == 401 ) {
            # unauthorized
            $s .= "UNAUTHORIZED\n";
        } elsif ( $res->header('Content-Type') =~ m,application/json, ) {
            my $content = decode_json($res->decoded_content);
            $s .= join("\n", @{ $$content{errorMessages} });
        } else {
            $s .= $res->as_string  . "\n";
        }
        __ul_log_event($s);
        die $s;
    }

    # decode the JSON
    return decode_json($res->decoded_content);
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
        __ul_log_event($s);
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
    
    my $endpoint = $config->get('jira_rest_endpoint');
    my $service = $endpoint;

    my ($user, $passwd) = __get_JIRA_user_passwd();

    return ( service => $service, user => $user, password => $passwd );
}

# ---------------------------------------------------------------------

=item comment_JIRA_ticket

Description

=cut

# ---------------------------------------------------------------------
sub comment_JIRA_ticket {
    my ($config, $ticket, $comment) = @_;

    my %config = __get_JIRA_connection($config);
    # POSSIBLY NOTREACHED

    my $service = JIRA::Client->new();
    my %options = ( action => 'comment', ticket => $ticket, body => { body => $comment }, %config );
    __check_fault( $service->post(%options) ) ;

    # POSSIBLY NOTREACHED
}

# ---------------------------------------------------------------------

=item get_JIRA_ticket_info

Description

=cut

# ---------------------------------------------------------------------
sub get_JIRA_ticket_info {
    my ($config, $ticket) = @_;

    my %config = __get_JIRA_connection($config);
    # POSSIBLY NOTREACHED

    my $service = JIRA::Client->new();
    my %options = ( ticket => $ticket, %config );

    __check_fault( $service->request(%options) ) ;
    # POSSIBLY NOTREACHED
}

# ---------------------------------------------------------------------

=item create_JIRA_ticket

Description

=cut

# ---------------------------------------------------------------------
sub create_JIRA_ticket {
    my ($config, $project, $ticket_summary, $description) = @_;

    my %config = __get_JIRA_connection($config);
    # POSSIBLY NOTREACHED

    my $service = JIRA::Client->new();
    my %options = ( 
        body => {
            fields => {
                project => {
                    key => $project
                },
                summary => $ticket_summary,
                description => $description,
                issuetype => {
                    name => "General"
                }
            }
        }, 
        %config 
    );
    my $resp = __check_fault( $service->post(%options) ) ;
    return $$resp{key};
}

sub search_JIRA {
    my ($config, $query, $maxResults) = @_;

    my %config = __get_JIRA_connection($config);
    # POSSIBLY NOTREACHED

    my $service = JIRA::Client->new();
    my %options = ( 
        action => 'search',
        body => {
            maxResults => ( $maxResults || 10 ),
            startAt => 0,
            fields => [ "id", "key" ],
            jql => $query
        }, 
        %config 
    );
    my $resp = __check_fault( $service->post(%options) ) ;
    return $resp;
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
