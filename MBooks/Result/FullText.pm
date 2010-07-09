package MBooks::Result::FullText;


=head1 NAME

MBooks::Result::FullText (rs)

=head1 DESCRIPTION

This class does encapsulates the Solr search response data.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use Utils;

use Search::Result;
use base qw(Search::Result);


# ---------------------------------------------------------------------

=item AFTER_Result_initialize

Subclass Initialize MBooks::Result::FullText object.

=cut

# ---------------------------------------------------------------------
sub AFTER_Result_initialize
{
    my $self = shift;
    my $collid = shift;

    $self->{'collid'} = $collid;
}


# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

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
sub AFTER_ingest_Solr_search_response
{
    my $self = shift;
    my $Solr_response_ref = shift;

    my @coll_ids = ();
    my (@result_ids, %result_score_hash);

    # Coll_ids
    my ($coll_id_fields) = ($$Solr_response_ref =~ m,<arr name="coll_id">(.*?)</arr>,s);
    @coll_ids = ($coll_id_fields =~ m,<long>(.*?)</long>,gs);
    $self->__set_result_coll_ids(\@coll_ids);

    # Ids
    @result_ids = ($$Solr_response_ref =~ m,<long name="id">(.*?)</long>,g);

    # Relevance scores
    my @result_scores = ($$Solr_response_ref =~ m,<float[^>]+>(.*?)</float>,g);
    for (my $i=0; $i < scalar(@result_ids); $i++)
    {
        $result_score_hash{$result_ids[$i]} = $result_scores[$i];
    }

    $self->__set_result_ids(\@result_ids);
    $self->{'result_scores'} = \%result_score_hash;
}



# ---------------------------------------------------------------------

=item PRIVATE: __set_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub __set_result_ids
{
    my $self = shift;
    my $arr_ref = shift;
    $self->{'result_ids'} = $arr_ref;
}


# ---------------------------------------------------------------------

=item PRIVATE: __set_result_coll_ids

Description

=cut

# ---------------------------------------------------------------------
sub __set_result_coll_ids
{
    my $self = shift;
    my $arr_ref = shift;
    $self->{'result_coll_ids'} = $arr_ref;
}


# ---------------------------------------------------------------------

=item get_collid

Description

=cut

# ---------------------------------------------------------------------
sub get_collid
{
    my $self = shift;
    return $self->{'collid'};
}


# ---------------------------------------------------------------------

=item get_result_coll_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_result_coll_ids
{
    my $self = shift;
    return $self->{'result_coll_ids'};
}

# ---------------------------------------------------------------------

=item get_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_result_ids
{
    my $self = shift;
    return $self->{'result_ids'};
}


# ---------------------------------------------------------------------

=item get_result_scores

Description

=cut

# ---------------------------------------------------------------------
sub get_result_scores
{
    my $self = shift;
    return $self->{'result_scores'};
}

# ---------------------------------------------------------------------

=item remove_result_ids_for

Used to keep the Result object member data synchronized with the
DELETE or MOVE operation eliminating the need to redo a search to
re-display the search result list following the DELETE or MOVE.

=cut

# ---------------------------------------------------------------------
sub remove_result_ids_for
{
    my $self = shift;
    my $collid = shift;
    my $id_arr_ref = shift;

    return if ($self->get_collid() ne $collid);

    # XXX WARNING: Inefficient.  We will probably not need this if we
    # use Lucene for sorting.
    my $curr_id_arr_ref = $self->get_result_ids();

    my @reduced_arr;
    foreach my $curr_id (@$curr_id_arr_ref)
    {
        # If one of the current ids is in the list of ids to be
        # deleted, decrement the num_found count else save it to the
        # reduced list of ids that will replace the current list
        if (grep(/^$curr_id$/, @$id_arr_ref))
        {
            $self->{'num_found'}--;
        }
        else
        {
            push(@reduced_arr, $curr_id);
        }
    }
    $self->__set_result_ids(\@reduced_arr);
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
