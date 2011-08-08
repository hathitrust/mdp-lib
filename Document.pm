package Document;


=head1 NAME

Document (doc)

=head1 DESCRIPTION

Document super-class expresses abstract interface for document
creation. Returns a document object structured corectly for submission
to an Indexer.  The Indexer subclasses are currently XPAT and
Solr. The XPAT Indexer types are basically defunct.

The Document class is modeled as the Composition of a Data Class (such
as text in the form of OCR or XML) and a Metadata Class (consisting of
title, author, rights and so on), i.e. as a HAS-A relationship.

The methods defined in the abstract interface are implemented by
Delegation to methods in one or both of the Data and Metadata classes.

=head1 SYNOPSIS

my $doc = new Document();

=head1 METHODS

=over 8

=cut

use strict;

# Perl
use Encode;

# Local
use Context;
use Utils;
use Debug::DUtils;
use ObjFactory;
use Identifier;


sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->create_document(@_);

    return $self;
}


# =====================================================================
# ==
# ==                       Abstract Public Interface
# ==
# =====================================================================


# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: create_document

Initialize Document object.

=cut

# ---------------------------------------------------------------------
sub create_document {
    ASSERT(0, qq{Pure virtual method create_document() not implemented in a subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: build_document

Description

=cut

# ---------------------------------------------------------------------
sub build_document {
    ASSERT(0, qq{Pure virtual method build_document() not implemented in a subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: finish_document

Clean up resources used to build the document

=cut

# ---------------------------------------------------------------------
sub finish_document {
    ASSERT(0, qq{Pure virtual method finish_document() not implemented in a subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_document_content

The finished Document content data + metadata fields

=cut

# ---------------------------------------------------------------------
sub get_document_content {
    ASSERT(0, qq{Pure virtual method get_document_content() not implemented in a subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_state_variable

Maintains the state of traversal over the Data content of a
Document. For example, over the OCR files in a package.

=cut

# ---------------------------------------------------------------------
sub get_state_variable {
    ASSERT(0, qq{Pure virtual method get_state_variable() not implemented in a subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_metadata_fields

For fields like title, author, date etc. to use Lucene for
search/facet

=cut

# ---------------------------------------------------------------------
sub get_metadata_fields {
    ASSERT(0, qq{Pure virtual method get_metadata_fields() not implemented in subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_data_fields

For fields like ocr, etc. that do not come directly from a metadata
source like the catalog.

=cut

# ---------------------------------------------------------------------
sub get_data_fields {
    ASSERT(0, qq{Pure virtual method get_data_fields() not implemented in subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_document_status

Description:

=cut

# ---------------------------------------------------------------------
sub get_document_status {
    ASSERT(0, qq{Pure virtual method get_document_status() not implemented in subclass of Document});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_document_stats

Description:

=cut

# ---------------------------------------------------------------------
sub get_document_stats {
    ASSERT(0, qq{Pure virtual method get_document_stats() not implemented in subclass of Document});
}


# =====================================================================
# ==
# ==                       Public Interface
# ==
# =====================================================================

# ---------------------------------------------------------------------

=item handle_debug_save_doc

Description

=cut

# ---------------------------------------------------------------------
sub handle_debug_save_doc {
    my $item_id = shift;
    my $complete_solr_doc_ref = shift;
    my $state = shift;

    if (DEBUG('docfulldebug,doconly')) {
        my $pairtree_item_id = Identifier::get_pairtree_id_wo_namespace($item_id);
        my $logdir = Utils::get_tmp_logdir();
        my $temporary_dir = $ENV{'SOLR_DOC_DIR'} ? $ENV{'SOLR_DOC_DIR'} : $logdir;
        my $complete_solr_doc_filename = "$temporary_dir/" . $pairtree_item_id . "-$$-$state" . '.solr.xml';
        Utils::write_data_to_file($complete_solr_doc_ref, $complete_solr_doc_filename);
        chmod(0666, $complete_solr_doc_filename) if (-o $complete_solr_doc_filename);
        DEBUG('docfulldebug,doconly', qq{build_document: save solr doc: "$complete_solr_doc_filename"});
    }
}

# ---------------------------------------------------------------------

=item PUBLIC: get_rights_f_id

Description

=cut

# ---------------------------------------------------------------------
sub get_rights_f_id {
    my ($C, $id) = @_;

    my $dbh = $C->get_object('Database')->get_DBH($C);
    my $attr = Db::Select_j_rights_id_attr($C, $dbh, $id);

    DEBUG('doc', qq{METADATA: $id MISSING from j_rights}) if (! $attr);

    return $attr;
}


# ---------------------------------------------------------------------

=item PUBLIC: maybe_preserve_doc

Description

=cut

# ---------------------------------------------------------------------
sub maybe_preserve_doc {
    my $text_ref = shift;
    my $filename = shift;

    if (DEBUG('docfulldebug')) {
        my $clean_filename = $filename . '-clean';
        my $logdir = Utils::get_tmp_logdir();
        $clean_filename =~ s,^/ram/,$logdir/,;
        Utils::write_data_to_file($text_ref, $clean_filename);
        chmod(0666, $clean_filename) if (-o $clean_filename);
        DEBUG('docfulldebug', qq{DOC: CLEANED file=$clean_filename});
    }
}

# ---------------------------------------------------------------------

=item apply_algorithms

Description

=cut

# ---------------------------------------------------------------------
sub apply_algorithms {
    my $C = shift;
    my $text_ref = shift;
    my $class = shift;

    my $garbage_class = $C->get_object('MdpConfig')->get($class);
    if ($garbage_class) {
        my $of = new ObjFactory;
        my %of_attrs = (
                        'class_name' => $garbage_class,
                        'parameters' => {
                                         'C'  => $C,
                                        },
                       );
        my $goc = $of->create_instance($C, \%of_attrs);

        DEBUG('doc', qq{ALG: apply Garbage_1 algorithm});
        $goc->remove_garbage($C, $text_ref);
    }
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
