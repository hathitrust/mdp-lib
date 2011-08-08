package Search::Result::vSolrRaw;


=head1 NAME

Search::Result::vSolrRaw (rs)

=head1 DESCRIPTION

This class encapsulates the raw VuFind Solr search response data as
is. The VuFind Solr schema is a bib record associated with 1 or more
item records.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


use strict;

use base qw(Search::Result);


# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

<response>
  <lst name="responseHeader">HEADER</lst>
  <result name="response" numFound="1" start="0">
    <doc>
      <arr name="author">
        <str>International Congress of Mathematicians </str>
      </arr>
      <arr name="availability">
        <str>HathiTrust</str>
        <str>Full text available online via HathiTrust</str>
        <str>Available online</str>
        <str>Circulating volumes</str></arr>
      <arr name="callnumber">
        <str>QA 1 .I6</str>
        <str>FILM X3107</str>
        <str>FILM X3107 Negative</str>
        <str>See URL for access</str>
        <str/></arr>
      <arr name="ht_id_display">
        <str>wu.89040267247|00000000|1 1898</str>
        <str>miun.aag4063.0097.001|00000000|1897</str>
        <str>miun.aag4063.0000.001|00000000|1900 v.1</str>
        [...]
        <str>wu.89040219560|00000000|5:1 1912</str>
        <str>wu.89040219578|00000000|5:2 1912</str>
      </arr>
      <str name="id">000061495</str>
      <arr name="language">
        <str>English</str>
        <str>French</str>
        <str>German</str>
        <str>Italian</str>
        <str>Russian</str>
      </arr>
      <str name="lccn">52001808//r62</str>
      <arr name="oclc"><str>09835499</str></arr>
      <arr name="publishDate"><str>1897</str></arr>
      <arr name="title"><str>Proceedings</str></arr>
      <str name="titleSort">proceedings</str><arr name="title_ab"><str>Proceedings.</str></arr>
      <arr name="topicStr"><str>Mathematics Congresses</str></arr>
    </doc>
  </result>  
</response>

=cut

# ---------------------------------------------------------------------
sub AFTER_ingest_Solr_search_response {
    my $self = shift;
    my $Solr_response_ref = shift;

    $self->set_complete_result($Solr_response_ref);
}


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

=item get_doc_node_count

Description

=cut

# ---------------------------------------------------------------------
sub get_doc_node_count
{
    my $self = shift;
    return $self->{'doc_node_count'};
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
