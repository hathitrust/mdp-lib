package MdpItem;

=head1 NAME

MdpItem

=head1 DESCRIPTION

Interface to the "MdpItem", e.g. data in the $id.mets.xml file.

Extracted from PT::MdpItem; only concerned with $id.mets.xml data.

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use strict;
use MirlynGlobals;

# MDP
use MdpGlobals;
use Debug::DUtils;
use Utils;
use Utils::Serial;
use Utils::Extract;
use Context;
use Auth::Auth;
use Identifier;

use Utils::Cache::Storable;

use XML::LibXML;

# Global variables

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetMetsXmlFromFile
{
    my $metsXmlFilename = shift;

    my $metsXmlRef = Utils::read_file( $metsXmlFilename );

    return $metsXmlRef;
}

sub GetMetsXmlFilename
{
    my ($itemFileSystemLocation, $id) = @_;

    my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);
    return $itemFileSystemLocation . qq{/$stripped_id} . $MdpGlobals::gMetsFileExtension;
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetMetadataFromMirlyn
{
    my ($C, $id) = @_;

    my $metadata = undef;
    my $url = $MirlynGlobals::gMirlynMetadataURL;
    $url =~ s,__METADATA_ID__,$id,;

    DEBUG('pt,mirlyn,all', qq{<h3>Mirlyn metadata URL: $url</h3>});
    DEBUG('time', qq{<h3>PageTurnerUtils::GetMetadataFromMirlyn(START)</h3>} . Utils::display_stats());

    my $response = Utils::get_user_agent()->get($url);
    my $responseOk = $response->is_success;
    my $responseStatus = $response->status_line;
    my $metadata_failed = 0;

    if ( $responseOk  )
    {
        $metadata = $response->content;

        DEBUG('ptdata,mirlyn',
              sub
              {
                  my $data = $metadata; Utils::map_chars_to_cers(\$data, [q{"}, q{'}]);
                  return qq{<h4>Mirlyn metadata:<br/></h4> $data};
              });

        # Point to surrogate data if the metadata is empty or there
        # was an error
        if ((! $metadata ) || ($metadata =~ m,<error>.*?</error>,))
        {
            $metadata_failed = 1;
            $metadata = <PageTurnerUtils::DATA>
        }
    }
    else
    {
        $metadata_failed = 1;
        $metadata = <PageTurnerUtils::DATA>;

        if (DEBUG('all,pt,mirlyn'))
        {
            ASSERT($responseOk,
                    qq{ERROR in PageTurnerUtils::GetMdpItem: Agent Status: $responseStatus});
        }
        else
        {
            soft_ASSERT($responseOk,
                        qq{ERROR in PageTurnerUtils::GetMdpItem: Agent Status: $responseStatus})
                if ($MdpGlobals::gMirlynErrorReportingEnabled);
        }
    }
    $metadata = Encode::decode_utf8($metadata);
    DEBUG('time', qq{<h3>PageTurnerUtils::GetMetadataFromMirlyn(END)</h3>} . Utils::display_stats());

    return (\$metadata, $metadata_failed);
}

# ----------------------------------------------------------------------
# NAME         : GetMdpItem
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetMdpItem
{
    my $class = shift;
    my ($C, $id, $itemFileSystemLocation ) = @_;
    my $config = $C->get_object('MdpConfig');

    $itemFileSystemLocation = Identifier::get_item_location($id) unless ( $itemFileSystemLocation );

    my $cache; my $cache_key = qq{mdpitem};
    my $mdpItem;
    
    my $t0 = time;
    my $cache_mdpItem = ( $config->get('mdpitem_use_cache') eq 'true' );
    if ( $cache_mdpItem ) {
        DEBUG('time', qq{<h3>Start mdp item uncache</h3>} . Utils::display_stats());
        
        my $cache_dir = Utils::get_true_cache_dir('mdpitem_cache_dir');
        $cache = Utils::Cache::Storable->new($cache_dir);
        $mdpItem = $cache->Get($id, $cache_key);
        DEBUG('time', qq{<h3>Finish mdp item uncache</h3>} . Utils::display_stats());

        my $cgi = $C->get_object('CGI');
        if ( $cgi->param('newsid') ) {
            $mdpItem = undef;
        }
        
    }
    
    # if we already have instantiated and saved on the session the
    # full mdpitem for the id being requested, we have everything we
    # need and can return
    
    # if the cached verison has metadatafailure == 1, re-compute
    
    if ( $mdpItem  && ( $mdpItem->Get( 'id' ) eq $id ) && ( ! $mdpItem->Get('metadatafailure') ) )
    {
        # item is already cached and we have it in $mdpItem.  Test to
        # see if the item files got zipped since the last time we
        # accessed this mdpItem object.
        if (! $mdpItem->ItemIsZipped())
        {
            my $zipfile = $itemFileSystemLocation . qq{/$id.zip};
            if (-e $zipfile)
            {
                $mdpItem->Set('zipfile', $zipfile);
                $mdpItem->SetItemZipped();
            }
        }

        DEBUG('pt,all', qq{<h3>Using cached mdpItem object for id="$id" zipped="}  . ($mdpItem->ItemIsZipped() || '0') . q{"</h3>});
    }
    else
    {

        $mdpItem = $class->new( $C,$id );
        
        DEBUG('pt,all', qq{<h3>Mirlyn metadata failure status for id="$id" = } . $mdpItem->Get('metadatafailure') . qq{</h3>});
        
        
        # don't cache if we've got a metadatafailure
        if ( $cache_mdpItem && ! $mdpItem->Get('metadatafailure') ) {
            $cache->Set($id, $cache_key, $mdpItem);
        }
        
    }
    
    DEBUG('mdpitem,all',
          sub
          {
              return $mdpItem->DumpPageInfoToHtml();
          });
          
    return $mdpItem;
}

# ----------------------------------------------------------------------
# NAME      : new
# PURPOSE   : create new object
# CALLED BY :
# CALLS     : $self->_initialize
# INPUT     : idno,  page sequence number
# RETURNS   : NONE
# NOTES     :
# ----------------------------------------------------------------------
sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}

# ----------------------------------------------------------------------
# NAME      : _initialize
# PURPOSE   : create structure for object
# CALLED BY : new
# CALLS     :
# INPUT     : see new
# RETURNS   :
# NOTES     :
# ----------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my ( $C, $id ) = @_;
    
    if($self->Get('initialized')) {
        return;
    }
    $self->Set('initialized', 1);

    $self->SetId( $id );
    $self->Set('namespace', Identifier::the_namespace($id));
    
    my $itemFileSystemLocation = Identifier::get_item_location($id);
    my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);
    
    my $metsXmlFilename = GetMetsXmlFilename($itemFileSystemLocation, $id);
    my $metsXmlRef = GetMetsXmlFromFile( $metsXmlFilename );

    my ($metadataRef, $metadata_failed) = GetMetadataFromMirlyn($C, $id);

    # Reduce size of METS
    $self->DeleteExtraneousMETSElements($metsXmlRef);

    $self->Set( 'metsxml', $metsXmlRef );
    $self->Set( 'metsxmlfilename', $metsXmlFilename );
    $self->Set( 'filesystemlocation', $itemFileSystemLocation );

    my $zipfile = $itemFileSystemLocation . qq{/$stripped_id.zip};
    if (-e $zipfile)
    {
        $self->SetItemZipped();
        $self->Set('zipfile', $zipfile);
    }

    my $source_attribute = $C->get_object('AccessRights')->get_source_attribute($C, $id);
    $self->Set( 'source_attribute', $source_attribute );

    $self->Set( 'marcmetadata', $metadataRef );

    # --------------------------------------------------

    $self->Set( 'metadatafailure', $metadata_failed );

    $self->SetPageInfo();

    if ( $self->HasPageFeatures() )
    {
        $self->BuildFeatureTable();
    }
}


