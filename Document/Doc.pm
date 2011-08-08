package Document::Doc;

=head1 NAME

Document

=head1 DESCRIPTION

This class implements teh abstract interface defined by the Document
supreclass and is the Composition parent of the Data and Metadata
objects that support construction of Solr documents for large-scale
full-text indexing and item-level indexing.

=head1 VERSION

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

# App
use base qw(Document);

use Context;
use Utils;
use Debug::DUtils;
use Identifier;
use Search::Constants;

use Db;


# ---------------------------------------------------------------------

=item PUBLIC API: create_document

Initialize Document object.

=cut

# ---------------------------------------------------------------------
sub create_document {
    my $self = shift;
    my $C = shift;
    my $document_id = shift;
    
    my $config = $C->get_object('MdpConfig');
    my $document_metadata_class = $config->get('document_subclass');

    my %of_attrs;
    my $of = new ObjFactory;
    %of_attrs = (
                 'class_name' => $document_metadata_class,
                 'parameters' => {
                                  'C'  => $C,
                                  'id' => $document_id,
                                 },
                );
    my $metadata_obj = $of->create_instance($C, \%of_attrs);

    my $document_data_class = $config->get('document_dataclass');
    %of_attrs = (
                 'class_name' => $document_data_class,
                 'parameters' => {
                                  'C'  => $C,
                                  'id' => $document_id,
                                 },
                );
    my $data_obj = $of->create_instance($C, \%of_attrs);

    $self->{D_metadata} = $metadata_obj;
    $self->{D_data} = $data_obj;

    $self->{D_doc_id} = $document_id;
}


sub D_get_metadata_obj {
    my $self = shift;
    return $self->{D_metadata};
}

sub D_get_data_obj {
    my $self = shift;
    return $self->{D_data};
}

sub D_get_doc_id {
    my $self = shift;
    return $self->{D_doc_id};
}

# ---------------------------------------------------------------------

=item PUBLIC API: build_document

Description

=cut

# ---------------------------------------------------------------------
sub build_document {
    my $self = shift;
    my ($C, $state) = @_;
    
    my $complete_solr_doc = '';
    
    DEBUG('doc', qq{build_document: start});
    my $start = Time::HiRes::time();
    
    my $dbh = $C->get_object('Database')->get_DBH($C);
    my $item_id = $self->D_get_doc_id();

    my $data_status = IX_NO_ERROR;
    my $metadata_status = IX_NO_ERROR;
    
    # Metadata fields
    my ($metadata_fields_ref, $m_status) = 
      $self->D_get_metadata_obj()->get_metadata_fields($C, $dbh, $item_id, $state);
    if ($m_status != IX_NO_ERROR) {
        $metadata_status = IX_METADATA_FAILURE;
    }
    my $ck = Time::HiRes::time() - $start;
    DEBUG('doc', qq{METADATA: read metadata in sec=$ck});

    # Data (like OCR)
    my ($data_fields_ref, $d_status, $data_elapsed) = 
      $self->D_get_data_obj()->get_data_fields($C, $item_id, $state);
    if ($d_status != IX_NO_ERROR) {
        $data_status = IX_DATA_FAILURE;
    }
    DEBUG('doc', qq{DATA: read data in sec=$data_elapsed});

    if (($data_status == IX_NO_ERROR) && ($metadata_status == IX_NO_ERROR)) {
        #
        # Here be the doc!
        #
        $complete_solr_doc = $$metadata_fields_ref . $$data_fields_ref;
        
        # Maybe save it to disk to have a look-see
        Document::handle_debug_save_doc($item_id, \$complete_solr_doc, $state);

        wrap_string_in_tag_by_ref(\$complete_solr_doc, 'doc');
    }
    
    my $elapsed = (Time::HiRes::time() - $start);
    DEBUG('doc', qq{build_document: elapsed=$elapsed sec ocr=$data_status metadata=$metadata_status});

    my %stats;
    $stats{'create'}{'doc_size'} = length($complete_solr_doc);
    $stats{'create'}{'elapsed'}  = $elapsed;

    $self->{'complete_solr_doc'}{'doc_ref'} = \$complete_solr_doc;
    $self->{'complete_solr_doc'}{'data_status'} = $data_status;
    $self->{'complete_solr_doc'}{'metadata_status'} = $metadata_status;
    $self->{'complete_solr_doc'}{'stats'} = \%stats;
}


# ---------------------------------------------------------------------

=item PUBLIC: finish_document

Clean up resources used to build the document

=cut

# ---------------------------------------------------------------------
sub finish_document {
    my $self = shift;
    my $C = shift;
    
    # Delegate cleanup
    $self->D_get_metadata_obj()->finish_document($C);
    $self->D_get_data_obj()->finish_document($C);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_document_content

Description: Implements pure virtual method

=cut

# ---------------------------------------------------------------------
sub get_document_content {
    my $self = shift;
    my $C = shift;

    return $self->{'complete_solr_doc'}{'doc_ref'};
}

# ---------------------------------------------------------------------

=item PUBLIC: get_state_variable

Maintains the state of traversal over the Data content of a
Document. For example, over the OCR files in a package.

=cut

# ---------------------------------------------------------------------
sub get_state_variable {
    my $self = shift;
    my $C = shift;

    return $self->D_get_data_obj()->get_state_variable($C);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_metadata_fields

For fields like title, author, date etc. to use Lucene for
search/facet

=cut

# ---------------------------------------------------------------------
sub get_metadata_fields {
    my $self = shift;
    my $C = shift;
    my $state = shift;

    my $dbh = $C->get_object('Database')->get_DBH($C);
    my $item_id = $self->D_get_doc_id();

    return $self->D_get_metadata_obj()->get_metadata_fields($C, $dbh, $item_id, $state);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_data_fields

For fields like ocr, etc. that do not come directly from a metadata
source like the catalog.

=cut

# ---------------------------------------------------------------------
sub get_data_fields {
    my $self = shift;
    my ($C, $item_id, $state) = @_;
    
    return $self->D_get_data_obj()->get_data_fields($C, $item_id, $state);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_document_status

Description: 

=cut

# ---------------------------------------------------------------------
sub get_document_status {
    my $self = shift;
    my $C = shift;

    return (
            $self->{'complete_solr_doc'}{'data_status'},
            $self->{'complete_solr_doc'}{'metadata_status'},
           );
}

# ---------------------------------------------------------------------

=item PUBLIC: get_document_stats

Description: 

=cut

# ---------------------------------------------------------------------
sub get_document_stats {
    my $self = shift;
    my $C = shift;

    return $self->{'complete_solr_doc'}{'stats'};
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008-11 ©, The Regents of The University of Michigan, All Rights Reserved

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
