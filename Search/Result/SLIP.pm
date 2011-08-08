package Result::SLIP;


=head1 NAME

Result::SLIP (rs)

=head1 DESCRIPTION

This class does encapsulates the Solr search response data.

=head1 VERSION

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


use strict;

use base qw(Search::Result);
use XML::LibXML;


# ---------------------------------------------------------------------

=item AFTER_Result_initialize

Subclass Initialize Result::SLIP object.

=cut

# ---------------------------------------------------------------------
sub AFTER_Result_initialize {
    my $self = shift;
    $self->{'parser'} = XML::LibXML->new();
}

# ---------------------------------------------------------------------

=item __get_parser

Description

=cut

# ---------------------------------------------------------------------
sub __get_parser {
    my $self = shift;
    return $self->{'parser'};
}

# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

Example Solr result is:

<response>
  <lst name="responseHeader">
    <int name="status">0</int>
    <int name="QTime">1</int>
  </lst>
  <result name="response" numFound="3" start="0" maxScore="0.02694472">
    <doc>
       <str name="id">mdp39015123456789</str>
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

    my $parser = $self->__get_parser();
    my $doc = $parser->parse_string($$Solr_response_ref);
    my $xpath_doc = q{/response/result/doc};

    my @result_ids;
    my @complete_result;
    foreach my $node ($doc->findnodes($xpath_doc)) {
        my $id = $node->findvalue(q{child::str[@name='id']});
        my $rights = $node->findvalue(q{child::int[@name='rights']});

        my @coll_ids = ();
        foreach my $coll_id_node ($node->findnodes(q{child::arr[@name='coll_id']/long})) {
            push(@coll_ids, $coll_id_node->textContent());
        }

        my $hash_ref = {
                        'id' => $id,
                        'rights' => $rights,
                        'coll_ids' => \@coll_ids,
                       };
        push(@complete_result, $hash_ref);
        push(@result_ids, $id);
    }

    $self->{'rows_returned'} = scalar(@result_ids);
    $self->set_complete_result(\@complete_result);
    $self->__set_result_ids(\@result_ids);
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

=item get_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_result_ids
{
    my $self = shift;
    return $self->{'result_ids'};
}



1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2009 ©, The Regents of The University of Michigan, All Rights Reserved

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