sub Set
{
    my $self = shift;
    my ( $key, $value ) = @_;
    $self->{ $key } = $value;
}

sub Get
{
    my $self = shift;
    my $key = shift;
    return $self->{ $key };
}

sub SetId
{
    my $self = shift;
    my $id = shift;
    $self->{ 'id' } = $id;
}

sub GetMetadataFailure
{
    my $self = shift;
    return $self->{'metadatafailure'};
}

sub ItemIsZipped
{
    my $self = shift;
    return $self->{'itemiszipped'};
}

sub SetItemZipped
{
    my $self = shift;
    $self->{'itemiszipped'} = 1;
}

sub GetId
{
    my $self = shift;
    return $self->{ 'id' };
}

sub InitFeatureIterator
{
    my $self = shift;
    $self->{'featuretableindex'} = 0;;
}

sub GetNextFeature
{
    my $self = shift;

    my $featureTableRef = $self->Get( 'featuretable' );
    return \$$featureTableRef{ $self->{'featuretableindex'}++ };
}

sub GetPageFeatures
{
    my $self = shift;
    my $seq = shift;

    return @{$self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}};
}

sub SetContentHandler
{
    my $self = shift;
    my $handler = shift;

    $self->{ 'contenthandler' } = $handler;
}

sub GetContentHandler
{
    my $self = shift;

    return $self->{ 'contenthandler' };
}

sub SetConcatenate
{
    my $self = shift;
    my $concatenate = shift;

    $self->{ 'concatenatepdf' } = $concatenate;

}

sub GetConcatenate
{
        my $self = shift;
        return $self->{ 'concatenatepdf' };
}

sub GetContainsJp2Jpg
{
        my $self = shift;
        return $self->{ 'containsjp2jpg' };
}

sub SetContainsJp2Jpg
{
    my $self = shift;
    my $jp2 = shift;

    $self->{ 'containsjp2jpg' } = $jp2;

}

sub SetPageCount
{
    my $self = shift;
    my $pages = shift;

    $self->{ 'pagecount' } = $pages;

}

sub GetPageCount
{
        my $self = shift;
        return $self->{ 'pagecount' };
}

sub SetHasPageNumbers
{
    my $self = shift;
    my $has = shift;
    $self->{ 'haspagenumbers' } = $has;
}

sub HasPageNumbers
{
    my $self = shift;
    return $self->{ 'haspagenumbers' };
}

sub SetHasPageFeatures
{
    my $self = shift;
    my $has = shift;
    $self->{ 'haspagefeatures' } = $has;
}

sub HasPageFeatures
{
    my $self = shift;
    return $self->{ 'haspagefeatures' };
}

sub SetHasCoordOCR
{
    my $self = shift;
    my $value = shift || 0;
    $self->{ 'hascoordocr' } = ($MdpGlobals::ghOCREnabled ? 1 : 0);
}

sub HasCoordOCR
{
    my $self = shift;
    return $self->{ 'hascoordocr' };
}

sub SetHasFirstContentFeature
{
    my $self = shift;
    my $has = shift;
    $self->{ 'hasfirstcontentfeature' } = $has;
}

sub HasFirstContentFeature
{
    my $self = shift;
    return $self->{ 'hasfirstcontentfeature' };
}

sub SetHasTitleFeature
{
    my $self = shift;
    my $seqOfTitle = shift;
    $self->{ 'hastitlefeature' } = $seqOfTitle;
}

sub HasTitleFeature
{
    my $self = shift;
    return $self->{ 'hastitlefeature' };
}

sub SetHasTOCFeature
{
    my $self = shift;
    my $seqOfTOC = shift;
    $self->{ 'hastocfeature' } = $seqOfTOC;
}

sub HasTOCFeature
{
    my $self = shift;
    return $self->{ 'hastocfeature' };
}

# ---------------------------------------------------------------------

=item GetFullMetsRef

With the advent of uc namespaces, there are additional dmdSec carrying
unused MARC. Delete those to download less data to the browser.  Whack
the PREMIS section too.

=cut

# ---------------------------------------------------------------------
sub GetFullMetsRef {
    my $self = shift;

    my $metsXmlRef = $self->Get( 'metsxml' );

    # May have already been substituted in
    return $metsXmlRef
        if ($$metsXmlRef =~ m,<metadata>,s);

    my $metadataRef = $self->Get( 'marcmetadata' );
    if ($metadataRef) {
        $$metsXmlRef =~ s,(<METS:dmdSec.+?ID="DMD1".*?>).*?(</METS:dmdSec>), $1 . $$metadataRef . $2,es;
    }

    return $metsXmlRef;
}

