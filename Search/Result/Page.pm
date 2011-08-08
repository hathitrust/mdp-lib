package Search::Result::Page;

=head1 NAME

Search::Result::Page (rs)

=head1 DESCRIPTION

This class does encapsulates the Item-level Solr search response
data.

It provides access to an array of Solr item page documents in
relevance order containing a number of snippets that are fragments of
the page text containing highlighted terms. 

The maximum number (hl.snippets) of snippets generated per page is
configurable.  The size of the snippets (hl.fragsize) is configurable.

Taken togehter
these two parameters control how may highligted terms (KWICs) will be
displayed. A fragment can vary in size up to the size of the entire
document (a page). In that case, there will be only one snippet
containing all of the terms highlighted.

 %hash =
   (
     'snip_list'  => [
                      'a snippet of a page of highlighted text',
                      'another one',
                      'and a third',
                     ]
     'pgnum'      => '42', # a printed page number
     'seq'        => '37', # the sequence number of the page in the item
     'id'         => 'mdp.39015015823563_41',
     'vol_id'     => 'mdp.39015015823563',
   );

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


use strict;

use base qw(Search::Result);
use XML::LibXML;
use Time::HiRes;

use Utils;
use Utils::Time;
use Debug::DUtils;


# ---------------------------------------------------------------------

=item AFTER_Result_initialize

Subclass Initialize Result::vSolr object.

=cut

# ---------------------------------------------------------------------
sub AFTER_Result_initialize {
    my $self = shift;

    $self->{'parser'} = XML::LibXML->new();
    $self->{'idx'} = 0;
}

# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

Example Solr result is:

<response>
  <lst name="responseHeader">
    <int name="status">0</int>
    <int name="QTime">357</int>
    <lst name="params">
      <str name="fl">id,vol_id,seq,pgnum</str>
      <str name="hl.useFastVectorHighlighter">true</str>
      <str name="start">0</str>
      <str name="q">ocr:"homer"</str>
      <str name="hl.fl">ocr</str>
      <str name="hi.snippets">10</str>
      <str name="hl">true</str>
      <str name="rows">2</str>
    </lst>
  </lst>
  <result name="response" numFound="8" start="0">
    <doc>
      <str name="id">mdp.39015015823563_41</str>
      <str name="pgnum">39</str>
      <int name="seq">41</int>
      <str name="vol_id">mdp.39015015823563</str>
      <str name="ocr"> --- OPTIONAL --- for retrieval of page w/o highlight matches </str>
    </doc>
    <doc>
      <str name="id">mdp.39015015823563_40</str>
      <str name="pgnum">38</str>
      <int name="seq">40</int>
      <str name="vol_id">mdp.39015015823563</str>
      <str name="ocr"> --- OPTIONAL --- for retrieval of page w/o highlight matches </str>
    </doc>
  </result>
  <lst name="highlighting">
    <lst name="mdp.39015015823563_41">
      <arr name="ocr">
        <str>: "W. <em>Homer</em> / 1891" Bequest of Mrs. Charles S. <em>Homer</em> 38.68 Bear and Canoe 1895 </str>
        <str>Another <em>Homer</em> Simpson Bear and Canoe circa 1895 </str>
      </arr>
    </lst>
    <lst name="mdp.39015015823563_40">
      <arr name="ocr">
        <str><em>HOMER</em> 39 HENRY HOLT, JR. 1889-1941 Earth's Upheaval Watercolor</str>
      </arr>
    </lst>
  </lst>
</response>

=cut

# ---------------------------------------------------------------------
sub AFTER_ingest_Solr_search_response {
    my $self = shift;
    my $Solr_response_ref = shift;

    my $start = Time::HiRes::time();
    DEBUG('solrpage', qq{DEBUG: start } . Utils::Time::iso_Time());

    my $parser = $self->__get_parser();
    my $root = $parser->parse_string($$Solr_response_ref);

    my $result_ids_arr_ref = [];
    my $complete_result_arr_ref = [];
    
    foreach my $hl_node ($root->findnodes(q{/response/lst[@name="highlighting"]})) {

        foreach my $lst_child_node ($hl_node->findnodes(q{lst})) {
            my $hid = $lst_child_node->findvalue(q{@name});

            my $hashref = {
                           'hid' => $hid,
                          };

            my $text_snippet_arr_ref = [];
            my @frag_node_list = $lst_child_node->findnodes(q{arr[@name="ocr"]/str});
            foreach my $frag_node (@frag_node_list){
                my $snippet = $frag_node->textContent();
                push(@$text_snippet_arr_ref, \$snippet);
            }
            $hashref->{snip_list} = $text_snippet_arr_ref;

            push(@$complete_result_arr_ref, $hashref);
        }
    }

    my $doc_node_ct = 0;
    my @doc_nodes = $root->findnodes(q{/response/result[@name="response"]/doc});
    foreach my $doc_node (@doc_nodes) {
        my @doc_child_nodes = $doc_node->findnodes(q{str | int});
        
        foreach my $child_node (@doc_child_nodes) {
            my $attr_name = $child_node->findvalue(q{@name});
            my $attr_value = $child_node->textContent();
            
            my $hashref = $complete_result_arr_ref->[$doc_node_ct];

            if ($attr_name eq 'hid') {
                soft_ASSERT($hashref->{hid} eq $attr_value, qq{Solr highlight response mismatch: hid="$attr_value"});
                push(@$result_ids_arr_ref, $attr_value);
            }
            $hashref->{$attr_name} = ($attr_name eq 'ocr') ? \$attr_value : $attr_value;
        }    
        $doc_node_ct++;
    }

    my $elapsed = Time::HiRes::time() - $start;
    DEBUG('solrpage', qq{DEBUG: elapsed=$elapsed});

    $self->{rows_returned} = scalar(@$result_ids_arr_ref);
    $self->set_complete_result($complete_result_arr_ref);
    $self->__set_result_ids($result_ids_arr_ref);
}


# ---------------------------------------------------------------------

=item PRIVATE: __set_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub __set_result_ids {
    my $self = shift;
    my $arr_ref = shift;
    $self->{'result_ids'} = $arr_ref;
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

=item init_iterator

Description

=cut

# ---------------------------------------------------------------------
sub init_iterator {
    my $self = shift;
    return $self->{'idx'} = 0;
}

# ---------------------------------------------------------------------

=item get_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_result_ids {
    my $self = shift;
    return $self->{'result_ids'};
}


# ---------------------------------------------------------------------

=item init_Page_iterator

Description

=cut

# ---------------------------------------------------------------------
sub init_Page_iterator {
    my $self = shift;
    return $self->{'page_idx'} = 0;
}

# ---------------------------------------------------------------------

=item get_next_Page_result

Description

=cut

# ---------------------------------------------------------------------
sub get_next_Page_result {
    my $self = shift;

    my $arr_ref = $self->get_complete_result();
    my $Page_result_hashref = $arr_ref->[ $self->{page_idx}++ ];
    
    return $Page_result_hashref;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011 ©, The Regents of The University of Michigan, All Rights Reserved

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
