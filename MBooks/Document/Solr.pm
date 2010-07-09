package MBooks::Document::Solr;


=head1 NAME

MBooks::Document::Solr

=head1 DESCRIPTION

This class creates an Solr stype document for indexing

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

# App
use base qw(Search::Document);
use Utils;
use Debug::DUtils;
use Identifier;
use Context;
use Collection;
use Search::Constants;

# MBooks
use MBooks::Index;

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}

# ---------------------------------------------------------------------

=item after_initialize

Initialize MBooks::Document::Solr.

=cut

# ---------------------------------------------------------------------
sub after_initialize
{
    my $self = shift;
    my ($C, $item_id, $coll_ids_ref) = @_;

    my ($doc_ref, $ocr_failure) 
        = $self->build_solr_document($C, $item_id, $coll_ids_ref);

    $self->{'complete_solr_doc'}{'doc_ref'} = $doc_ref;
    $self->{'complete_solr_doc'}{'ocr_failure'} = $ocr_failure;
}

# ---------------------------------------------------------------------

=item build_solr_document

Description

=cut

# ---------------------------------------------------------------------
sub build_solr_document
{
    my $self = shift;
    my ($C, $item_id, $coll_ids_ref) = @_;

    my $co = $C->get_object('Collection');
    my $extern_id = $co->get_extern_id_from_item_id($item_id);

    my $ocr_failure = 0;
    
    # OCR
    my ($ocr_data_ref, $elapsed) = $self->get_ocr_data($C, $extern_id);
    soft_ASSERT($ocr_data_ref, qq{Failed to get OCR data for id="$item_id" extern_id="$extern_id"});
    if (! $ocr_data_ref)
    {
        my $config = $C->get_object('MdpConfig');
        # We can do a solr query in the Admin interface for this string
        my $failure_sentinel = $config->get('ix_index_failure_string');
        $ocr_data_ref = \$failure_sentinel;
        $ocr_failure = 1;
    }
    wrap_string_in_tag_by_ref($ocr_data_ref, 'field', [['name', 'ocr']]);

    # internal id field cgi: iid
    my $item_id_field = wrap_string_in_tag($item_id, 'field', [['name', 'id']]);

    # external MDP id field cgi: id
    my $extern_id_field = wrap_string_in_tag($extern_id, 'field', [['name', 'extern_id']]);

    # Coll IDs
    my $collid_fields = $self->__get_collid_fields($C, $item_id, $coll_ids_ref);

    # Metadata
    my $metadata_fields_ref = $self->get_metadata_fields($C, $item_id);

    my $complete_solr_doc =
        $item_id_field .
            $extern_id_field .
                $collid_fields .
                    $$metadata_fields_ref .
                        $$ocr_data_ref;

    wrap_string_in_tag_by_ref(\$complete_solr_doc, 'doc');
    wrap_string_in_tag_by_ref(\$complete_solr_doc, 'add');

    return (\$complete_solr_doc, $ocr_failure);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_document_content

Description: Implements pure virtual method

=cut

# ---------------------------------------------------------------------
sub get_document_content
{
    my $self = shift;
    my $C = shift;

    return $self->{'complete_solr_doc'}{'doc_ref'};
}

# ---------------------------------------------------------------------

=item PUBLIC: get_document_status

Description:

=cut

# ---------------------------------------------------------------------
sub get_document_status
{
    my $self = shift;
    my $C = shift;

    my ($ocr_status, $metadata_status) = (IX_NO_ERROR, IX_NO_ERROR);
    
    if ($self->{'complete_solr_doc'}{'ocr_failure'})
    {
        ($ocr_status, $metadata_status) = (IX_OCR_FAILURE, IX_METADATA_FAILURE);
    }

    return ($ocr_status, $metadata_status);
}

# ---------------------------------------------------------------------

=item __get_collid_fields

Description

=cut

# ---------------------------------------------------------------------
sub __get_collid_fields
{
    my $self = shift;
    my ($C, $item_id, $coll_ids_ref) = @_;

    my $ids_arr_ref = [];

    # collection id field(s).  ids of all collections containing this item.
    if ($coll_ids_ref)
    {
        my @id_arr = split(/\|/, $$coll_ids_ref);
        $ids_arr_ref = \@id_arr;
    }
    else
    {
        my $co = $C->get_object('Collection');
        $ids_arr_ref = $co->get_coll_ids_for_item($item_id);
    }

    if (scalar(@$ids_arr_ref) == 0)
    {
        push(@$ids_arr_ref, IX_NO_COLLECTION);
    }

    my $coll_id_fields;
    foreach my $coll_id (@$ids_arr_ref)
    {
        $coll_id_fields .=
            wrap_string_in_tag($coll_id, 'field', [['name', 'coll_id']]);
    }

    return $coll_id_fields;
}



# ---------------------------------------------------------------------

=item PRIVATE: get_metadata_fields

For title, author, date to use Lucene for sorting on these

=cut

# ---------------------------------------------------------------------
sub get_metadata_fields
{
    my $self = shift;
    my ($C, $item_id) = @_;

    my $Lucene_Metadata_Search_Enabled = 0;

    my $metadata_fields = '';
    return \$metadata_fields if (! $Lucene_Metadata_Search_Enabled); # XXX

    my $co = $C->get_object('Collection');

    # Author sort-title and date
    my $item_data_arr_ref = $co->get_metadata_f_item_ids([$item_id]);
    my $metadata_hashref = $$item_data_arr_ref[0];

    my $sort_title = $$metadata_hashref{'sort_title'};
    my $sort_title_field =
        wrap_string_in_tag($$metadata_hashref{'sort_title'},
                           'field', [['name', 'title']]);
    my $author_field =
        wrap_string_in_tag($$metadata_hashref{'author'},
                           'field', [['name', 'author']]);
    my $date_field =
        wrap_string_in_tag($$metadata_hashref{'date'},
                           'field', [['name', 'date']]);

    $metadata_fields = $sort_title_field . $author_field . $date_field;

    return \$metadata_fields;
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