sub SetRequestedSize
{
    my $self = shift;
    my $size = shift;
    $self->{ 'requestedsize' } = $size;
}

sub GetRequestedSize
{
    my $self = shift;
    return $self->{ 'requestedsize' };
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub SetCurrentRequestInfo
{
    my $self = shift;
    my ( $C, $validRotationValuesHashRef ) = @_;

    my $cgi = $C->get_object('CGI');

    # check that the requested sequence is within the range of available pages
    $self->CheckCgiSequence( $cgi );

    my $id     = $cgi->param( 'id' );
    my $seq    = $cgi->param( 'seq' );
    my $num    = $cgi->param( 'num' );
    my $user   = $cgi->param( 'u' );
    my $size   = $cgi->param( 'size' );
    my $orient = $cgi->param( 'orient' );

    $self->SetRequestedSize( $size );

    $self->SetRequestedPageSequence( $seq, $num, $user);
    $self->SetConcatenate(0);

    my $requestedSequence = $self->GetRequestedPageSequence();

    # The idea here is that only the "rotate clockwise" and "rotate
    # counterclockwise" links will put an orientation param on the URL
    #
    # if the requested orientation is valid, use it
    #      cannot test: if ( $orient ) because "0" is a valid orientation
    #      and would test false in Perl
    my $orientationToUse;

    if ( exists( $$validRotationValuesHashRef{ $orient } ) )
    {
        $self->SetOrientationForIdSequence( $id, $requestedSequence, $orient );
        $orientationToUse = $orient;
    }

    # if there is no requested orientation, use the page's
    # most-recently saved orientation
    else
    {
        $orientationToUse = $self->GetOrientationForIdSequence( $id, $requestedSequence ) ||
            $MdpGlobals::gDefaultOrientation;
        $self->SetOrientationForIdSequence( $id, $requestedSequence, $orientationToUse );
    }

    $cgi->param( 'orient', $orientationToUse );
}

# ----------------------------------------------------------------------
# NAME         : CheckCgiSequence, GetValidSequence
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub CheckCgiSequence
{
    my $self = shift;
    my $cgi = shift;

    my $validSeq = $self->GetValidSequence( $cgi->param( 'seq' ) );
    $cgi->param( 'seq', $validSeq );
}

sub GetValidSequence
{
    my $self = shift;
    my $seq = shift;

    $seq = 0 if ( $seq !~ m,^[1-9]\d*$, );

    my $firstPage = $self->GetFirstPageSequence();
    my $lastPage = $self->GetLastPageSequence();

    return $lastPage     if ( $seq > $lastPage );
    return $firstPage    if ( $seq < $firstPage );
    return $seq;
}

# ----------------------------------------------------------------------
# NAME         : SetRequestedPageSequence
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        : This have become heavier to support user-entered values
#                that will be interpreted as either a page number or a
#                sequence number depending on which is supported by the
#                metadata.  Since page numbers are not unique due to
#                scanning errors and reuse of page numbering sequences
#                in multi-section works we depend ultimately on the
#                sequence number to deliver the right physical page.
# ----------------------------------------------------------------------
sub SetRequestedPageSequence
{
    my $self = shift;
    my ( $pageSequence, $pageNumber, $userEntered, $chunk ) = @_;

    my $finalSequenceNumber;
    $pageSequence = $self->GetValidSequence( $pageSequence );

    if ( $self->HasPageNumbers() )
    {
        # If page number is supplied map it to a sequence number but
        # only if user entered.  Otherwise we treat it as a display
        # only value.
        if ( $pageNumber )
        {
            if ( $userEntered )
            {
                my $page2SeqNumberHashRef = $self->GetPage2SequenceMap();
                my $trialSequenceNumber = $$page2SeqNumberHashRef{$pageNumber};
                if ( $trialSequenceNumber )
                {
                    # seq known to be valid
                    $finalSequenceNumber = $trialSequenceNumber;
                }
                else
                {
                    # seq validity enforced by caller
                    $finalSequenceNumber = $pageSequence;
                }
            }
            else
            {
                $finalSequenceNumber = $pageSequence;
            }
        }
        else
        {
            # If no page number is supplied use the page sequence
            # (validity enforced by caller)
            $finalSequenceNumber = $pageSequence;
        }
    }
    else
    {
        # Item does not have page number metadata. The page number,
        # if supplied, should be treated as a sequence number if
        # entered by the user and valid.  Otherwise use $pageSequence.
        # Enforce validity on pageNumber.  $pageSequence enforced
        # above.
        if ( $pageNumber )
        {
            if ( $userEntered )
            {
                my $testPageNumber = $self->GetValidSequence( $pageNumber );
                if ( $testPageNumber eq $pageNumber )
                {
                    # Page number is valid as a sequence number
                    $finalSequenceNumber = $pageNumber;
                }
                else
                {
                    $finalSequenceNumber = $pageSequence;
                }
            }
            else
            {
                $finalSequenceNumber = $pageSequence;
            }
        }
        else
        {
            $finalSequenceNumber = $pageSequence;
        }
    }

    $self->{ 'requestedpagesequence' } = $finalSequenceNumber;
}

sub GetRequestedPageSequence
{
    my $self = shift;
    return $self->{ 'requestedpagesequence' };
}

sub GetPage2SequenceMap
{
    my $self = shift;
    return $self->{ 'pageinfo' }{ 'page2sequencemap' };
}

sub SetLastPageSequence
{
    my $self = shift;
    my $lastPageSequence = shift;
    $self->{ 'lastpagesequence' } = $lastPageSequence;
}

sub GetLastPageSequence
{
    my $self = shift;
    return $self->{ 'lastpagesequence' };
}

sub SetFirstPageSequence
{
    my $self = shift;
    my $firstPageSequence = shift;
    $self->{ 'firstpagesequence' } = $firstPageSequence;
}

sub GetFirstPageSequence
{
    my $self = shift;
    return $self->{ 'firstpagesequence' };
}

# ----------------------------------------------------------------------
# NAME         : GetSequenceForPageNumber
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetSequenceForPageNumber
{
    my $self = shift;
    my ( $num, $defaultSeq ) = @_;

    my $finalSequenceNumber;

    if ( $self->HasPageNumbers() )
    {
        my $page2SeqNumberHashRef = $self->GetPage2SequenceMap();
        my $trialSequenceNumber = $$page2SeqNumberHashRef{$num};

        if ( $trialSequenceNumber )
        {
            $finalSequenceNumber = $trialSequenceNumber;
        }
        else
        {
            $finalSequenceNumber = $defaultSeq;
        }
    }
    else
    {
        $finalSequenceNumber = $num ? $num : $defaultSeq;
    }

    return $finalSequenceNumber;
}

sub GetStoredFileType
{
    my $self = shift;
    my $pageSequence = shift;

    my $pageInfoHashRef = $self->{ 'pageinfo' };

    return $$pageInfoHashRef{ 'sequence' }{ $pageSequence }{ 'filetype' };
}

sub GetFullTitle
{
    my $self = shift;
    my $title;

    my $id = $self->GetId();

    if (! Identifier::has_MARC_metadata( $id ))
    {
        # For now we only do volume data for MARC for MDP
        return $title;
    }
    
    my $marcMetadataRef = $self->Get( 'marcmetadata' );
    my ($varfield) = ($$marcMetadataRef =~ m,<varfield id="245"[^>]*>(.*?)</varfield>,s);
    ($title)     = ($varfield =~ m,<subfield label="a">(.*?)</subfield>,g);

    ($title)     = ($varfield =~ m,<subfield label="b">(.*?)</subfield>,g)
        unless ( $title );
    
    ($title)     = ($varfield =~ m,<subfield label="c">(.*?)</subfield>,g)
        unless ( $title );
    
    my $dataRef = $self->GetVolumeData();
    my $frag = $$dataRef{$id}{'vol'};
    
    if ( $frag ) {
        $title .= " " . $frag;
    }
    
    return $title;
}

sub GetAuthor
{
    my $self = shift;
    my @values = ();

    my $id = $self->GetId();

    if (! Identifier::has_MARC_metadata( $id ))
    {
        # For now we only do volume data for MARC for MDP
        return "";
    }
    
    my $marcMetadataRef = $self->Get( 'marcmetadata' );
    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_string($$marcMetadataRef);
    my $root = $tree->getDocumentElement();
    
    foreach my $node ( $root->findnodes(qq{/present/record/metadata/oai_marc/varfield[\@id='100']}) ) {
        # a - Personal name
        # b - Numeration
        # c - titles associated with name
        # e - relator term
        # q - fuller form of name
        # d - dates associated with name
        my @tmp = ();
        foreach my $subid (qw(a b c e q d)) {
            my ( $value ) = $node->findvalue("subfield[\@label='$subid']");
            if ( $value ) {
                ## push @values, " " unless ( $subid eq 'a' );
                push @tmp, $value;
            }
        }
        push @values, join(" ", @tmp) if ( scalar @tmp );
    }

    foreach my $node ( $root->findnodes(qq{/present/record/metadata/oai_marc/varfield[\@id='110']}) ) {
        my ( $value ) = $node->findvalue("subfield[\@label='a']");      # corporate name
        if ( $value ) {
            push @values, $value;
        }
        if ( $node->exists("subfield[\@label='b']") ) {                 # subordinate unit
            ( $value ) = $node->findvalue("subfield[\@label='c']");     # location of meeting?
            if ( $value ) {
                ## push @values, " "; # &x32 in XSLT?
                push @values, $value;
            }
        }
    }
    
    foreach my $node ( $root->findnodes(qq{/present/record/metadata/oai_marc/varfield[\@id='111']}) ) {
        my ( $value ) = $node->findvalue("subfield[\@label='a']");      # meeting name
        if ( $value ) {
            push @values, $value;
        }
    }
    
    return join('; ', @values);

}

# ----------------------------------------------------------------------
# NAME         : GetVolumeData
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetVolumeData
{
    my $self = shift;

    my %volHash;

    my $id = $self->GetId();

    if (! Identifier::has_MARC_metadata( $id ))
    {
        # For now we only do volume data for MARC for MDP
        return \%volHash;
    }

    # Parse and cache the marc metadata for volume ids and title
    # string fragments and this infor specifically for the current id
    my $journalVolHashRef = $self->Get( 'volhashref' );
    if ( $journalVolHashRef )
    {
        return $journalVolHashRef;
    }

    my $marcMetadataRef = $self->Get( 'marcmetadata' );
    my $marcForIdHashRef = Utils::Serial::get_volume_data($marcMetadataRef);

    %volHash = (
                $id => $marcForIdHashRef,
               );

    $self->Set( 'volhashref', \%volHash );

    return  \%volHash;
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub BuildFeatureTable
{
    my $self = shift;

    my %featureTable;

    my $featureHashRef = $self->GetFeatureHash();
    my @featureTags = keys( %$featureHashRef );

    my $pageInfoHashRef = $self->Get( 'pageinfo' );

    my @seqsArray = keys( % {$$pageInfoHashRef{'sequence'}} );
    @seqsArray = sort { $a <=> $b } ( @seqsArray );
    my $j = 0;
    for ( my $i=0; $i < scalar( @seqsArray ); $i++ )
    {
        my $seq = $seqsArray[$i];

        my $featuresArrRef = $$pageInfoHashRef{'sequence'}{ $seq }{'pagefeatures'};
        foreach my $featureTag ( @featureTags )
        {
            if ( grep( /$featureTag/, @$featuresArrRef ) )
            {
                $featureTable{$j}{'tag'} = $featureTag;
                $featureTable{$j}{'label'} = $$featureHashRef{$featureTag};
                $featureTable{$j}{'pg'} = $$pageInfoHashRef{'sequence'}{ $seq }{'pagenumber'};
                $featureTable{$j}{'seq'} = $seq;
                $j++;
                last;
            }
        }
    }

    $self->Set( 'featuretable', \%featureTable );
}


# ---------------------------------------------------------------------

=item handle_MIUN_features

Description

=cut

# ---------------------------------------------------------------------
sub handle_MIUN_features
{
    my ($pgftr, $order, $hasPF_FCref, $hasPF_TOCref, $hasPF_TITLEref) = @_;

    $$hasPF_FCref = $order
        if (! $$hasPF_FCref && ( $pgftr =~ m,1STPG,o ));

    $$hasPF_TITLEref = $order
        if (! $$hasPF_TITLEref && ( $pgftr =~ m,TPG|CTP|VTP|VTV,o ));

    $$hasPF_TOCref = $order
        if (! $$hasPF_TOCref && ( $pgftr =~ m,TOC,o ));
}

# ---------------------------------------------------------------------

=item handle_MDP_features

Description

=cut

# ---------------------------------------------------------------------
sub handle_MDP_features
{
    my ($pgftr, $order, $hasPF_FCref, $hasPF_TOCref, $hasPF_TITLEref) = @_;

    $$hasPF_FCref = $order
        if (! $$hasPF_FCref && ( $pgftr =~ m,FIRST_CONTENT_CHAPTER_START,o ));

    $$hasPF_TITLEref = $order
        if (! $$hasPF_TITLEref && ( $pgftr =~ m,TITLE,o ));

    $$hasPF_TOCref = $order
        if (! $$hasPF_TOCref && ( $pgftr =~ m,TABLE_OF_CONTENTS,o ));
}

# ---------------------------------------------------------------------

=item build_feature_map

Description

=cut

# ---------------------------------------------------------------------
sub build_feature_map
{
    my $self = shift;
    my $structMap = shift;

    my %seq2PageFeatureHash;
    my %seq2PageNumberHash;

    my $hasPF_FIRST_CONTENT = 0;
    my $hasPF_TOC = 0;
    my $hasPF_TITLE = 0;
    my $hasPNs = 0;
    my $hasPFs = 0;

    foreach my $metsDiv ($structMap->get_nodelist)
    {
        my $order = $metsDiv->getAttribute('ORDER');
        my $pgnum = $metsDiv->getAttribute('ORDERLABEL');
        $pgnum =~ s,^0+,,;
        my $pgftr = $metsDiv->getAttribute('LABEL');
        # miun, miua have different feature tags than everything else
        my $namespace = $self->Get('namespace');
        if  (($namespace eq 'miun') || ($namespace eq 'miua'))
        {
            handle_MIUN_features($pgftr, $order,
                                 \$hasPF_FIRST_CONTENT, \$hasPF_TOC, \$hasPF_TITLE );
        }
        elsif (Identifier::has_MARC_metadata($self->GetId()))
        {
            handle_MDP_features($pgftr, $order,
                                \$hasPF_FIRST_CONTENT, \$hasPF_TOC, \$hasPF_TITLE);
        }

        my @pageFeatures = split( /,\s*/, $pgftr );
        $seq2PageFeatureHash{$order} = \@pageFeatures;
        $seq2PageNumberHash{$order} = $pgnum;
        $hasPNs++ if ( $pgnum );
        $hasPFs ||= ( scalar(@pageFeatures) > 0 );
    }

    my %featureRecord =
        (
         'hasPF_TOC'           => $hasPF_TOC,
         'hasPF_TITLE'         => $hasPF_TITLE,
         'hasPF_FIRST_CONTENT' => $hasPF_FIRST_CONTENT,
        );

    $self->SetHasPageNumbers( $hasPNs );
    $self->SetHasPageFeatures( $hasPFs );

    return (\%seq2PageFeatureHash, \%seq2PageNumberHash, \%featureRecord);
}

# ---------------------------------------------------------------------

=item DeleteExtraneousMETSElements

Description

=cut

# ---------------------------------------------------------------------
sub DeleteExtraneousMETSElements {
    my $self = shift;
    my $metsXmlRef = shift;

   # remove all xml bits since we don't need them in the outp
    $$metsXmlRef =~ s,<\?xml\s+.*?\?>,,s;

    # If not debug=xml, remove other unneeded elements. UC content has
    # an extra dmdSec. The amdSec is PREMIS and not used by
    # pageturner.
    if (! DEBUG('xml')) {
        $$metsXmlRef =~ s,<METS:amdSec>.*?</METS:amdSec>,,s;
        $$metsXmlRef =~ s,<METS:dmdSec.+?ID="DMD2".*?>.*?</METS:dmdSec>,,;
    }
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub SetPageInfo
{
    my $self = shift;

    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(START) START</h3>} . Utils::display_stats());
    my %pageInfoHash = ();
    my $metsXmlRef = $self->Get( 'metsxml' );
    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_string($$metsXmlRef);
    my $root = $tree->getDocumentElement();

    # Image fileGrp
    my $imageFileGrp;
    my $xpath = '//*[name()="METS:mets"][1]/*[name()="METS:fileSec"][1]/*[name()="METS:fileGrp" and ' .
        '@USE="image"][1]/*[name()="METS:file"]';
    ASSERT( $imageFileGrp = $root->findnodes($xpath) ,
            qq{Problem finding fileGrp USE="image" element in METS file: }
            . $self->Get( 'metsxmlfilename' ) );

    # OCR fileGrp
    my $textFileGrp;
    $xpath = '//*[name()="METS:mets"][1]/*[name()="METS:fileSec"][1]/*[name()="METS:fileGrp" and ' .
             '@USE="ocr"][1]/*[name()="METS:file"]';
    ASSERT( $textFileGrp = $root->findnodes($xpath),
            qq{Problem finding fileGrp USE="ocr" element in METS file: }
            . $self->Get( 'metsxmlfilename' ) );

    # structMap contains the page and feature metadata
    my $structMap;
    $xpath = '//*[name()="METS:mets"][1]/*[name()="METS:structMap"][1]//*[name()="METS:div" and @ORDER]';
    ASSERT( $structMap = $root->findnodes($xpath),
            qq{Problem finding structMap elements in METS file: }
            . $self->Get( 'metsxmlfilename' ) );
    my ($seq2PageFeatureHashRef, $seq2PageNumberHashRef, $featureRecordRef) =
        $self->build_feature_map($structMap);

    my $where;
    foreach my $node ($imageFileGrp->get_nodelist)
    {
      # Each of these nodes is <METS:file>
      my $pageSequence = $node->getAttribute('SEQ');
      if ($pageSequence)
      {
        my $unpaddedPageSequence = $pageSequence;
        $unpaddedPageSequence =~ s,^0+,,;

        $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'pagenumber' } =
                $$seq2PageNumberHashRef{$unpaddedPageSequence};

        $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'pagefeatures' } =
                $$seq2PageFeatureHashRef{$unpaddedPageSequence};

        eval { $where = $node->findvalue('./*[name()="METS:FLocat"][1]/@xlink:href'); };
        $where = '' if $@;
        if ( $where =~ m,^(.*?\.(.*?))$,ios )
        {
          my $imageFile = $1;
          my $fileType = $2;
          $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'imagefile' } = $imageFile;
          $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'filetype' } = $fileType;
          $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'imagefilesize' } = $node->getAttribute('SIZE');
        }
      }
    }
    # It is faster to iterate here rather than xpath the OCR file grp
    # for a matching SEQ in the above iteration.
    foreach my $node ($textFileGrp->get_nodelist)
    {
      # Each of these nodes is <METS:file>
      my $pageSequence = $node->getAttribute('SEQ');
      if ($pageSequence)
      {
        my $unpaddedPageSequence = $pageSequence;
        $unpaddedPageSequence =~ s,^0+,,;

        eval { $where = $node->findvalue('./*[name()="METS:FLocat"][1]/@xlink:href');};
        $where = '' if $@;
        if ( $where =~ m,^(.*?\.(.*?))$,ios )
        {
          my $ocrFile = $1;
          $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'ocrfile' } = $ocrFile;
          $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'ocrfilesize' } = $node->getAttribute('SIZE');
        }
      }
    }
    # get locations of OPTIONAL coordOCR-ed files
    # FIXME: this has not been tested because $PTGlobals::ghOCREnabled is always 0.
    if ( $MdpGlobals::ghOCREnabled )
    {
      $xpath = '//*[name()="METS:mets"][1]/*[name()="METS:fileSec"][1]/*[name()="METS:fileGrp" and ' .
               '@USE="coordOCR"][1]/*[name()="METS:file"]';
      my $coordOCRFileGrp = $root->findnodes($xpath);
      if ($coordOCRFileGrp)
      {
        $self->SetHasCoordOCR();
        foreach my $node ($coordOCRFileGrp->get_nodelist)
        {
          # Each of these nodes is <METS:file>
          my $pageSequence = $node->getAttribute('SEQ');
          if ($pageSequence)
          {
            my $unpaddedPageSequence = $pageSequence;
            $unpaddedPageSequence =~ s,^0+,,;

            eval { $where = $node->findvalue('./*[name()="METS:FLocat"][1]/@xlink:href');};
            $where = '' if $@;
            if ( $where =~ m,^(.*?\.(.*?))$,ios )
            {
              my $coordOcrFile = $1;
              $pageInfoHash{ 'sequence' }{ $unpaddedPageSequence }{ 'coordocrfile' } = $coordOcrFile;
            }
          }
        }
      }
    }

    my $firstSequence = Utils::min_of_list( keys ( %{ $pageInfoHash{ 'sequence' } } ) );
    $self->SetFirstPageSequence( $firstSequence );

    $self->SupressCheckoutSeqs( \%pageInfoHash, $seq2PageNumberHashRef, $featureRecordRef );

    my $lastSequence = Utils::max_of_list( keys ( %{ $pageInfoHash{ 'sequence' } } ) );
    $self->SetLastPageSequence( $lastSequence );

    # Note: MUST FOLLOW SUPPRESSION CALL ABOVE.
    $self->SetHasTOCFeature( $$featureRecordRef{'hasPF_TOC'} );
    $self->SetHasTitleFeature( $$featureRecordRef{'hasPF_TITLE'} );
    $self->SetHasFirstContentFeature( $$featureRecordRef{'hasPF_FIRST_CONTENT'} );

    # Note: MUST FOLLOW SUPPRESSION CALL ABOVE.  We can't simply
    # reverse the %seq2PageNumberHash because the many sequence
    # numbers can map to the same (undef) page number because we don't
    # have a page number for every physical page due to limitations in
    # the OCR detector.  Further, there can be more than one of a
    # given page number so we're forced to choose to use the the first
    # occurrence of the page number when mapping to sequence number.
    my %page2SequenceMap;
    foreach my $seq ( sort {$a <=> $b} keys %$seq2PageNumberHashRef )
    {
        my $pageNumber = $$seq2PageNumberHashRef{$seq};
        if ( $pageNumber && (! $page2SequenceMap{$pageNumber} ))
        {
            $page2SequenceMap{$pageNumber} = $seq;
        }
    }
    $pageInfoHash{ 'page2sequencemap' } = \%page2SequenceMap;

    $self->{ 'pageinfo' } = \%pageInfoHash;
    
    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(END)</h3>} . Utils::display_stats());
}


