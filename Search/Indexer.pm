package Search::Indexer;

=head1 NAME

Search::Indexer (idxr)

=head1 DESCRIPTION

This class encapsulates the functionality needed to index the Solr
document content produced by a Document subclass.

=head1 SYNOPSIS

my $idxr = new Search::Indexer(<<Solr engine URI>>, [$timeout]);

my ($index_state, $stats_hashref) = $idxr->index_Solr_document($C, $Sol_doc_ref);

To select a non-default engine:

my $idxr = new Search::Indexer('mbooks_solr_DEV_1_engine');

=head1 METHODS

=over 8

=cut

use strict;

use Time::HiRes;
use LWP::UserAgent;

use Context;
use Utils;
use Utils::Logger;
use Debug::DUtils;
use Search::Constants;

use constant DEFAULT_TIMEOUT => 30; # LWP default

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize Search::Indexer object.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;

    my $engine_uri = shift;
    my $timeout = shift;

    ASSERT(defined($engine_uri), qq{Missing Solr engine URI});
    $self->{'Solr_engine_uri'} = $engine_uri;
    $self->{'timeout'} = defined($timeout) ? $timeout : DEFAULT_TIMEOUT;
}


# ---------------------------------------------------------------------

=item PUBLIC: get_solr_engine_uri

Description

=cut

# ---------------------------------------------------------------------
sub get_solr_engine_uri
{
    my $self = shift;
    return $self->{'Solr_engine_uri'};
}


# ---------------------------------------------------------------------

=item PUBLIC:  index_Solr_document

Description

=cut

# ---------------------------------------------------------------------
sub index_Solr_document
{
    my $self = shift;
    my ($C, $Solr_doc_ref) = @_;

    my %stats;
    my $ua = $self->__create_user_agent();
    my $index_state = $self->__update_doc($C, $ua, $Solr_doc_ref, \%stats);

    return ($index_state, \%stats);
}


# ---------------------------------------------------------------------

=item PUBLIC: delete_document

Description

=cut

# ---------------------------------------------------------------------
sub delete_document
{
    my $self = shift;
    my $C = shift;
    my $id = shift;

    my %stats;
    my $index_state = $self->__delete_document($C, $id, \%stats);

    return ($index_state, \%stats);
}


# ---------------------------------------------------------------------

=item PUBLIC: delete_by_query

Description

=cut

# ---------------------------------------------------------------------
sub delete_by_query {
    my $self = shift;
    my $C = shift;
    my $query = shift;

    my %stats;
    my $index_state = $self->__delete_by_query($C, $query, \%stats);

    return ($index_state, \%stats);
}

# ---------------------------------------------------------------------

=item PUBLIC: delete_index

Description

=cut

# ---------------------------------------------------------------------
sub delete_index
{
    my $self = shift;
    my $C = shift;

    my %stats;
    my $success = $self->__delete_index($C, \%stats);

    return ($success, \%stats);
}


# ---------------------------------------------------------------------

=item PUBLIC:  commit_updates

Description

=cut

# ---------------------------------------------------------------------
sub commit_updates
{
    my $self = shift;
    my $C = shift;

    my %stats;
    my $index_state = $self->__commit_updates($C, \%stats);

    return ($index_state, \%stats);
}




# ---------------------------------------------------------------------

=item PUBLIC: optimize

Description

=cut

# ---------------------------------------------------------------------
sub optimize {
    my $self = shift;
    my $C = shift;
    my $segments = shift;

    my %stats;
    my $index_state = $self->__optimize_index($C, \%stats, $segments);

    return ($index_state, \%stats);
}


# ---------------------------------------------------------------------

=item PRIVATE: __create_user_agent

When OCR index gets large timeouts occur with the default 180
sec. during commits and optimizations.

=cut

