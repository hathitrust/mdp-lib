package Document::Doc::Data::Ocr::Page;


=head1 NAME

Document::Doc::Data::Ocr::Page

=head1 DESCRIPTION

This class encapsulates the retrieval of ocr for one page of OCR as
part of the construction of a Solr/Lucene document for item-level
indexing.  It implements the abstract interface defined by Document.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use Time::HiRes;

use base qw(Document::Doc::Data::Ocr);

use Utils;
use Utils::Logger;
use Debug::DUtils;
use Identifier;

use Document;
use Search::Constants;

# ---------------------------------------------------------------------

=item PUBLIC: get_data_fields

For fields like ocr, etc. that do not come directly from a metadata
source like the catalog.

=cut

# ---------------------------------------------------------------------
sub get_data_fields {
    my $self = shift;
    my ($C, $item_id, $state) = @_;

    # OCR field
    my  ($ocr_text_ref, $status, $elapsed) = $self->__get_ocr_data($C, $item_id, $state);
    wrap_string_in_tag_by_ref($ocr_text_ref, 'field', [['name', 'ocr']]);

    # seq == state
    my $seq_field = wrap_string_in_tag($state, 'field', [['name', 'seq']]);

    # pgnum field
    my  $map_ref = $self->get_seq2pgnum_map($C);
    my $pgnum = $map_ref->{$state};
    my $pgnum_field;
    if (defined($pgnum)) {
        $pgnum_field = wrap_string_in_tag($pgnum, 'field', [['name', 'pgnum']]);
    }

    my $data_fields =
      $$ocr_text_ref
        . $seq_field
          . ($pgnum_field ? $pgnum_field : '');
    
    return (\$data_fields, $status, $elapsed);
}


# ---------------------------------------------------------------------

=item PRIVATE: __get_ocr_data

Description

=cut

# ---------------------------------------------------------------------
sub __get_ocr_data {
    my $self = shift;
    my ($C, $item_id, $state) = @_;

    my $files_arr_ref = $self->get_filelist($C);

    my $start = Time::HiRes::time();

    # ----- Extract OCR if METS says files exist and are non-zero size -----
    my $has_files = $self->get_has_files($C);

    my ($temp_dir, $has_ocr) = $self->handle_ocr_extraction($C, $item_id)
      unless (! $has_files);

    my $ocr_text_ref;
    my $pairtree_item_id = Identifier::get_pairtree_id_wo_namespace($item_id);
    # state == seq, state and seq are 1-relative
    my $filename = $files_arr_ref->[$state - 1];
    my $full_filename = $temp_dir . '/' . $filename;

    if ($has_ocr) {
        # ----- Read file[$state] -----
        $ocr_text_ref = Utils::read_file($full_filename, 1);
        if (! $ocr_text_ref) {
            my $s = qq{Utils::read_file failed: page_file=$full_filename};
            Utils::Logger::__Log_simple($s);
            DEBUG('doc', $s);

            return (undef, IX_DATA_FAILURE, 0);
        }
        # POSSIBLY NOTREACHED

        if ($$ocr_text_ref eq '') {
            my $empty_ocr_sentinel = $C->get_object('MdpConfig')->get('ix_index_empty_string');
            $ocr_text_ref = \$empty_ocr_sentinel;
        }

        $self->clean_ocr($ocr_text_ref);

        Document::apply_algorithms($C, $ocr_text_ref, 'garbage_ocr_class');
    }
    else {
        system("touch", $full_filename);
        my $empty_ocr_sentinel = $C->get_object('MdpConfig')->get('ix_index_empty_string');
        $ocr_text_ref = \$empty_ocr_sentinel;
    }

    Document::maybe_preserve_doc($ocr_text_ref, $filename . qq{_$state});

    my $elapsed = Time::HiRes::time() - $start;
    DEBUG('doc', qq{OCR: total elapsed sec=$elapsed});

    return ($ocr_text_ref, IX_NO_ERROR, $elapsed);
}


# ---------------------------------------------------------------------

=item get_state_variable

This method returns a closure (subroutine ref) that encapsulates the
state of document generation iteration for this subclass.

In the case of Document::Doc::Data::Ocr::Page, we are building
a Solr document that contains the OCR for just one page of an
item.

For this subclass state == seq

=cut

# ---------------------------------------------------------------------
sub get_state_variable {
    my $self = shift;
    my $C = shift;

    my $state_var =
      sub {
          if (! defined($self->{S_state})) {
              $self->{S_state} = 1;
              return $self->{S_state};
          }
          else {
              if ($self->{S_state} > $self->get_num_files($C)) {
                  return undef;
              }
              else {
                  $self->{S_state}++;
                  return $self->{S_state};
              }
          }
      };

    return $state_var;
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