# ---------------------------------------------------------------------

=item adjust_feature_seq

Deleting this seq moves the saved feature seqs down by 1.

=cut

# ---------------------------------------------------------------------
sub adjust_feature_seq
{
    my $suppressed_seq = shift;
    my $feature_seq = shift;

    my $new_seq;
    if ($suppressed_seq == $feature_seq)
    {
        $new_seq = 0;
    }
    elsif ($suppressed_seq < $feature_seq)
    {
        $new_seq = --$feature_seq;
    }
    else
    {
        $new_seq = $feature_seq;
    }

    return $new_seq;
}


# ----------------------------------------------------------------------
# NAME         : SupressCheckoutSeqs
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        : If the item has page metadata suppress the sequences
#                labeled with CHECKOUT_PAGE.  If the item lacks page
#                metadata suppress the next to last page sequence.
#                Eventually, the next to last page suppression will be
#                eliminated in favor of CHECKOUT_PAGE when all books
#                have page metadata.
# ----------------------------------------------------------------------
sub SupressCheckoutSeqs
{
    my $self = shift;
    my ( $pageInfoHashRef, $seq2PageNumberHashRef, $featureRecordRef ) = @_;

    # Don't suppress pages for development viewing using debug=nosup
    # switch
    return
        if (DEBUG('nosup') && Debug::DUtils::debugging_enabled());

    if ( $self->HasPageFeatures() )
    {
        foreach my $seq ( keys %{ $$pageInfoHashRef{'sequence'} })
        {
            if ( grep( /CHECKOUT_PAGE/,
                       @{$$pageInfoHashRef{'sequence'}{$seq}{'pagefeatures'}}))
            {
                delete $$pageInfoHashRef{'sequence'}{$seq};
                delete $$seq2PageNumberHashRef{$seq};
                DEBUG('pt,all', qq{seq="$seq" is CHECKOUT_PAGE, suppressed});

                # Deleting this seq moves the saved feature seqs down by 1.
                $$featureRecordRef{'hasPF_TOC'} =
                    adjust_feature_seq($seq, $$featureRecordRef{'hasPF_TOC'});
                $$featureRecordRef{'hasPF_TITLE'} =
                    adjust_feature_seq($seq, $$featureRecordRef{'hasPF_TITLE'});
                $$featureRecordRef{'hasPF_FIRST_CONTENT'} =
                    adjust_feature_seq($seq, $$featureRecordRef{'hasPF_FIRST_CONTENT'});
            }
        }

        my @tempPageInfo;
        my @tempSeq2PageNumber;
        foreach my $seq (sort {$a <=> $b} keys %{$$pageInfoHashRef{'sequence'}})
        {
            push(@tempPageInfo, $$pageInfoHashRef{'sequence'}{$seq});
            push(@tempSeq2PageNumber, $$seq2PageNumberHashRef{$seq});
        }
        delete $$pageInfoHashRef{'sequence'};
        undef %$seq2PageNumberHashRef;

        my $seq = 1;
        foreach my $i (0..$#tempPageInfo)
        {
            if ($tempPageInfo[$i])
            {
                $$pageInfoHashRef{'sequence'}{$seq} = $tempPageInfo[$i];
                $$seq2PageNumberHashRef{$seq} = $tempSeq2PageNumber[$i];
                $seq++;
            }
        }
    }
    else
    {
        my $lastSequence =
            Utils::max_of_list( keys %{$$pageInfoHashRef{'sequence' }});

        my $penultimatePageSequence = $lastSequence - 1;

        $$pageInfoHashRef{'sequence'}{ $penultimatePageSequence } =
            $$pageInfoHashRef{'sequence'}{ $lastSequence };
        delete( $$pageInfoHashRef{'sequence'}{ $lastSequence } );

        $$seq2PageNumberHashRef{$penultimatePageSequence} =
            $$seq2PageNumberHashRef{ $lastSequence};
        delete($$seq2PageNumberHashRef{$lastSequence});
    }
}

# ----------------------------------------------------------------------
# NAME         : GetSequenceNumbers
# PURPOSE      : Returns the unsuppressed sequence numbers for this record
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetSequenceNumbers
{
    my $self = shift;

    my %pageInfoHash = % { $self->{'pageinfo'} };
    my @seqsArray = keys( %{ $pageInfoHash{'sequence'} } );
    @seqsArray = sort { $a <=> $b } ( @seqsArray );
    return  @seqsArray;
}

# ----------------------------------------------------------------------
# NAME         : GetFeatureHash
# PURPOSE      : Returns the types and labels used for section headings (features).
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetFeatureHash
{
    my $self = shift;

    my $featureHashRef;

    my $id = $self->GetId();

    my $namespace = $self->Get('namespace');
    if (defined($MdpGlobals::gPageFeatureHash{$namespace})) {
        $featureHashRef = $MdpGlobals::gPageFeatureHash{$namespace};
    } 
    elsif (Identifier::has_MARC_metadata($id))
    {   $featureHashRef = $MdpGlobals::gPageFeatureHash{'MARC.METADATA'};   }

    return $featureHashRef;
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetPageNumBySequence
{
    my $self = shift;
    my $sequence = shift;

    my $pageInfoHashRef = $self->Get( 'pageinfo' );

    my $pageNumber;
    if ( $self->HasPageNumbers() )
    {
        $pageNumber = $$pageInfoHashRef{ 'sequence' }{ $sequence }{ 'pagenumber' };
    }
    else
    {
        $pageNumber = $sequence;
    }

    return $pageNumber;
}


# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetFileNameBySequence
{
    my $self = shift;
    my $sequence = shift;
    my $which = shift;

    my $pageInfoHashRef = $self->Get( 'pageinfo' );
    my $fileName = $$pageInfoHashRef{ 'sequence' }{ $sequence }{ $which };

    return $fileName;
}

sub GetFileSizeBySequence
{
    my $self = shift;
    my $sequence = shift;
    my $which = shift;

    my $pageInfoHashRef = $self->Get( 'pageinfo' );
    my $filesize = $$pageInfoHashRef{ 'sequence' }{ $sequence }{ $which . 'size' };

    return $filesize;
}


# ----------------------------------------------------------------------
# NAME         : GetDirPathMaybeExtract
# PURPOSE      : Extract all ocr or img files for a given id from zip archive and drop
#                them in the input cache
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetDirPathMaybeExtract
{
    my $self = shift;
    my $pattern_arr_ref = shift;
    my $which = shift;
    my $suffix = shift;

    my $fileDir;

    my $fileSystemLocation = $self->Get( 'filesystemlocation' );
    if ($self->ItemIsZipped())
    {
        # Extract file to the input cache location
        $fileDir =
            Utils::Extract::extract_dir_to_temp_cache
                (
                 $self->GetId(),
                 $fileSystemLocation,
                 $pattern_arr_ref,
                 $suffix
                );
    }
    else
    {
        # File is already available
        $fileDir = $fileSystemLocation;
    }

    return $fileDir;
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
sub GetFilePathMaybeExtract
{
    my $self = shift;
    my $sequence = shift;
    my $which = shift;
    my $suffix = shift;
    
    my $filePath;

    my $fileName = $self->GetFileNameBySequence($sequence, $which);
    my $fileSystemLocation = $self->Get( 'filesystemlocation' );

    if ($self->ItemIsZipped())
    {
        # Extract file to the input cache location
        $filePath =
            Utils::Extract::extract_file_to_temp_cache
                (
                 $self->GetId(),
                 $fileSystemLocation,
                 $fileName,
                 $suffix
                );
    }
    else
    {
        # File is already available
        $filePath = $fileSystemLocation . qq{/$fileName};
    }

    return ($fileName, $filePath);
}

# ----------------------------------------------------------------------
# NAME         : DumpPageInfoToHtml
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub DumpPageInfoToHtml
{
    my $self = shift;

    my $s;
    my %pageInfoHash = % { $self->{'pageinfo'} };
    my @seqsArray = keys( %{ $pageInfoHash{'sequence'} } );
    @seqsArray = sort { $a <=> $b } ( @seqsArray );

    my $basename = $self->Get( 'filesystemlocation' );
    $s .= qq{<h4>Base directory="$basename"</h4>\n};

    $s .= qq{<h4>Volume information</h4>\n};
    my $volHashRef = $self->GetVolumeData();
    if ( scalar( keys %$volHashRef ) > 0 )
    {
        $s .= qq{<table>\n};
        foreach my $bc( sort keys %$volHashRef )
        {
            my $vol = $$volHashRef{$bc}{'vol'};
            my $callno = $$volHashRef{$bc}{'callno'};
            my $b = $$volHashRef{$bc}{'b'};
            my $c = $$volHashRef{$bc}{'c'};

            $s .= qq{<tr><td>id="$bc"</td><td>vol="$vol"</td><td>callno="$callno"</td><td>b="$b"</td><td>c="$c"</td></tr>\n};

        }
        $s .= qq{</table>\n};
    }
    else
    {
        $s .= qq{<p>None</p>\n};
    }


    $s .= qq{<h4>Has page numbers: } . $self->HasPageNumbers() . qq{</h4>\n};
    $s .= qq{<h4>Has page features: } . $self->HasPageFeatures() . qq{</h4>\n};
    $s .= qq{<table>\n};
    for ( my $i=0; $i < scalar( @seqsArray ); $i++ )
    {
        my $seq = $seqsArray[$i];
        my $imgfile  = $pageInfoHash{'sequence'}{ $seq }{'imagefile'} || 'NOTDEFINED';
        my $ocrfile  = $pageInfoHash{'sequence'}{ $seq }{'ocrfile'} || 'NOTDEFINED';
        my $fileType = $pageInfoHash{'sequence'}{ $seq }{'filetype'};
        my $pagenum = $pageInfoHash{'sequence'}{ $seq }{'pagenumber'};
        my $featuresArrRef = $pageInfoHash{'sequence'}{ $seq }{'pagefeatures'};
        my $features = join( ',', @$featuresArrRef );

        $s .= qq{<tr><td>seq="$seqsArray[$i]"</td><td>pg="$pagenum"</td><td>imgfile="$imgfile"</td><td>ocrfile="$ocrfile"</td><td>img fileType="$fileType"</td><td>features="$features"</td></tr>\n};
    }
    $s .= qq{</table>\n};

    if ( $self->HasPageFeatures() )
    {
        $s .= qq{<h3>Feature Table</h3>\n};
        $s .= qq{<table>\n};
        $self->InitFeatureIterator();
        my $featureRef;
        while ( $featureRef = $self->GetNextFeature(), $$featureRef )
        {
            my $tag   = $$$featureRef{'tag'};
            my $label = $$$featureRef{'label'};
            my $page  = $$$featureRef{'pg'};
            my $seq   = $$$featureRef{'seq'};
            $s .= qq{<tr><td>seq="$seq"</td><td>pg="$page"</td><td>tag="$tag"</td><td>label="$label"</td></tr>\n};
        }
        $s .= qq{</table>\n};


        my $page2SeqNumberHashRef = $self->GetPage2SequenceMap();
        $s .= qq{<h3>Page to Sequence Map</h3>\n};
        $s .= qq{<table>\n};
        foreach my $page ( sort {$a <=> $b} keys %$page2SeqNumberHashRef )
        {
            my $seq   = $$page2SeqNumberHashRef{$page};
            $s .= qq{<tr><td>page="$page"</td><td>seq="$seq"</td></tr>\n};
        }
        $s .= qq{</table>\n};
    }

    return $s;
}

sub SetOrientationForIdSequence
{
    my $self = shift;
    my ( $id, $sequence, $orientation ) = @_;
    
    my $C = new Context;
    my $ses = $C->get_object('Session');
    my $orientation_cache = $ses->get_persistent("orientation:$id") || {};
    
    my $do_persist = 1;
    if($orientation == $MdpGlobals::gDefaultOrientation) {
        if (defined($$orientation_cache{$sequence})) {
            delete $$orientation_cache{$sequence};
        } else {
            $do_persist = 0;
        }
    } else {
        $$orientation_cache{$sequence} = $orientation;
    }

    $ses->set_persistent("orientation:$id", $orientation_cache) if ( $do_persist );

}

sub GetOrientationForIdSequence
{
    my $self = shift;
    my ( $id, $sequence ) = @_;

    my $C = new Context;
    my $ses = $C->get_object('Session');
    my $orientation_cache = $ses->get_persistent("orientation:$id") || {};
    
    return $$orientation_cache{$sequence} || $MdpGlobals::gDefaultOrientation;
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub GetOrientationInDegrees
{
    my $self = shift;
    my $rotation = $self->GetOrientationForIdSequence(
                                                      $self->GetId(),
                                                      $self->GetRequestedPageSequence(),
                                                     );

    return $MdpGlobals::gValidRotationValues{ $rotation };

}


# ---------------------------------------------------------------------

=item file_exists_n_newer

Check existence of web derivative and that its mtime is newer that
mtime of zip file it was derived from.  Assumes all archival files are
in zip files. That should now be the case.

=cut

# ---------------------------------------------------------------------
sub file_exists_n_newer {
    my $self = shift;
    my $derivative = shift;
    
    my $id = $self->GetId();

    my $exists_n_newer = 0;
    
    if (Utils::file_exists($derivative)) {
        my $itemFileSystemLocation = Identifier::get_item_location($id);
        my $barcode = Identifier::get_id_wo_namespace($id);
        my $zipfile = qq{$itemFileSystemLocation/$barcode.zip};

        my $zip_mtime = (stat($zipfile))[9];
        my $der_mtime = (stat($derivative))[9];

        if ($der_mtime > $zip_mtime) {
            $exists_n_newer = 1;
        }
    }

    return $exists_n_newer;
}


1;



__END__;

