package Document::Doc::Data::Ocr;


=head1 NAME

Document::Data::Ocr

=head1 DESCRIPTION

This is the base class to handle the retrieval of ocr.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use File::Path;

use base qw(Document::Doc::Data);

use Utils;
use Debug::DUtils;
use Utils::Extract;
use Identifier;
use Utils::Logger;

use SLIP_Utils::Common;
use Document::Doc::METS;


# ---------------------------------------------------------------------

=item PUBLIC API: new

Initialize Document.

=cut

# ---------------------------------------------------------------------
sub new {
    my $class = shift;
    my $param_hashref = shift;

    my $C = $$param_hashref{'C'};
    my $item_id = $$param_hashref{'id'};

    my $self = {};
    bless $self, $class;

    my $mo = new Document::Doc::METS($C, $item_id, ['ocr']);
    $self->{d__METS_obj} = $mo;

    return $self;
}

sub get_filelist {
    my $self = shift;
    my $C = shift; 
    return $self->{d__METS_obj}->get_filelist_for($C, 'ocr');
}

sub get_seq2pgnum_map {
    my $self = shift;
    my $C = shift; 
    return $self->{d__METS_obj}->get_seq2pgnum_map($C, 'ocr');
}

sub get_num_files {
    my $self = shift;
    my $C = shift; 
    return $self->{d__METS_obj}->get_num_files_for($C, 'ocr');
}

sub get_has_files {
    my $self = shift;
    my $C = shift; 
    return $self->{d__METS_obj}->get_has_files_for($C, 'ocr');
}

sub __get_ddo {
    my $self = shift;
    my $key = shift;
    return $self->{$key};
}

sub __set_ddo {
    my $self = shift;
    my ($key, $val) = @_;
    $self->{$key} = $val;
}


# ---------------------------------------------------------------------

=item PUBLIC API: finish_document

Description

=cut

# ---------------------------------------------------------------------
sub finish_document {
    my $self = shift;
    my $C = shift;

    my $temp_dir = $self->__get_ddo('d__temp_dir');

    if (defined($temp_dir)) {
        my $err = [];
        File::Path::remove_tree($temp_dir, {error => \$err})
            unless (DEBUG('docfulldebug'));
        
        if (scalar(@$err)) {
            for my $diagnostic (@$err) {
                my ($file, $message) = %$diagnostic;
                if ($file eq '') {
                    Utils::Logger::__Log_simple(qq{general error: $message});
                }
                else {
                    Utils::Logger::__Log_simple(qq{problem unlinking $file: $message});
                }
            }
        }
    }
}


# ---------------------------------------------------------------------

=item PUBLIC: handle_ocr_extraction

Description

=cut

# ---------------------------------------------------------------------
sub handle_ocr_extraction {
    my $self = shift;
    my $C = shift;
    my $item_id = shift;
    
    # Already unzipped?
    if (! $self->__get_ddo('d__temp_dir')) {
        # ----- Extract OCR, avoid some obvious junk -----
        my $file_pattern_arr_ref = ['*.txt'];
        my $exclude_pattern_arr_ref = ['*/notes.txt', '*/pagedata.txt' ];
        
        my $temp_dir =
          $self->__extract_ocr_to_path(
                                       $item_id,
                                       $file_pattern_arr_ref,
                                       $exclude_pattern_arr_ref
                                      );
        my $DIR;
        if (! opendir($DIR, $temp_dir)) {
            my $s = qq{OCR: failed to open dir="$temp_dir", item_id="$item_id"};
            Utils::Logger::__Log_simple($s);
            DEBUG('doc', $s);
        }
        else {
            $self->__set_ddo('d__temp_dir', $temp_dir);

            # ----- Test OCR files exist: there exist objects without OCR files
            my $has_ocr = $self->__ocr_existence_test($DIR, $temp_dir, $item_id);
            $self->__set_ddo('d__has_ocr', $has_ocr);

            closedir($DIR);
        }
    }
    
    return ($self->__get_ddo('d__temp_dir'), $self->__get_ddo('d__has_ocr'));
}


# ---------------------------------------------------------------------

=item PRIVATE: __extract_ocr_to_path

For example (Shell file patterns, NOT a perl regexp):

my $file_pattern_arr_ref = ['*.txt'];
my $exclude_pattern_arr_ref = ['*/notes.txt', '*/pagedata.txt' ];

=cut

# ---------------------------------------------------------------------
sub __extract_ocr_to_path {
    my $self = shift;
    my ($id, $file_pattern_arr_ref, $exclude_pattern_arr_ref) = @_;

    my $ck = Time::HiRes::time();
    my $ocr_file_dir;

    eval {
        my $file_sys_location = Identifier::get_item_location($id);
        my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);

        if (-e $file_sys_location . qq{/$stripped_id.zip}) {
            # Extract ocr files to the input cache location
            $ocr_file_dir =
              Utils::Extract::extract_dir_to_temp_cache
                  (
                   $id,
                   $file_sys_location,
                   $file_pattern_arr_ref,
                   $exclude_pattern_arr_ref,
                  );
            chomp($ocr_file_dir);
        }
    };
    if ($@) {
        my $s = qq{extract_ocr_to_path failed: id=$id error:$@};
        Utils::Logger::__Log_simple($s);
        DEBUG('doc', $s);
        return undef;
    }
    my $cke = Time::HiRes::time() - $ck;
    DEBUG('doc', qq{OCR: zipfile extracted to dir="$ocr_file_dir" in sec=$cke});

    return $ocr_file_dir;
}


# ---------------------------------------------------------------------

=item PUBLIC: clean_ocr

Description

=cut

# ---------------------------------------------------------------------
sub clean_ocr {
    my $self = shift;
    my $ocr_text_ref = shift;

    my $ck = Time::HiRes::time();
    SLIP_Utils::Common::clean_xml($ocr_text_ref);
    my $cke = Time::HiRes::time() - $ck;
    DEBUG('doc', qq{OCR: cleaned in sec=$cke});
}

# ---------------------------------------------------------------------

=item PRIVATE: __ocr_existence_test

Description

=cut

# ---------------------------------------------------------------------
sub __ocr_existence_test {
    my $self = shift;
    my $dir_handle = shift;
    my $temp_dir = shift;
    my $item_id = shift;

    my $ocr_exists = 1;
    my $g_ocr_file_regexp = q{^.+?\.txt$};
    my @ocr_filespecs = grep(/$g_ocr_file_regexp/os, readdir($dir_handle));
    if (scalar(@ocr_filespecs) == 0) {
        DEBUG('doc', qq{OCR: no files in $temp_dir match regexp="$g_ocr_file_regexp", item_id="$item_id"});
        $ocr_exists = 0;
    }

    return $ocr_exists;
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
