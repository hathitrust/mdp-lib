package Search::Document;


=head1 NAME

Search::Document (doc)

=head1 DESCRIPTION

This class returns a document object structured corectly for
submission to the a given Indexer.  The Indexer types are currently
XPAT and Solr implemented as subclasses.

=head1 SYNOPSIS

see PT::Document::XPAT and MBooks::Document::Solr;

=head1 METHODS

=over 8

=cut

use strict;

# Perl
use File::Path;
use Encode;
use Time::HiRes;
use File::Pairtree;
use IPC::Run;
use Cwd;

# Local
use Utils;
use Utils::Logger;
use Debug::DUtils;
use Identifier;
use Utils::Extract;


sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize DocumentFactory object.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    $self->after_initialize(@_);
}


# ---------------------------------------------------------------------

=item after_initialize

Initialize Document subclass using Template Method Design Pattern.

=cut

# ---------------------------------------------------------------------
sub after_initialize
{
    ASSERT(0, qq{Pure virtual method after_initialize() not implemented in a Search::Document::subclass});
}


# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_document_content

Description

=cut

# ---------------------------------------------------------------------
sub get_document_content
{
    ASSERT(0, qq{Pure virtual method get_document_content() not implemented in a Search::Document::subclass});
}

# ---------------------------------------------------------------------

=item PUBLIC PURE VIRTUAL: get_metadata_fields

For title, author, date etc. to use Lucene for search/facet

=cut

# ---------------------------------------------------------------------
sub get_metadata_fields
{
    ASSERT(0, qq{Pure virtual method get_metadata_fields() not implemented in Search::Document::subclass});
}

# ---------------------------------------------------------------------

=item PRIVATE CLASS METHOD: ___num2utf8

Description

=cut

# ---------------------------------------------------------------------
sub ___num2utf8
{
    my ( $t ) = @_;
    my ( $trail, $firstbits, @result );

    if    ($t<0x00000080) { $firstbits=0x00; $trail=0; }
    elsif ($t<0x00000800) { $firstbits=0xC0; $trail=1; }
    elsif ($t<0x00010000) { $firstbits=0xE0; $trail=2; }
    elsif ($t<0x00200000) { $firstbits=0xF0; $trail=3; }
    elsif ($t<0x04000000) { $firstbits=0xF8; $trail=4; }
    elsif ($t<0x80000000) { $firstbits=0xFC; $trail=5; }
    else {
        ASSERT(0, qq{Too large scalar value="$t": cannot be converted to UTF-8.});
    }
    for (1 .. $trail)
    {
        unshift (@result, ($t & 0x3F) | 0x80);
        $t >>= 6;         # slight danger of non-portability
    }
    unshift (@result, $t | $firstbits);
    pack ("C*", @result);
}

# ---------------------------------------------------------------------

=item PUBLIC: Google_NCR_to_UTF8

Description

=cut

# ---------------------------------------------------------------------
sub Google_NCR_to_UTF8
{
    my $sRef = shift;
    $$sRef =~ s,\#{([0-9]+)},___num2utf8($1),ges;
}


# ---------------------------------------------------------------------

=item PUBLIC: clean_xml

The input ref may be invalid UTF-8 because of the forgiving read.  Try
to fix it

As of this date Fri Oct 5 14:36:30 2007 there are 2 problems with the
Google OCR:

1) Single byte control characters like \x01 and \x03 which are legal
UTF-8 but illegal in XML

2) Invalid UTF-8 encoding sequences like \xFF

The following eliminates ranges of invalid control characters (1)
while preserving TAB=U+0009, NEWLINE=U+000A and CARRIAGE
RETURN=U+000D. To handle (2) we eliminate all byte values with high
bit set.  We try to test for this so we do not destroy valid UTF-8
sequences.

=cut

