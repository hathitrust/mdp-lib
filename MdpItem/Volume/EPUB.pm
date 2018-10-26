package MdpItem::Volume::EPUB;

use strict;

use base 'MdpItem';

use Debug::DUtils;

sub quack {
    my $self = shift;
    return "QUACK";
}

sub GetPackageId {
  my $self = shift;
  foreach my $fileid ( keys %{ $$self{fileGrpHash} } ) {
    next if ( $$self{fileGrpHash}{$fileid}{filegrp} ne 'epubfile' );
    return $fileid;
  }
}

sub BuildFileGrpHash {
    my $self = shift;
    $self->SUPER::BuildFileGrpHash(@_);
    $self->Set('has_ocr', $self->Get('has_text'));
    # print STDERR "AHOY :: BuildFileGrpHash :: " . $self->Get('has_text') . " :: " . $self->Get("has_ocr") . "\n";
}

# ----------------------------------------------------------------------
# NAME         : GetFilePathMaybeExtract
# PURPOSE      : Extract ocr/image for a given seq from zip archive and drop
#                it in the input cache
#                unless it's already in the cache or not zipped
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetFilePathMaybeExtract {
    my $self = shift;
    my $sequence = shift;
    my $which = shift;
    my $suffix = shift;

    my $filePath;

    $which = 'textfile' if ( $which eq 'ocrfile' );

    my $fileName;
    if ( $sequence =~ m,^\d+, && $which ) {
        # it's really a sequence
        $fileName = $self->GetFileNameBySequence($sequence, $which);
    } else {
        # treat $sequence as a fileid
        $fileName = $self->GetFileById($sequence);
    }
    return (undef, undef)
      if (! $fileName);
    # POSSIBLY NOTREACHED

    my $fileSystemLocation = $self->Get( 'filesystemlocation' );

    if ($self->ItemIsZipped())
    {
        # Extract file to the input cache location
        my $C = new Context;
        my $input_cache_dir = Utils::get_true_cache_dir($C, 'epub_cache_dir');
        $input_cache_dir .= '/' . Identifier::id_to_mdp_path($self->GetId()) . "_" . $self->get_modtime();
        $input_cache_dir .= '_' . $ENV{USER} if ( $ENV{USER} );

        if ( -f "$input_cache_dir/$fileName" ) {
            return ( $fileName, "$input_cache_dir/$fileName" );
        }

        Utils::mkdir_path( $input_cache_dir, "/dev/null" );
        $filePath =
            Utils::Extract::extract_file_to_temp_cache
                (
                 $self->GetId(),
                 $fileSystemLocation,
                 $fileName,
                 $suffix,
                 $input_cache_dir
                );

    }
    else
    {
        # File is already available
        $filePath = $fileSystemLocation . qq{/$fileName};
    }

    return ($fileName, $filePath);
}

sub _visitDiv {
    my $self = shift;
    my ( $parent, $type, $fileGrpHash, $contentsInfoHashRef ) = @_;
    foreach my $node ( $parent->findnodes(q{*}) ) {
        if ( $node->localName eq 'div' ) {
            my $subtype = $type;
            if ( my $tmp = $node->getAttribute('TYPE') ) {
                $subtype .= ".$tmp";
            }
            $self->_visitDiv($node, $subtype, $fileGrpHash, $contentsInfoHashRef);
        } elsif ( $node->localName eq 'fptr' ) {
            my $fileid = $node->getAttribute('FILEID');
            unless ( ref($$contentsInfoHashRef{$type}) ) {
                $$contentsInfoHashRef{$type} = [];
            }
            push @{ $$contentsInfoHashRef{$type} }, $fileid;

        }
    }
}

# ---------------------------------------------------------------------

=item ParseStructMap

structMap contains page numbers and feature metadata + reading order:
use the file group hash to populate %pageInfoHash based on the order
in the structMap

=cut