# ---------------------------------------------------------------------
sub __create_user_agent
{
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

=item __get_timeout

Description

=cut

# ---------------------------------------------------------------------
sub __get_timeout
{
    my $self = shift;

    return $self->{'timeout'};
}


# ---------------------------------------------------------------------

=item PRIVATE: __get_request_object

Description

=cut

# ---------------------------------------------------------------------
sub __get_request_object
{
    my $self = shift;
    my $url = shift;
    my $content_ref = shift;

    my $req = HTTP::Request->new(POST => $url);

    $req->header('Content-type' => 'Content-type:text/xml; charset=utf-8');
    # Prevent "wide character in syswrite" error in LWP.
    $$content_ref = Encode::encode_utf8($$content_ref);
    
    $req->content_ref($content_ref);

    return $req;
}


# ---------------------------------------------------------------------

=item __response_handler

Description

=cut

# ---------------------------------------------------------------------
sub __response_handler
{
    my $self = shift;
    my ($C, $response) = @_;

    my $index_state;
    my $success = $response->is_success;
    my $code = $response->code();
    my $status_line = $response->status_line();

    if ($success)
    {
        $index_state = IX_INDEXED;
        DEBUG('idx', qq{DEBUG: INDEXER: Good HTTP response: $code status=} . $response->status_line());
    }
    else
    {
        my $s = qq{Solr error response: code=$code, status="$status_line"\n} 
            . $response->content();
        Utils::Logger::__Log_simple($s);
        DEBUG('idx', qq{DEBUG: INDEXER: Bad HTTP response: $code status=} . $response->status_line() . q{ (see logfile)} );

        if ($code =~ m,^5\d\d,)
        {
            # Some kind of foobar
            if ($status_line =~ m,reset by peer,is)
            {
                # Bad data server couldn't process
                $index_state = IX_INDEX_FAILURE;
            }
            elsif ($status_line =~ m,timeout,is)
            {
                # Server took too long to respond.  Could be merging,
                # or committing or the doc could be huge.  This is not
                # a failure unless it happens a few more times for
                # this item.
                $index_state = IX_INDEX_TIMEOUT;
            }
            elsif (($status_line =~ m,Can't connect,is) || ($status_line =~ m,not currently available,is))
            {
                # Server down
                $index_state = IX_SERVER_GONE;
            }
            else
            {
                # Something we've not seen yet
                $index_state = IX_INDEX_FAILURE;
            }
        }
        else
        {
            # Some other non-good event. Treat as a failure.
            $index_state = IX_INDEX_FAILURE;
        }
    }
    
    return $index_state;
}

# ---------------------------------------------------------------------

=item PRIVATE: __update_doc

Description

=cut

# ---------------------------------------------------------------------
sub __update_doc
{
    my $self = shift;
    my ($C, $ua, $data_ref, $stats_ref) = @_;

    my $url = $self->__get_Solr_post_update_url($C);
    my $req = $self->__get_request_object($url, $data_ref);

    my $start = Time::HiRes::time();

    # Here be HTTP 
    my $response = $ua->request($req);

    my $elapsed = Time::HiRes::time() - $start;
    $$stats_ref{'update'}{'elapsed'} = $elapsed;
    ($$stats_ref{'update'}{'qtime'}) = ($response->{_content} =~ m,<int name="QTime">(.*?)</int>,);

    my $index_state = $self->__response_handler($C, $response);

    return $index_state;
}


# ---------------------------------------------------------------------

=item PRIVATE: __delete_document



=cut

# ---------------------------------------------------------------------
sub __delete_document
{
    my $self = shift;
    my $C = shift;
    my $id = shift;
    my $stats_ref = shift;

    my $ua = $self->__create_user_agent();
    my $url = $self->__get_Solr_post_update_url($C);
    my $post_data = qq{<delete><id>$id</id></delete>};
    my $req = $self->__get_request_object($url, \$post_data);

    my $start = Time::HiRes::time();
    my $response = $ua->request($req);
    my $elapsed = Time::HiRes::time() - $start;

    $$stats_ref{'delete'}{'elapsed'} = $elapsed;

    my $index_state = $self->__response_handler($C, $response);

    DEBUG('idx', qq{Index DELETE DOCUMENT FAILURE response: index_state=$index_state status=} . $response->status_line)
        if (Search::Constants::indexing_failed($index_state));

    return $index_state;
}


# ---------------------------------------------------------------------

=item PRIVATE: __delete_by_query



=cut

# ---------------------------------------------------------------------
sub __delete_by_query {
    my $self = shift;
    my $C = shift;
    my $query = shift;
    my $stats_ref = shift;

    my $ua = $self->__create_user_agent();
    my $url = $self->__get_Solr_post_update_url($C);
    my $post_data = qq{<delete><query>$query</query></delete>};
    my $req = $self->__get_request_object($url, \$post_data);

    my $start = Time::HiRes::time();
    my $response = $ua->request($req);
    my $elapsed = Time::HiRes::time() - $start;

    $$stats_ref{'delete'}{'elapsed'} = $elapsed;

    my $index_state = $self->__response_handler($C, $response);

    DEBUG('idx', qq{Index DELETE BY QUERY FAILURE response: index_state=$index_state status=} . $response->status_line)
        if (Search::Constants::indexing_failed($index_state));

    return $index_state;
}

# ---------------------------------------------------------------------

=item PRIVATE: __delete_index



=cut

# ---------------------------------------------------------------------
sub __delete_index
{
    my $self = shift;
    my $C = shift;
    my $stats_ref = shift;

    my $ua = $self->__create_user_agent();
    my $url = $self->__get_Solr_post_update_url($C);
    my $post_data = qq{<delete><query>*:*</query></delete>};
    my $req = $self->__get_request_object($url, \$post_data);

    my $start = Time::HiRes::time();
    my $response = $ua->request($req);
    my $elapsed = Time::HiRes::time() - $start;

    $$stats_ref{'delete'}{'elapsed'} = $elapsed;

    my $index_state = $self->__response_handler($C, $response);

    DEBUG('idx', qq{Index DELETE FAILURE response: index_state=$index_state status=} . $response->status_line)
        if (Search::Constants::indexing_failed($index_state));

    return $index_state;
}


# ---------------------------------------------------------------------

=item PRIVATE: __commit_updates

called by indexing scripts

=cut

# ---------------------------------------------------------------------
sub __commit_updates
{
    my $self = shift;
    my $C = shift;
    my $stats_ref = shift;

    my $ua = $self->__create_user_agent();
    my $url = $self->__get_Solr_post_update_url($C);
    my $post_data = qq{<commit/>};
    my $req = $self->__get_request_object($url, \$post_data);

    my $start = Time::HiRes::time();
    my $response = $ua->request($req);
    my $elapsed = Time::HiRes::time() - $start;

    $$stats_ref{'commit'}{'elapsed'} = $elapsed;

    my $index_state = $self->__response_handler($C, $response);

    DEBUG('idx', qq{Index COMMIT FAILURE response: index_state=$index_state status=} . $response->status_line)
        if (Search::Constants::indexing_failed($index_state));

    return $index_state;
}


# ---------------------------------------------------------------------

=item PRIVATE: __optimize_index

called by indexing scripts

=cut

# ---------------------------------------------------------------------
sub __optimize_index
{
    my $self = shift;
    my $C = shift;
    my $stats_ref = shift;
    my $segments = shift;
    
    my $ua = $self->__create_user_agent();
    my $url = $self->__get_Solr_post_update_url($C);
    my $segs;
    if ($segments > 1) {
        $segs = qq{ maxSegments="$segments"};
    }
    
    my $post_data = qq{<optimize$segs/>};
    my $req = $self->__get_request_object($url, \$post_data);

    my $start = Time::HiRes::time();
    my $response = $ua->request($req);
    my $elapsed = Time::HiRes::time() - $start;

    $$stats_ref{'optimize'}{'elapsed'} = $elapsed;

    my $index_state = $self->__response_handler($C, $response);

    DEBUG('idx', qq{Index OPTIMIZE FAILURE response: index_state=$index_state status=} . $response->status_line)
        if (Search::Constants::indexing_failed($index_state));

    return $index_state;
}

# ---------------------------------------------------------------------

=item PRIVATE: __get_Solr_post_update_url

Description

=cut

# ---------------------------------------------------------------------
sub __get_Solr_post_update_url
{
    my $self = shift;
    my $C = shift;

    my $engine_uri = $self->get_solr_engine_uri();
    my $script = $C->get_object('MdpConfig')->get('solr_update_script');
    my $url = $engine_uri . $script;

    return $url;
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
