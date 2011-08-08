package Document::Doc::vSolrMetadataAPI;


=head1 NAME

Document::vSolrMetadataAPI

=head1 DESCRIPTION

This class is the base class of
index/Document/vSolrMetadataAPI/Schema_*.pm and a child of
index/Document.  It is an intermediate class to provide methods to
access metadata common to these Schema classes and will be the
eventual sibling to other APIs for metadata

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

# Perl
use XML::LibXML;

# App
use base qw(Document::Doc);
use Utils;
use Debug::DUtils;
use Search::Constants;

# SLIP
use Db;
use SLIP_Utils::Solr;
use Search::Result::vSolrRaw;



# CLASS member data
my $g_PARSER = XML::LibXML->new();

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}


# ---------------------------------------------------------------------

=item PUBLIC API: finish_document

Description

=cut

# ---------------------------------------------------------------------
sub finish_document {
    my $self = shift;
    my $C = shift;
}

# ---------------------------------------------------------------------

=item PUBLIC API: get_metadata_fields

Implements pure virtual method. Main method.

=cut

# ---------------------------------------------------------------------
sub get_metadata_fields {
    my $self = shift;
    my ($C, $dbh, $item_id, $state) = @_;

    my $cached = defined( $self->{M_metadata_cache} );

    my $field_list_ref = $self->get_field_list();
    # Author, etc.
    my ($metadata_hashref, $status) = 
      $cached 
        ? ($self->{M_metadata_cache}{_hashref}, $self->{M_metadata_cache}{_status})
          : $self->get_metadata_f_item_id($C, $dbh, $item_id, $field_list_ref);

    my $metadata_fields;
    if ($status == IX_NO_ERROR) {
        # Add aux data
        ($metadata_hashref, $status) =
          $self->get_auxiliary_field_data($C, $dbh, $item_id, $metadata_hashref, $state, $cached);

        if ($status == IX_NO_ERROR) {
            # Field mapping. Always do this even to cached data.
            $self->post_process_metadata($C, $item_id, $metadata_hashref, $state, $cached);

            foreach my $field_name (keys(%$metadata_hashref)) {
                # If multi-valued field
                if (scalar(@{$metadata_hashref->{$field_name}}) > 1) {
                    my @field_vals = @{$metadata_hashref->{$field_name}};
                    foreach my $field_val (@field_vals) {
                        $metadata_fields .=
                          wrap_string_in_tag(
                                             $field_val,
                                             'field',
                                             [['name', $field_name]]
                                            );
                    }
                }
                else {
                    $metadata_fields .=
                      wrap_string_in_tag(
                                         $metadata_hashref->{$field_name}[0],
                                         'field',
                                         [['name', $field_name]]
                                        );
                }
            }
        }
    }

    # Metadata is basically the same across all doc content instances
    # for this subclass.  Any metadata that changes should be handled
    # in post_process_metadata().
    $self->{M_metadata_cache}{_hashref} = $metadata_hashref;
    $self->{M_metadata_cache}{_status} = $status;

    return (\$metadata_fields, $status);
}


# ---------------------------------------------------------------------

=item get_field_list

List of Solr fields to ask for

=cut

# ---------------------------------------------------------------------
sub get_field_list {
    ASSERT(0, qq{get_field_list() in __PACKAGE__ is pure virtual});
}


# ---------------------------------------------------------------------

=item get_auxiliary_field_data

Supplement primary metadata with field data.  This method can be overridden to go
to a variety of sources for additional field data, e.g. MySQL.

Nominally, it returns status and the primary hashref supplemeted with
additional data:

   {
     'field_name' => [ field_val, ... ]
   },
   ...

=cut

# ---------------------------------------------------------------------
sub get_auxiliary_field_data {
    my $self = shift;
    my ($C, $dbh, $item_id, $primary_metadata_hashref, $state, $cached) = @_;

    return ($primary_metadata_hashref, IX_NO_ERROR);
}

# ---------------------------------------------------------------------

=item post_process_metadata

Mapping of VuFind Solr Schema into LS Solr Schema

=cut

# ---------------------------------------------------------------------
sub post_process_metadata {
    ASSERT(0, qq{post_process_metadata() in __PACKAGE__ is pure virtual});
}