# ---------------------------------------------------------------------
sub ParseStructMap {
    my $self = shift;
    my ($root, $fileGrpHashRef, $pageInfoHashRef, $seq2PageNumberHashRef, $featureRecordRef) = @_;

    # tombstone objects have an empty structMap
    my $xpath = q{/METS:mets/METS:structMap//METS:div[@ORDER]};
    my $structMap = $root->findnodes($xpath);

    my $hasPNs = 0;
    my $hasPFs = 0;

    my %featureTable;
    my $featureTableCt = 0;
    my $featureHashRef = {};
    my @featureTags = keys( %$featureHashRef );
    my $featureTableHashRef = \%featureTable;

    ## APPROACH 2: re-order the array of $metsDivs
    my @nodeListAndOrder = ();
    my @orders = ();
    foreach my $metsDiv ( $structMap->get_nodelist ) {
        my $order = $metsDiv->getAttribute('ORDER');
        push @nodeListAndOrder, [ $order, $metsDiv ];
        push @orders, $order;
    }

    if ( $self->Get('readingOrder') eq 'right-to-left' && $self->Get('scanningOrder') eq 'left-to-right' ) {
        @orders = reverse @orders;
        my $tmp = {};
        foreach my $i ( 0 .. $#orders ) {
            $$tmp{"v2p",$orders[$i]} = $nodeListAndOrder[$i]->[0];
            $$tmp{"p2v", $nodeListAndOrder[$i]->[0]} = $orders[$i];
            $nodeListAndOrder[$i]->[0] = $orders[$i];
        }
        $self->Set('seqOrderMap', $tmp);
    }

    # foreach my $metsDiv ($structMap->get_nodelist) {
    #     my $order = $metsDiv->getAttribute('ORDER');2v
    while ( scalar @nodeListAndOrder ) {
        my ( $order, $metsDiv ) = @{ shift @nodeListAndOrder };

        my @metsFptrChildren = $metsDiv->getChildrenByTagName('METS:fptr');
        foreach my $child (@metsFptrChildren) {
            my $fileid = $child->getAttribute('FILEID');
            my $filegrp  = $fileGrpHashRef->{$fileid}{'filegrp'};
            my $filename = $fileGrpHashRef->{$fileid}{'filename'};
            my $filetype = $fileGrpHashRef->{$fileid}{'filetype'};
            my $filesize = $fileGrpHashRef->{$fileid}{'filesize'};

            # if a JP2 image has already been referenced, skip further images
            next if ( $filegrp eq 'imagefile' && $pageInfoHashRef->{sequence}{$order}{filetype} eq 'jp2' );

            $pageInfoHashRef->{sequence}{$order}{$filegrp} = $filename;
            $pageInfoHashRef->{sequence}{$order}{filetype} = $filetype if ($filegrp eq 'imagefile');
            $pageInfoHashRef->{sequence}{$order}{$filegrp . 'size'} = $filesize;
        }

        # page numbers
        my $pgnum = $metsDiv->getAttribute('ORDERLABEL');
        $pageInfoHashRef->{sequence}{$order}{pagenumber} = $pgnum;
        $hasPNs++ if (defined($pgnum));
        $seq2PageNumberHashRef->{$order} = $pgnum;

        # page features
        my $pgftr = $metsDiv->getAttribute('LABEL');
        my @pageFeatures = ();
        push @pageFeatures, $pgftr if ( $pgftr );
        $$featureHashRef{$pgftr} = $pgftr if ( $pgftr );
        $pageInfoHashRef->{sequence}{$order}{pagefeatures} = \@pageFeatures;
        my $order_has_PFs = (scalar(@pageFeatures) > 0);
        $hasPFs ||= $order_has_PFs;

        if ( $pgftr ) {
            $$featureTableHashRef{$featureTableCt}{'tag'} = $order;
            $$featureTableHashRef{$featureTableCt}{'label'} = $pgftr;
            # $$featureTableHashRef{$featureTableCt}{'pg'} = $order;
            # Advance seq one image beyond boundary
            $$featureTableHashRef{$featureTableCt}{'seq'} = $order;
            $featureTableCt += 1;
        }
    }

    $self->SetHasPageNumbers($hasPNs);
    $self->SetHasPageFeatures($hasPFs);

    $self->Set('featuretable', \%featureTable);
    $self->Set('featureHash', $featureHashRef);
}

sub add_to_feature_table {
    my ($seq, $pgnum, $featureTagArrRef, $seqFeaturesArrRef, $featureHashRef, $featureTableHashRef, $table_ct_ref) = @_;

    # foreach my $seqFeature (@$seqFeaturesArrRef) {
    #     if (1)) {
    #         $$featureTableHashRef{$$table_ct_ref}{'tag'} = $seqFeature;
    #         $$featureTableHashRef{$$table_ct_ref}{'label'} = $$featureHashRef{$seqFeature};
    #         $$featureTableHashRef{$$table_ct_ref}{'pg'} = $pgnum;
    #         # Advance seq one image beyond boundary
    #         $$featureTableHashRef{$$table_ct_ref}{'seq'} = ($seqFeature =~ m,^MULTI,o) ? $seq + 1 : $seq ;
    #         $$table_ct_ref++;
    #         last;
    #     }
    # }
}

sub GetPageFeature {
    my $self = shift;
    my $seq = shift;
    if (defined $self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}) {
        return $self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}->[0];
    }
    else {
        return "";
    }
}

sub GetFeatureHash {
    my $self = shift;

    return $self->Get('featureHash');
}

sub GetContent {
    my $self = shift;
    my $type = shift;
    my $contentsInfoHashRef = $self->Get('contentinfo');
    if ( exists $$contentsInfoHashRef{$type} ) {
        return @{ $$contentsInfoHashRef{$type} };
    }
    return ();
}

sub GetFileIdByIndex {
    my $self = shift;
    my $index = shift;
    my $filegrp = shift;

    my $fileid = $$self{contentinfo}{sequence}{$index}{$filegrp};
    return $fileid;

}

sub GetFileIdByXlinkHref {
    my $self = shift;
    my $xlink_href = shift;
    return $$self{xlinkinfo}{$xlink_href};
}

sub GetStoredFileGroup {
    my $self = shift;
    return '';
}

sub GetItemCover {
  my $self = shift;
  # no cover
  return undef;
}

1;