# ---------------------------------------------------------------------
sub clean_xml
{
    my $self = shift;
    my $s_ref = shift;

    $$s_ref = Encode::encode_utf8($$s_ref);
    Google_NCR_to_UTF8($s_ref);
    $$s_ref = Encode::decode_utf8($$s_ref);

    if (! Encode::is_utf8($$s_ref, 1))
    {
        $$s_ref = Encode::encode_utf8($$s_ref);
        $$s_ref =~ s,[\200-\377]+,,gs;
        $$s_ref = Encode::decode_utf8($$s_ref);
    }
    # Decoding changes invalid UTF-8 bytes to the Unicode REPLACEMENT
    # CHARACTER U+FFFD.  Replace that char with a SPACE for nicer
    # viewing.
    $$s_ref =~ s,[\x{FFFD}]+, ,gs;

    # At some time after Wed Aug 5 16:32:34 2009, Google will begin
    # CJK segmenting using 0x200B ZERO WIDTH SPACE instead of 0x0020
    # SPACE.  To maintain compatibility change ZERO WIDTH SPACE to
    # SPACE until we have a Solr query segmenter.
    $$s_ref =~ s,[\x{200B}]+, ,gs;

    # Kill characters that are invalid in XML data. Valid XML
    # characters and ranges are:

    #  (c == 0x9) || (c == 0xA) || (c == 0xD)
    #             || ((c >= 0x20) && (c <= 0xD7FF))
    #             || ((c >= 0xE000) && (c <= 0xFFFD))
    #             || ((c >= 0x10000) && (c <= 0x10FFFF))

    # Note that since we have valid Unicode UTF-8 encoded at this
    # point we don't need to remove any other code
    # points. \x{D800}-\x{DFFF} compose surrogate pairs in UTF-16
    # and the rest are not valid Unicode code points.
    $$s_ref =~ s,[\000-\010\013-\014\016-\037]+, ,gs;

    # Protect against non-XML character data like "<"
    Utils::map_chars_to_cers($s_ref, [q{"}, q{'}], 1);
}

# ---------------------------------------------------------------------

=item PRIVATE: __extract_ocr_to_path

Description

=cut

# ---------------------------------------------------------------------
# Shell file pattern, NOT a perl regexp
my $file_pattern_arr_ref = ['*.txt'];

sub __extract_ocr_to_path {
    my $self = shift;
    my $id = shift;

    my $file_sys_location = Identifier::get_item_location($id);
    my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);
    my $concat_ocr_file_dir;

    if (-e $file_sys_location . qq{/$stripped_id.zip}) {
        # Extract ocr files to the input cache location
        $concat_ocr_file_dir =
            Utils::Extract::extract_dir_to_temp_cache
                (
                 $id,
                 $file_sys_location,
                 $file_pattern_arr_ref
                );
        chomp($concat_ocr_file_dir);
    }

    return $concat_ocr_file_dir;
}


# ---------------------------------------------------------------------

=item __concat_files

Protect filename containg $BARCODE anw who knows what else from shell
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

# ---------------------------------------------------------------------

=item __cleanup_ocr_process

Description

=cut

# ---------------------------------------------------------------------
sub __cleanup_ocr_process {
    my $concat_filename = shift;
    my $temp_dir = shift;

    unlink($concat_filename)
        unless (DEBUG('docfulldebug'));

    # Because this sub can be called in a long loop (sync-i index-i,
    # index-j etc.) unlink the tempdir so they don't accumulate and
    # consume all available space
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

# ---------------------------------------------------------------------

=item __maybe_preserve_doc

Description

=cut

# ---------------------------------------------------------------------
sub __maybe_preserve_doc {
    my $ocr_text_ref = shift;
    my $concat_filename = shift;
    
    if (DEBUG('docfulldebug')) {
        my $clean_concat_filename = $concat_filename . '-clean';
        $clean_concat_filename =~ s,^/ram/,/tmp/,;
        Utils::write_data_to_file($ocr_text_ref, $clean_concat_filename);
        DEBUG('docfulldebug', qq{OCR: CLEANED concat file=$clean_concat_filename});
    }
}

# ---------------------------------------------------------------------

=item __clean_xml

Description

=cut

# ---------------------------------------------------------------------
sub __clean_xml {
    my $self = shift;
    my $ocr_text_ref = shift;
    
    my $ck = Time::HiRes::time();
    $self->clean_xml($ocr_text_ref);
    my $cke = Time::HiRes::time() - $ck;
    DEBUG('doc', qq{OCR: xml cleaned in sec=$cke});

}

# ---------------------------------------------------------------------

=item __get_ocr

Description

=cut

# ---------------------------------------------------------------------
sub __get_ocr {
    my $self = shift;
    my $item_id = shift;
    
    my $ck = Time::HiRes::time();
    my $temp_dir ;
    eval {
        $temp_dir = $self->__extract_ocr_to_path($item_id);
    };
    if ($@) {
        my $s = qq{__extract_ocr_to_path failed: id=$item_id error:$@};
        Utils::Logger::__Log_simple($s);
        DEBUG('doc', $s);

        return undef;
    }
    my $cke = Time::HiRes::time() - $ck;
    DEBUG('doc', qq{OCR: zipfile extracted to dir="$temp_dir" in sec=$cke});

    return $temp_dir;
}

# ---------------------------------------------------------------------

=item __ocr_existence_test

Description

=cut

# ---------------------------------------------------------------------
sub __ocr_existence_test {
    my $dir_handle = shift;
    my $temp_dir = shift;
    my $item_id = shift;

    my $ocr_exists = 1;
    my $g_ocr_file_regexp = qq{^.+?\.txt$};
    my @ocr_filespecs = grep(/$g_ocr_file_regexp/os, readdir($dir_handle));
    if (scalar(@ocr_filespecs) == 0) {
        DEBUG('doc', qq{OCR: no files in $temp_dir match regexp="$g_ocr_file_regexp", item_id="$item_id"});
        $ocr_exists = 0;
    }

    return ($ocr_exists, \@ocr_filespecs);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_ocr_data

Description

=cut

# ---------------------------------------------------------------------
sub get_ocr_data {
    my $self = shift;
    my ($C, $item_id) = @_;

    my $start = Time::HiRes::time();

    # ----- Extract OCR -----
    my $temp_dir = __get_ocr($self, $item_id);
    my $DIR;
    if (! opendir($DIR, $temp_dir)) {
        my $s = qq{OCR: failed to open dir="$temp_dir", item_id="$item_id"};
        Utils::Logger::__Log_simple($s);        
        DEBUG('doc', $s);

        return (undef, 0);
    }
    # POSSIBLY NOTREACHED

    # ----- Test OCR files exist ----- there exist objects without OCR files
    my ($ocr_exists, $ocr_filespecs_ref) = __ocr_existence_test($DIR, $temp_dir, $item_id);
    closedir($DIR);

    my $ocr_text_ref;
    my $pairtree_item_id = Identifier::get_pairtree_id_wo_namespace($item_id);
    my $concat_filename = Utils::Extract::get_formatted_path("/ram/OCR-$pairtree_item_id", ".txt");

    if ($ocr_exists) {
        # ----- Create concatenated file -----
        my $rc = __concat_files($temp_dir, $ocr_filespecs_ref, $concat_filename);
        if ($rc > 0) {
            return (undef, 0);
        }
        # POSSIBLY NOTREACHED

        $ocr_text_ref = Utils::read_file($concat_filename, 1);
        if (! $ocr_text_ref) {
            my $s = qq{Utils::read_file failed: concat_file=$concat_filename};
            Utils::Logger::__Log_simple($s);
            DEBUG('doc', $s);

            return (undef, 0);
        }
        # POSSIBLY NOTREACHED

        if ($$ocr_text_ref eq '') {
            my $empty_ocr_sentinel = $C->get_object('MdpConfig')->get('ix_index_empty_string');
            $ocr_text_ref = \$empty_ocr_sentinel;
        }

        __clean_xml($self, $ocr_text_ref);    
    }
    else {
        system("touch", $concat_filename);
        my $empty_ocr_sentinel = $C->get_object('MdpConfig')->get('ix_index_empty_string');
        $ocr_text_ref = \$empty_ocr_sentinel;
    }

    __maybe_preserve_doc($ocr_text_ref, $concat_filename);

    __cleanup_ocr_process($concat_filename, $temp_dir);

    my $elapsed = Time::HiRes::time() - $start;
    DEBUG('doc', qq{OCR: total elapsed sec=$elapsed});

    return ($ocr_text_ref, $elapsed);
}


# ---------------------------------------------------------------------

=item PUBLIC CLASS METHOD: normalize_solr_date

From mysql we expect e.g. 1999-01-20.  The format Solr needs is of the
form 1995-12-31T23:59:59Z, and is a more restricted form of the
canonical representation of dateTime
http://www.w3.org/TR/xmlschema-2/#dateTime The trailing "Z" designates
UTC time and is mandatory.  Optional fractional seconds are allowed:
1995-12-31T23:59:59.999Z All other components are mandatory.

=cut

# ---------------------------------------------------------------------
sub normalize_solr_date
{
    my $date_in = shift;
    return $date_in . 'T00:00:00Z';
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
