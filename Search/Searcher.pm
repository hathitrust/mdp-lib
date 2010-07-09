package Search::Searcher;


=head1 NAME

Search::Searcher (searcher)

=head1 DESCRIPTION

This class encapsulates the search interface to Solr/Lucene. It
provides two interfaces.  One to handle user entered queries and one
to handle queries generated internally by the application.

=head1 VERSION

$Id: Searcher.pm,v 1.37 2010/02/18 18:07:24 pfarber Exp $

=head1 SYNOPSIS

my $searcher = new Search::Searcher(30, <<solr_engine URI>>');
my $rs = new Search::Result();

my $query_string = qq{q=*:*&start=0&rows=10&fl=id&indent=on};
$rs = $searcher->get_Solr_raw_internal_query_result($C, $query_string, $rs);

my $id_arr_ref = $rs->get_result_ids();



Coding example

=head1 METHODS

=over 8

=cut

BEGIN {
    if ($ENV{'HT_DEV'}) {
        require "strict.pm";
        strict::import();
    }
}

use LWP::UserAgent;

#use App;
use Context;
use Utils;
use Utils::Time;
use Utils::Logger;
use Debug::DUtils;
use Search::Query;
use Search::Result;

use constant DEFAULT_TIMEOUT => 30; # LWP default

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize Search::Searcher object.

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my $engine_uri = shift;
    my $timeout = shift;


    ASSERT(defined($engine_uri), qq{Missing Solr engine URI});
    $self->{'Solr_engine_uri'} = $engine_uri;
    $self->{'timeout'} = defined($timeout) ? $timeout : DEFAULT_TIMEOUT;
}

# ---------------------------------------------------------------------

=item PRIVATE: __get_timeout

Description

=cut

# ---------------------------------------------------------------------
sub __get_timeout {
    my $self = shift;
    return $self->{'timeout'};
}


# ---------------------------------------------------------------------

=item PRIVATE: __Solr_result

Helper

=cut

# ---------------------------------------------------------------------
sub __Solr_result {
    my $self = shift;
    my ($C, $query_string, $rs) = @_;

    my $url = $self->__get_Solr_select_url($C, $query_string);
    my $req = $self->__get_request_object($url);
    my $ua = $self->__create_user_agent();

    if (DEBUG('query')) {
        my $d = $url;
        Utils::map_chars_to_cers(\$d, [q{"}, q{'}]) if Debug::DUtils::under_server();;
        DEBUG('query', qq{Query URL: $d});
    }
    my ($code, $response, $status_line) = $self->__get_query_response($C, $ua, $req);

    $rs->ingest_Solr_search_response($code, \$response, $status_line);

    return $rs;
}


# ---------------------------------------------------------------------

=item get_Solr_raw_internal_query_result

Description

=cut

# ---------------------------------------------------------------------
sub get_Solr_raw_internal_query_result {
    my $self = shift;
    my ($C, $query_string, $rs) = @_;

    return $self->__Solr_result($C, $query_string, $rs);
}


# ---------------------------------------------------------------------

=item PUBLIC: get_populated_Solr_query_result

Description

=cut

# ---------------------------------------------------------------------
sub get_populated_Solr_query_result {
    my $self = shift;
    my ($C, $Q, $rs) = @_;

    ASSERT(0, qq{get_populated_Solr_query_result() in __PACKAGE__ is pure virtual});
}


# ---------------------------------------------------------------------

=item PRIVATE: __create_user_agent

Description

=cut

# ---------------------------------------------------------------------
sub __create_user_agent {
    my $self = shift;

    my $timeout = $self->__get_timeout();

    # Create a user agent object
    my $ua = LWP::UserAgent->new;
    $ua->agent(qq{MBooks/$::VERSION});
    $ua->timeout($timeout)
        if (defined($timeout));

    return $ua;
}


# ---------------------------------------------------------------------

=item get_collid

Description

=cut

# ---------------------------------------------------------------------
sub get_collid {
    my $self = shift;
    return $self->{'collid'};
}


# ---------------------------------------------------------------------

=item __get_request_object

Description

=cut

# ---------------------------------------------------------------------
sub __get_request_object {
    my $self = shift;
    my $url = shift;

    $url = Encode::encode_utf8($url);
    my $req = HTTP::Request->new(GET => $url);
    return $req;
}


# ---------------------------------------------------------------------

=item get_engine_uri

Description

=cut

# ---------------------------------------------------------------------
sub get_engine_uri {
    my $self = shift;
    return $self->{'Solr_engine_uri'};
}



# ---------------------------------------------------------------------

=item __get_Solr_select_url

Description

=cut

# ---------------------------------------------------------------------
sub __get_Solr_select_url {
    my $self = shift;
    my ($C, $query_string) = @_;

    my $engine_uri = $self->get_engine_uri();
    my $script = $C->get_object('MdpConfig')->get('solr_select_script');
    my $url = $engine_uri . $script . '?' . $query_string;

    return $url;
}



# ---------------------------------------------------------------------

=item PRIVATE: __get_query_response

Description

=cut

# ---------------------------------------------------------------------
sub __get_query_response {
    my $self = shift;
    my ($C, $ua, $req) = @_;
    
    my $res = $ua->request($req);
    my $code = $res->code();
    my $status_line = $res->status_line;
    my $http_status_fail = (! $res->is_success());
    
    # Debug / fail logging
    my $responseDebug = DEBUG('response,idx,all');
    my $otherDebug = DEBUG('idx,all');
    my $Debug = $responseDebug || $otherDebug;
    
    if ($Debug || $http_status_fail) {

        if ($otherDebug) {
            my $u = $req->url();
            Utils::map_chars_to_cers(\$u);
            my $s = qq{__get_query_response: request="$u": status="$code" status_line=} . $status_line;
            DEBUG('idx,all', $s);
        }
        
        if ($responseDebug || $http_status_fail) {
            require Data::Dumper;
            my $d = Data::Dumper::Dumper($res);
            
            if ($http_status_fail) {
                my $sesion_id = 0;
                if ($C->has_object('Session')) {
                    $sesion_id = $C->get_object('Session')->get_session_id();
                }
                my $lg = qq{$ENV{REMOTE_ADDR} $sesion_id $$ } . Utils::Time::iso_Time('time') . qq{ $d};
                #my $app_name = $C->get_object('App')->get_app_name($C);
                Utils::Logger::__Log_string($C, $lg,
                                                 'query_error_logfile', '___QUERY___', 'ls');
            }
            
            Utils::map_chars_to_cers(\$d, [q{"}, q{'}]) if Debug::DUtils::under_server();;
            DEBUG('response', $d);
        }
    }

    if (! $http_status_fail) {
        return ($code, $res->content(), $res->status_line());
    }
    else {
        return ($code, '',  $res->status_line());
    }
}



1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-9 ©, The Regents of The University of Michigan, All Rights Reserved

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