# ---------------------------------------------------------------------

=item PUBLIC: get_metadata_f_item_id

Description

=cut

# ---------------------------------------------------------------------
sub get_metadata_f_item_id {
    my $self = shift;
    my ($C, $dbh, $item_id, $field_list_arr_ref) = @_;

    my ($metadata_ref, $status) =
        $self->__get_metadata_from_vufind_f_item_id($C, $dbh, $item_id, $field_list_arr_ref);

    my $metadata_struct_hashref;

    if ($status == IX_NO_ERROR) {
        $metadata_struct_hashref =
            $self->get_structured_metadata_f_item_id($C, $item_id, $metadata_ref);

        # Test for title.
        if (! defined($metadata_struct_hashref->{'title'})) {
            DEBUG('doc', qq{METADATA: ERROR missing title for item_id=$item_id});
            $status = IX_METADATA_FAILURE;
        }
    }

    return ($metadata_struct_hashref, $status);
}


# ---------------------------------------------------------------------

=item get_structured_metadata_f_item_id

Description

=cut

# ---------------------------------------------------------------------
sub get_structured_metadata_f_item_id {
    my $self = shift;
    my ($C, $item_id, $metadata_ref) = @_;

    my %metadata_hash;

    my $doc = $g_PARSER->parse_string($$metadata_ref);
    my $doc_xpath = q{/response/result/doc};

    my @doc_nodes = $doc->findnodes($doc_xpath);

    # Just one doc node per response by design.
    foreach my $node ($doc_nodes[0]->childNodes()) {
        # NAME ::= arr|str
        my $name = $node->nodeName();
        # FIELD_NAME ::= <NAME name="FIELD_NAME>
        my $anode = $node->getAttributeNode('name');
        my $field_name = $anode->textContent();

        # FIELD_VAL ::= <NAME name="FIELD_NAME>FIELD_VAL</>
        if ($name eq 'arr') {
            foreach my $str_node ($node->childNodes()) {
                my $text_node = $str_node->firstChild();
                # Sometimes a field is empty
                if ($text_node) {
                    my $field_val = $text_node->toString();
                    push(@{$metadata_hash{$field_name}}, $field_val);
                }
            }
        }
        else {
            my $text_node = $node->firstChild();
            # Sometimes a field is empty
            if ($text_node) {
                my $field_val = $text_node->toString();
                push(@{$metadata_hash{$field_name}}, $field_val);
            }
        }
    }

    return \%metadata_hash;
}


# ---------------------------------------------------------------------

=item PRIVATE: __get_metadata_from_vufind_f_item_id

Description

=cut

# ---------------------------------------------------------------------
sub __get_metadata_from_vufind_f_item_id {
    my $self = shift;
    my ($C, $dbh, $item_id, $field_list_arr_ref) = @_;

    # Pessimistic
    my $status = IX_METADATA_FAILURE;

    # Retrieve sysid for item_id and construct query
    my $sysid = Db::Select_j_rights_id_sysid($C, $dbh, $item_id);
    my $ref_to_vSolr_response;

    # 0 might happen if item_id was not sourced from VuFind Solr
    if ($sysid > 0) {
        my $field_list = join(',', @$field_list_arr_ref);
        my $query = qq{q=id:$sysid&start=0&rows=1&fl=$field_list};

        my $searcher = SLIP_Utils::Solr::create_VuFind_Solr_Searcher_by_alias($C);
        my $rs = new Search::Result::vSolrRaw();

        # Retrieve VuFind Solr doc for q=id:$sysid
        $rs = $searcher->get_Solr_raw_internal_query_result($C, $query, $rs);

        # Could have server error or the record with sysid=$sysid may
        # have been removed -- usually a staff error
        if ($rs->http_status_ok() && ($rs->get_num_found() > 0)) {
            $status = IX_NO_ERROR;
            $ref_to_vSolr_response = $rs->get_complete_result();

            DEBUG('vufind', qq{VuFind: response="$$ref_to_vSolr_response"});
        }
        else {
            DEBUG('vufind', qq{VuFind: response="EMPTY" code=} . $rs->get_response_code());
        }
    }

    return ($ref_to_vSolr_response, $status);
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
