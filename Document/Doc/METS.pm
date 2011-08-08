package Document::Doc::METS;


=head1 NAME

Document::Doc::METS (mo)

=head1 DESCRIPTION

This class provides a lightweight METS parsing service to return
various bit from a METS object fileSec/fileGrp | structMap.

=head1 SYNOPSIS

my $mo = new Document::Doc::METS($C, $item_id, $USE_attr_arr_ref);

=head1 METHODS

=over 8

=cut

use strict;

use XML::LibXML;

use Context;
use MdpGlobals;
use Utils;
use Identifier;


sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}

# ---------------------------------------------------------------------

=item _initialize

Description

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my ($C, $id, $USE_attr_arr_ref) = @_;

    my $mets_xml_filename = __get_METS_xml_filename($id);
    my $mets_xml_ref = Utils::read_file($mets_xml_filename);

    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_string($$mets_xml_ref);
    my $root = $tree->getDocumentElement();

    $self->build_METS_dataset($root, $USE_attr_arr_ref);
}


# ---------------------------------------------------------------------

=item get_seq2pgnum_map

Description

=cut

# ---------------------------------------------------------------------
sub get_seq2pgnum_map {
    my $self = shift;
    my ($C, $USE) = @_;

    my $map = $self->{dataset}{$USE}{METS_seq2pgnum};
    return $map;
}

# ---------------------------------------------------------------------

=item get_filelist_for

Description

=cut

# ---------------------------------------------------------------------
sub get_filelist_for {
    my $self = shift;
    my ($C, $USE) = @_;

    my $files_arr_ref = $self->{dataset}{$USE}{METS_filelist};
    return $files_arr_ref;
}

# ---------------------------------------------------------------------

=item get_has_files_for

Description

=cut

# ---------------------------------------------------------------------
sub get_has_files_for {
    my $self = shift;
    my ($C, $USE) = @_;

    my $has_files =  $self->{dataset}{$USE}{METS_has_files};    
    return $has_files;
}

# ---------------------------------------------------------------------

=item get_num_files_for

Description

=cut

# ---------------------------------------------------------------------
sub get_num_files_for {
    my $self = shift;
    my ($C, $USE) = @_;

    my $num_files =  $self->{dataset}{$USE}{METS_has_files};    
    return $num_files;
}


# ---------------------------------------------------------------------

=item build_METS_dataset

Description

=cut

# ---------------------------------------------------------------------
sub build_METS_dataset {
    my $self = shift;
    my ($root, $USE_attr_arr_ref) = @_;

    my %METS_hash = ();
    my $file_grp_hashref = $self->parse_fileGrp($root, $USE_attr_arr_ref);

    my $xpath = q{/METS:mets/METS:structMap//METS:div[@ORDER]};
    my $structMap = $root->findnodes($xpath);

    foreach my $metsDiv ($structMap->get_nodelist) {
        my $order = $metsDiv->getAttribute('ORDER');
        my $pgnum = $metsDiv->getAttribute('ORDERLABEL');

        my @metsFptrChildren = $metsDiv->getChildrenByTagName('METS:fptr');
        foreach my $child (@metsFptrChildren) {
            my $fileid = $child->getAttribute('FILEID');

            foreach my $USE (@$USE_attr_arr_ref) {
                last
                  if (! defined($file_grp_hashref->{$USE}{$fileid}));
                
                my $filename  = $file_grp_hashref->{$USE}{$fileid};

                my $USE_order_hashref = {
                                         'filename' => $filename,
                                         'pgnum'    => $pgnum,
                                         'order'    => $order,
                                        };

                $METS_hash{$USE}{seq}{$order} = $USE_order_hashref;
                $METS_hash{$USE}{has_files} = $file_grp_hashref->{$USE}{has_files};
            }
        }
    }

    foreach my $USE (@$USE_attr_arr_ref) {
        my $files_arr_ref = [];
        my $seq2pgnum_hashref = {};
            
        foreach my $order (sort {$a <=> $b} keys %{ $METS_hash{$USE}{seq} }) {
            push(@$files_arr_ref, $METS_hash{$USE}{seq}{$order}->{filename});
            $seq2pgnum_hashref->{$order} = $METS_hash{$USE}{seq}{$order}->{'pgnum'}
        }
        $self->{dataset}{$USE}{METS_filelist} = $files_arr_ref;
        $self->{dataset}{$USE}{METS_has_files} = $METS_hash{$USE}{has_files};
        $self->{dataset}{$USE}{METS_seq2pgnum} = $seq2pgnum_hashref;
    }
}


# ---------------------------------------------------------------------

=item parse_fileGrp

Description

=cut

# ---------------------------------------------------------------------
sub parse_fileGrp {
    my $self = shift;
    my ($root, $USE_attr_arr_ref) = @_;

    my $file_grp_hashref = {};

    foreach my $USE (@$USE_attr_arr_ref) {
        # Note fileGrp[@USE='ocr']: some objects may lack this group
        my $xpath = q{/METS:mets/METS:fileSec/METS:fileGrp[@USE='} . $USE. q{']/METS:file};
        my $_file_grp = $root->findnodes($xpath);
        my $has_files = scalar(@$_file_grp);

        if ($has_files) {
            # Test for all zero-length files.
            my $total_file_size = 0;
            foreach my $node ($_file_grp->get_nodelist) {
                my $fileid = $node->getAttribute('ID');
                my $filesize = $node->getAttribute('SIZE');
                my $filename = ($node->childNodes)[1]->getAttribute('xlink:href');
                $file_grp_hashref->{$USE}{$fileid} = $filename;

                $total_file_size += $filesize;
            }
            $has_files = 0 if ($total_file_size == 0);
        }
        $file_grp_hashref->{$USE}{has_files} = $has_files;
    }

    return $file_grp_hashref
}

# ---------------------------------------------------------------------

=item __get_METS_xml_filename

Description

=cut

# ---------------------------------------------------------------------
sub __get_METS_xml_filename {
    my $id = shift;

    my $itemFileSystemLocation = Identifier::get_item_location($id);
    my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);

    return $itemFileSystemLocation . qq{/$stripped_id} . $MdpGlobals::gMetsFileExtension;
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
