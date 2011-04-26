package Search::Result;


=head1 NAME

Search::Result (rs)

=head1 DESCRIPTION

This class encapsulates an  Search::Searcher search result.  It's
subclasses represent various ways of packaging that response.

=head1 VERSION

$Id: Result.pm,v 1.20 2009/08/10 20:03:49 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use Utils;


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

Initialize Search::Result object.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;

    # Subclass:
    $self->AFTER_Result_initialize(@_);
}



# ---------------------------------------------------------------------

=item AFTER_Result_initialize

Subclass Initialize Search::Result object.

=cut

# ---------------------------------------------------------------------
sub AFTER_Result_initialize
{
    ASSERT(0, qq{AFTER_Result_initialize() in __PACKAGE__ is pure virtual});
}

# ---------------------------------------------------------------------

=item ingest_Solr_search_response

Example Solr result is:

<response>
  <lst name="responseHeader">
    <int name="status">0</int>
    <int name="QTime">1</int>
    <lst name="params">
      <str name="fl">id,score</str>
      <str name="fq">id:(4 43 46)</str>
      <str name="q">camp</str>
      <str name="rows">1000000</str>
    </lst>
  </lst>
  <result name="response" numFound="3" start="0" maxScore="0.02694472">
    <doc>
       <float name="score">0.02694472</float>
       <str name="id">43</str>
    </doc>

    [...]
  </result>
</response>


=cut

# ---------------------------------------------------------------------
sub ingest_Solr_search_response
{
    my $self = shift;
    my ($code, $Solr_response_ref, $status_line, $failed_HTTP_dump) = @_;

    my $http_status_ok = ($code eq '200');

    my ($max_score, $num_found, $query_time) = (0, 0, 0.0);

    if ($http_status_ok)
    {
        # QTime (query time in milliseconds)
        ($query_time) = ($$Solr_response_ref =~ m,<int name="QTime">(.*?)</int>,);
        $query_time = sprintf("%.3f", $query_time/1000);

        # Max score
        ($max_score) = ($$Solr_response_ref =~ m,maxScore="(.*?)",);
        $max_score = $max_score ? $max_score : 0.0;

        # Hits
        ($num_found) = ($$Solr_response_ref =~ m,numFound="(.*?)",);
        $num_found = $num_found ? $num_found : 0;
    }

    $self->{'http_status_ok'} = $http_status_ok;
    $self->{'response_code'} = $code;
    $self->{'status_line'} = $status_line;
    $self->{'query_time'} = $query_time;
    $self->{'max_score'} = $max_score;
    $self->{'num_found'} = $num_found;
    # May be overridden for queries that limit by rows
    $self->{'rows_returned'} = $num_found;
    $self->{'failed_HTTP_dump'} = $failed_HTTP_dump;

    # In Subclass:
    if ($http_status_ok)
    {
        $self->AFTER_ingest_Solr_search_response($Solr_response_ref);
    }
}



# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

Uses Template Design patten to invoke subclass-specific Solr response
parsing.  Must be implemented in Subclass.

=cut

# ---------------------------------------------------------------------
sub AFTER_ingest_Solr_search_response
{
    my $self = shift;
    my $Solr_response_ref = shift;

    ASSERT(0, qq{AFTER_ingest_Solr_search_response() in __PACKAGE__ is pure virtual});
}



# ---------------------------------------------------------------------

=item get_failed_HTTP_dump

Description

=cut

# ---------------------------------------------------------------------
sub get_failed_HTTP_dump
{
    my $self = shift;
    return $self->{'failed_HTTP_dump'};
}


# ---------------------------------------------------------------------

=item get_status_line

Description

=cut

# ---------------------------------------------------------------------
sub get_status_line
{
    my $self = shift;
    return $self->{'status_line'};
}


# ---------------------------------------------------------------------

=item http_status_ok

Description

=cut

# ---------------------------------------------------------------------
sub http_status_ok
{
    my $self = shift;
    return $self->{'http_status_ok'};
}

# ---------------------------------------------------------------------

=item get_rows_returned

Description

=cut

# ---------------------------------------------------------------------
sub get_rows_returned
{
    my $self = shift;
    return $self->{'rows_returned'};
}

# ---------------------------------------------------------------------

=item get_total_hits

Description

=cut

# ---------------------------------------------------------------------
sub get_total_hits
{
    my $self = shift;
    return $self->{'num_found'};
}

# ---------------------------------------------------------------------

=item get_num_found

Description

=cut

# ---------------------------------------------------------------------
sub get_num_found
{
    my $self = shift;
    return $self->{'num_found'};
}

# ---------------------------------------------------------------------

=item get_max_score

Description

=cut

# ---------------------------------------------------------------------
sub get_max_score
{
    my $self = shift;
    return $self->{'max_score'};
}

# ---------------------------------------------------------------------

=item get_query_time

in milliseconds

=cut

# ---------------------------------------------------------------------
sub get_query_time
{
    my $self = shift;
    return $self->{'query_time'};
}
# ---------------------------------------------------------------------

=item get_response_code

Description

=cut

# ---------------------------------------------------------------------
sub get_response_code
{
    my $self = shift;
    return $self->{'response_code'};
}


# ---------------------------------------------------------------------

=item set_complete_result

Description

=cut

# ---------------------------------------------------------------------
sub set_complete_result
{
    my $self = shift;
    my $arr_ref = shift;
    $self->{'complete_result'} = $arr_ref;
}

# ---------------------------------------------------------------------

=item get_complete_result

Description

=cut

# ---------------------------------------------------------------------
sub get_complete_result
{
    my $self = shift;
    return $self->{'complete_result'};
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
