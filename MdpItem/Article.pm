package MdpItem::Article;
# MdpItem::Article

use strict;

use base 'MdpItem';

use Debug::DUtils;

sub quack {
	my $self = shift;
	return "QUACK";
}

# ---------------------------------------------------------------------

=item SetPageInfo

Description

=cut

# ---------------------------------------------------------------------
sub SetPageInfo {
    my $self = shift;

    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(START)</h3>} . Utils::display_stats());

    my $root = $self->_GetMetsRoot();

    my %fileGrpHash = ();

    $self->BuildFileGrpHash
      (
       $root,
       \%fileGrpHash
      );
    
    $self->SetFileGroupMap(\%fileGrpHash);

    my %xlinkInfoHash = ();
    foreach my $fileid ( keys %fileGrpHash ) {
    	$xlinkInfoHash{$fileGrpHash{$fileid}{filename}} = $fileid;
    }

    $$self{xlinkinfo} = \%xlinkInfoHash;

    my %contentsInfoHash = ();
    my %featureRecord = ();

    $self->ParseStructMap
      (
       $root,
       \%fileGrpHash,
       \%contentsInfoHash,
      );

    $$self{contentinfo} = \%contentsInfoHash;

    # Note: MUST FOLLOW SUPPRESSION CALL ABOVE.
    # $self->SetHasTOCFeature($featureRecord{hasPF_TOC});
    # $self->SetHasTitleFeature($featureRecord{hasPF_TITLE});
    # $self->SetHasFirstContentFeature($featureRecord{hasPF_FIRST_CONTENT});
    # $self->SetHasMULTIFeature($featureRecord{hasPF_MULTI});

    my ($version, $was_deleted) = $self->ParseVersionFromPREMIS($root);
    $self->Version($version, $was_deleted);
    
    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(END)</h3>} . Utils::display_stats());
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

sub ParseStructMap {
	my $self = shift;
    my ($root, $fileGrpHashRef, $contentsInfoHashRef) = @_;

    # tombstone objects have an empty structMap
    # first get the physical structMap
    my $xpath = q{/METS:mets/METS:structMap[@TYPE='physical']/METS:div[@TYPE='contents']/METS:div};
    my $structMap = $root->findnodes($xpath);
    
    my $hasPNs = 0;
    my $hasPFs = 0;

    # my %featureTable;
    # my $featureTableCt = 0;
    # my $featureHashRef = $self->GetFeatureHash();
    # my @featureTags = keys( %$featureHashRef );
    my $namespace = $self->Get('namespace');

    my $idx = 0;
    foreach my $metsDiv ($structMap->get_nodelist) {
        $self->_visitDiv($metsDiv, $metsDiv->getAttribute('TYPE'), $fileGrpHashRef, $contentsInfoHashRef);
    	# $idx += 1;

     #    my @metsFptrChildren = $metsDiv->getChildrenByTagName('METS:fptr');
     #    foreach my $child (@metsFptrChildren) {
     #        my $fileid = $child->getAttribute('FILEID');
     #        my $filegrp  = $fileGrpHashRef->{$fileid}{'filegrp'};

     #        # since we don't do any of the pageInfo structure, we can get
     #        # away with some indirection
     #        $$contentsInfoHashRef{$idx}{$filegrp} = $fileid;
     #        # $$contentsInfoHashRef{$idx}{fileid} = $fileid;
     #        # $$contentsInfoHashRef{$idx}{filetype} = $filetype if ($filegrp eq 'articlefile');
     #        # $$contentsInfoHashRef{$idx}{$filegrp . 'size'} = $filesize;
     #    }

    }

    # $self->SetHasPageNumbers($hasPNs);    
    # $self->SetHasPageFeatures($hasPFs);

    # $self->Set('featuretable', \%featureTable);
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

	my $fileid = $$self{contentinfo}{$index}{$filegrp};
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

1;