package Document::Doc::Data::Ocr::Volume;


=head1 NAME

Document::Doc::Data::Ocr::Volume

=head1 DESCRIPTION

This class encapsulates the retrieval of ocr for an entire volume as
part of the construction of a Solr/Lucene document for indexing.  It
implements the abstract interface defined by Document.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use IPC::Run;
use Time::HiRes;
use Cwd;

use base qw(Document::Doc::Data::Ocr);

use Utils;
use Utils::Logger;
use Utils::Extract;
use Debug::DUtils;
use Identifier;

use Document;
use Search::Constants;


# ---------------------------------------------------------------------

=item PUBLIC: get_data_fields

Description

=cut

# ---------------------------------------------------------------------
sub get_data_fields {
    my $self = shift;
    my ($C, $item_id, $state) = @_;

    my $start = Time::HiRes::time();

    # ----- Extract OCR if METS says files exist and are non-zero size -----
    my $has_files = $self->get_has_files($C);

    my ($temp_dir, $has_ocr) = $self->handle_ocr_extraction($C, $item_id)
      unless (! $has_files);

    my $ocr_text_ref;
    my $pairtree_item_id = Identifier::get_pairtree_id_wo_namespace($item_id);
    my $concat_filename = Utils::Extract::get_formatted_path("/ram/OCR-$pairtree_item_id", ".txt");

    if ($has_ocr) {
        # ----- Create concatenated file -----
        my $files_arr_ref = $self->get_filelist($C);
        my $rc = __concat_files($temp_dir, $files_arr_ref, $concat_filename);
        if ($rc > 0) {
            return (undef, IX_DATA_FAILURE, 0);
        }
        # POSSIBLY NOTREACHED

        $ocr_text_ref = Utils::read_file($concat_filename, 1);
        if (! $ocr_text_ref) {
            my $s = qq{Utils::read_file failed: concat_file=$concat_filename};
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
        system("touch", $concat_filename);
        my $empty_ocr_sentinel = $C->get_object('MdpConfig')->get('ix_index_empty_string');
        $ocr_text_ref = \$empty_ocr_sentinel;
    }

    Document::maybe_preserve_doc($ocr_text_ref, $concat_filename);

    unlink($concat_filename)
      unless (DEBUG('docfulldebug'));

    # OCR field
    wrap_string_in_tag_by_ref($ocr_text_ref, 'field', [['name', 'ocr']]);

    my $elapsed = Time::HiRes::time() - $start;
    DEBUG('doc', qq{OCR: total elapsed sec=$elapsed});

    return ($ocr_text_ref, IX_NO_ERROR, $elapsed);
}


# ---------------------------------------------------------------------

=item get_state_variable

This method returns a closure (subroutine ref) that encapsulates the
state of document generation iteration for this subclass.

In the case of Document::Doc::Data::Ocr::Volume, we are building
a Solr document that contains the concatenation of all the OCR for an
item there is only a single iteration required.

=cut

# ---------------------------------------------------------------------
sub get_state_variable {
    my $self = shift;
    my $C = shift;

    my $state_var =
      sub {
          if (! defined($self->{S_state})) {
              $self->{S_state} = 0;
              return $self->{S_state};
          }
          return undef;
      };

    return $state_var;
}


# ---------------------------------------------------------------------

=item __concat_files

Protect filename containg $BARCODE and who knows what else from shell
interpolation

=cut

# ---------------------------------------------------------------------
sub __concat_files {
    my $dir = shift;
    my $files_arr_ref = shift;
    my $catfile_path = shift;

    my $ck = Time::HiRes::time();
    my $cwd = cwd();
    chdir($dir);
    my @cat_cmds;
    push @cat_cmds, "cat", @$files_arr_ref;
    IPC::Run::run \@cat_cmds, ">", "$catfile_path";
    my $rc = $? >> 8;
    chdir($cwd);
    my $cke = Time::HiRes::time() - $ck;

    if ($rc > 0) {
        my $files = join(' ', @$files_arr_ref);
        my $s = qq{__concat_files failed: rc=$rc dir=$dir files=$files path=$catfile_path};
        Utils::Logger::__Log_simple($s);
        DEBUG('doc', $s);
    }

    DEBUG('doc', qq{OCR: concat file=$catfile_path created in sec=$cke});

    return $rc;
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
