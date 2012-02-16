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
use CGI;
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

# ---------------------------------------------------------------------

=item __handle_mdpitem_cache_setup

Description

=cut

# ---------------------------------------------------------------------
sub __handle_mdpitem_cache_setup {
    my $C = shift;
    my $id = shift;
    
    my $cgi = $C->get_object('CGI', 1);
    my $config = $C->get_object('MdpConfig', 1);    

    my $mdpItem;
    my $cache; 
    my $cache_key = qq{mdpitem};

    my $cache_mdpItem = 0;
    my $ignore_existing_cache = 1;

    if (defined($config) && defined($cgi)) {
        $cache_mdpItem = ( $config->get('mdpitem_use_cache') eq 'true' );
        $ignore_existing_cache = ( $cgi->param('newsid') eq "1" );
        my $cache_max_age = $config->get('mdpitem_max_age') || 0;
    
        if ( $cache_mdpItem ) {
            DEBUG('time', qq{<h3>Start mdp item uncache</h3>} . Utils::display_stats());
        
            my $cache_dir = Utils::get_true_cache_dir($C, 'mdpitem_cache_dir');
            $cache = Utils::Cache::Storable->new($cache_dir, $cache_max_age);
            $mdpItem = $cache->Get($id, $cache_key);
            DEBUG('time', qq{<h3>Finish mdp item uncache</h3>} . Utils::display_stats());

            if ( $ignore_existing_cache ) {
                $mdpItem = undef;
            }
        }
    }

    return ($cache, $cache_key, $cache_mdpItem, $ignore_existing_cache, $mdpItem);
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

    $itemFileSystemLocation = Identifier::get_item_location($id) unless ( $itemFileSystemLocation );

    my ($cache, $cache_key, $cache_mdpItem, $ignore_existing_cache, $mdpItem) = 
      __handle_mdpitem_cache_setup($C, $id);
    
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
        $mdpItem = $class->new( $C, $id );
        
        DEBUG('pt,all', qq{<h3>Mirlyn metadata failure status for id="$id" = } . $mdpItem->Get('metadatafailure') . qq{</h3>});
        
        # don't cache if we've got a metadatafailure
        if ( $cache_mdpItem && ! $mdpItem->Get('metadatafailure') ) {
            DEBUG('pt,mdpitem,cache', qq{<h3>Cache MdpItem: $id : $cache_key</h3>});
            $cache->Set($id, $cache_key, $mdpItem, $ignore_existing_cache);
        }
    }
    
    DEBUG('mdpitem,all',
          sub
          {
              return $mdpItem->DumpPageInfoToHtml();
          });
          
    if (DEBUG('noocr')) {
        $mdpItem->Set('has_ocr', 0);
    }
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

    $self->Set( 'marcmetadata', $metadataRef );

    # --------------------------------------------------

    $self->Set( 'metadatafailure', $metadata_failed );

    $self->SetPageInfo();
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
    if (defined $featureTableRef) {
        return \$$featureTableRef{ $self->{'featuretableindex'}++ };
    }
    else {
        return undef;
    }
}

sub PeekNextFeature
{
    my $self = shift;

    my $featureTableRef = $self->Get( 'featuretable' );
    if (defined $featureTableRef) {
        return \$$featureTableRef{ ($self->{'featuretableindex'}) };
    }
    else {
        return undef;
    }
}

sub GetPageFeatures
{
    my $self = shift;
    my $seq = shift;
    
    if (defined $self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}) {
        return @{$self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}};
    }
    else {
        return ();
    }
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

sub SetHasMULTIFeature
{
    my $self = shift;
    my $seqOfMULTI = shift;
    $self->{ 'hasmultifeature' } = $seqOfMULTI;
}

sub HasMULTIFeature
{
    my $self = shift;
    return $self->{ 'hasmultifeature' };
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
sub SetCurrentRequestInfo {
    my $self = shift;
    my ( $C, $validRotationValuesHashRef ) = @_;

    my $cgi = $C->get_object('CGI', 1);
    if (! defined($cgi)) {
        $cgi = new CGI('');
        $cgi->param( 'id', 1 );
        $cgi->param( 'seq', 1 );
        $cgi->param( 'num', 1 );
        $cgi->param( 'u', 0 );
        $cgi->param( 'size', 100 );
        $cgi->param( 'orient', 0 );
    }

    # check that the requested sequence is within the range of
    # available pages
    my $validSeq = $self->GetValidSequence( $cgi->param( 'seq' ) );
    $cgi->param( 'seq', $validSeq );

    my $id     = $cgi->param( 'id' );
    my $seq    = $cgi->param( 'seq' );
    my $num    = $cgi->param( 'num' );
    my $user   = $cgi->param( 'u' );
    my $size   = $cgi->param( 'size' );
    my $orient = $cgi->param( 'orient' );

    $self->SetRequestedSize( $size );

    $self->SetRequestedPageSequence( $seq, $num, $user);
    my $requestedSequence = $self->GetRequestedPageSequence();
    # Update CGI object with seq that is correct for requested seq.
    # Requested seq can be influenced by user entered page num.
    $cgi->param('seq', $requestedSequence);

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

sub GetValidSequence
{
    my $self = shift;
    my $seq = shift;

    $seq = 0 if ( $seq !~ m,^[1-9][0-9]*$, );

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
sub SetRequestedPageSequence {
    my $self = shift;
    my ( $pageSequence, $pageNumber, $userEntered, $chunk ) = @_;

    my $finalSequenceNumber;
    $pageSequence = $self->GetValidSequence( $pageSequence );

    if ( $self->HasPageNumbers() ) {
        # If page number is supplied map it to a sequence number but
        # only if user entered.  Otherwise we treat it as a display
        # only value.
        if ( $pageNumber ) {
            if ( $userEntered ) {
                my $page2SeqNumberHashRef = $self->GetPage2SequenceMap();
                my $trialSequenceNumber = $$page2SeqNumberHashRef{$pageNumber};
                if ( $trialSequenceNumber ) {
                    # seq known to be valid by mapping
                    $finalSequenceNumber = $trialSequenceNumber;
                }
                else {
                    # User-entered page number for which we don't have
                    # a mapping to a sequence number: treat page
                    # number as the sequence number IF NUMERIC. Else it
                    # was alphanumeric or strictly alpha: stay where
                    # we are.
                    if ($pageNumber =~ m,^[1-9][0-9]*$,) {
                        $finalSequenceNumber = $pageNumber;
                    }
                    else {
                        $finalSequenceNumber = $pageSequence;
                    }
                }
            }
            else {
                $finalSequenceNumber = $pageSequence;
            }
        }
        else {
            # If no page number is supplied use the page sequence
            # (validity enforced by caller)
            $finalSequenceNumber = $pageSequence;
        }
    }
    else {
        # Item does not have page number metadata. The page number,
        # if supplied, should be treated as a sequence number if
        # entered by the user and valid.  Otherwise use $pageSequence.
        # Enforce validity on pageNumber.  $pageSequence enforced
        # above.
        if ( $pageNumber ) {
            if ( $userEntered ) {
                my $testPageNumber = $self->GetValidSequence( $pageNumber );
                if ( $testPageNumber eq $pageNumber ) {
                    # Page number is valid as a sequence number
                    $finalSequenceNumber = $pageNumber;
                }
                else {
                    $finalSequenceNumber = $pageSequence;
                }
            }
            else {
                $finalSequenceNumber = $pageSequence;
            }
        }
        else {
            $finalSequenceNumber = $pageSequence;
        }
    }

    $finalSequenceNumber = $self->GetValidSequence($finalSequenceNumber);
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

    my $marcMetadataRef = $self->Get( 'marcmetadata' );
    my ($varfield) = ($$marcMetadataRef =~ m,<varfield id="245"[^>]*>(.*?)</varfield>,s);
    
    my @tmp = ();
    push @tmp, ($varfield =~ m,<subfield label="a">(.*?)</subfield>,g);
    push @tmp, ($varfield =~ m,<subfield label="b">(.*?)</subfield>,g);
    push @tmp, ($varfield =~ m,<subfield label="c">(.*?)</subfield>,g);
    
    $title = join(' ', @tmp);
    $title =~ s,\s+, ,gsm;
    
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
    
    my $marcMetadataRef = $self->Get( 'marcmetadata' );
    
    unless ( $$marcMetadataRef ) {
        return "";
    }
    
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

sub GetPublisher
{
    my $self = shift;

    my $text;
    my $id = $self->GetId();

    my $marcMetadataRef = $self->Get( 'marcmetadata' );
    my ($varfield) = ($$marcMetadataRef =~ m,<varfield id="260"[^>]*>(.*?)</varfield>,s);
    
    my @tmp = ();
    push @tmp, ($varfield =~ m,<subfield label="a">(.*?)</subfield>,g);
    push @tmp, ($varfield =~ m,<subfield label="b">(.*?)</subfield>,g);
    push @tmp, ($varfield =~ m,<subfield label="c">(.*?)</subfield>,g);
    push @tmp, ($varfield =~ m,<subfield label="d">(.*?)</subfield>,g);
    
    $text = join(' ', @tmp);
    $text =~ s,\s+, ,gsm;
    
    return $text;
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

# ---------------------------------------------------------------------

=item add_to_feature_table

Description

=cut

# ---------------------------------------------------------------------
sub add_to_feature_table {
    my ($seq, $pgnum, $featureTagArrRef, $seqFeaturesArrRef, $featureHashRef, $featureTableHashRef, $table_ct_ref) = @_;
    
    foreach my $seqFeature (@$seqFeaturesArrRef) {
        if (grep(/^$seqFeature$/, @$featureTagArrRef)) {
            $$featureTableHashRef{$$table_ct_ref}{'tag'} = $seqFeature;
            $$featureTableHashRef{$$table_ct_ref}{'label'} = $$featureHashRef{$seqFeature};
            $$featureTableHashRef{$$table_ct_ref}{'pg'} = $pgnum;
            # Advance seq one image beyond boundary
            $$featureTableHashRef{$$table_ct_ref}{'seq'} = ($seqFeature =~ m,^MULTI,o) ? $seq + 1 : $seq ;
            $$table_ct_ref++;
            last;
        }
    }
}


# ---------------------------------------------------------------------

=item handle_feature_record

Description

=cut

# ---------------------------------------------------------------------
sub handle_feature_record {
    my ($pgftr, $order, $namespace, $featureRecordRef) = @_;
    
    if (($namespace eq 'miun') || ($namespace eq 'miua')) {
        $featureRecordRef->{hasPF_FIRST_CONTENT}  = $order
          if (! $featureRecordRef->{hasPF_FIRST_CONTENT}  && ($pgftr =~ m,1STPG,o));
        $featureRecordRef->{hasPF_TITLE} = $order
          if (! $featureRecordRef->{hasPF_TITLE} && ($pgftr =~ m,TPG|CTP|VTP|VTV,o));        
        $featureRecordRef->{hasPF_TOC} = $order
          if (! $featureRecordRef->{hasPF_TOC} && ($pgftr =~ m,TOC,o));
    }
    else {
        $featureRecordRef->{hasPF_FIRST_CONTENT} = $order
          if (! $featureRecordRef->{hasPF_FIRST_CONTENT} && ($pgftr =~ m,FIRST_CONTENT_CHAPTER_START,o));
        $featureRecordRef->{hasPF_TITLE} = $order
          if (! $featureRecordRef->{hasPF_TITLE} && ($pgftr =~ m,TITLE,o));
        $featureRecordRef->{hasPF_TOC} = $order
          if (! $featureRecordRef->{hasPF_TOC} && ($pgftr =~ m,TABLE_OF_CONTENTS,o));
        # Advance seq one image beyond boundary
        $featureRecordRef->{hasPF_MULTI} = $order + 1
          if (! $featureRecordRef->{hasPF_MULTI} && ($pgftr =~ m,MULTIWORK_BOUNDARY,o));
    }
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

# ---------------------------------------------------------------------

=item BuildFileGrpHash

Description

=cut

# ---------------------------------------------------------------------
sub BuildFileGrpHash {
    my $self = shift;
    my $root = shift;
    my $fileGrpHashRef = shift;
    
    # Image fileGrp - tombstone objects lack this group
    my $xpath = q{/METS:mets/METS:fileSec/METS:fileGrp[@USE='image']/METS:file};
    my $imageFileGrp = $root->findnodes($xpath);

    foreach my $node ($imageFileGrp->get_nodelist) {
        my $id = $node->getAttribute('ID');
        my $filesize = $node->getAttribute('SIZE');
        my $filename = ($node->childNodes)[1]->getAttribute('xlink:href');
        my ($filetype) = ($filename =~ m,^.*?\.(.*?)$,ios); 

        $fileGrpHashRef->{$id}{filename} = $filename;
        $fileGrpHashRef->{$id}{filetype} = $filetype;
        $fileGrpHashRef->{$id}{filesize} = $filesize;
        $fileGrpHashRef->{$id}{filegrp} = 'imagefile';
    }

    # OCR fileGrp - all tombstone and some live objects lack this group
    $xpath = q{/METS:mets/METS:fileSec/METS:fileGrp[@USE='ocr']/METS:file};
    my $textFileGrp = $root->findnodes($xpath);
    $self->Set('has_ocr', scalar(@$textFileGrp));

    if ($self->Get('has_ocr')) {
        # Test for all zero-length OCR files.
        my $totalFileSize = 0;
        foreach my $node ($textFileGrp->get_nodelist) {
            my $id = $node->getAttribute('ID');
            my $filesize = $node->getAttribute('SIZE');
            my $filename = ($node->childNodes)[1]->getAttribute('xlink:href');
            my ($filetype) = ($filename =~ m,^.*?\.(.*?)$,ios); 
            
            $fileGrpHashRef->{$id}{filename} = $filename;
            $fileGrpHashRef->{$id}{filetype} = $filetype;
            $fileGrpHashRef->{$id}{filesize} = $filesize;
            $fileGrpHashRef->{$id}{filegrp} = 'ocrfile';
            $totalFileSize += $filesize;
        }
        $self->Set('has_ocr', 0) if ($totalFileSize == 0);
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
    my $featureHashRef = $self->GetFeatureHash();
    my @featureTags = keys( %$featureHashRef );
    my $namespace = $self->Get('namespace');

    foreach my $metsDiv ($structMap->get_nodelist) {
        my $order = $metsDiv->getAttribute('ORDER');
        
        my @metsFptrChildren = $metsDiv->getChildrenByTagName('METS:fptr');
        foreach my $child (@metsFptrChildren) {
            my $fileid = $child->getAttribute('FILEID');
            my $filegrp  = $fileGrpHashRef->{$fileid}{'filegrp'};
            my $filename = $fileGrpHashRef->{$fileid}{'filename'};
            my $filetype = $fileGrpHashRef->{$fileid}{'filetype'};
            my $filesize = $fileGrpHashRef->{$fileid}{'filesize'};

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
        my @pageFeatures = split(/,\s*/, $pgftr);
        $pageInfoHashRef->{sequence}{$order}{pagefeatures} = \@pageFeatures;
        my $order_has_PFs = (scalar(@pageFeatures) > 0);
        $hasPFs ||= $order_has_PFs;

        add_to_feature_table($order, $pgnum, \@featureTags, \@pageFeatures, $featureHashRef,
                             \%featureTable, \$featureTableCt)
          if ($order_has_PFs);

        handle_feature_record($pgftr, $order, $namespace, $featureRecordRef);
    }

    $self->SetHasPageNumbers($hasPNs);    
    $self->SetHasPageFeatures($hasPFs);

    $self->Set('featuretable', \%featureTable);
}

# ---------------------------------------------------------------------

=item BuildPage2SequenceMap

Many sequence numbers can map to the same (undef) page number.
Further, there can be more than one of a given page number so we
choose to use the the first occurrence of the page number when mapping
to sequence.

=cut

# ---------------------------------------------------------------------
sub BuildPage2SequenceMap {
    my $self = shift;
    my $seq2PageNumberHashRef = shift;
    my $pageInfoHashRef = shift;

    my %page2SeqNumberHash = ();
    
    foreach my $seq ( sort {$a <=> $b} keys %$seq2PageNumberHashRef ) {
        my $pageNumber = $seq2PageNumberHashRef->{$seq};
        if ($pageNumber && (! $page2SeqNumberHash{$pageNumber} )) {
            $page2SeqNumberHash{$pageNumber} = $seq;
        }
    }
    $pageInfoHashRef->{page2sequencemap} = \%page2SeqNumberHash;
}

# ---------------------------------------------------------------------

=item SetPageInfo

Description

=cut

# ---------------------------------------------------------------------
sub SetPageInfo {
    my $self = shift;

    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(START)</h3>} . Utils::display_stats());

    my $metsXmlRef = $self->Get( 'metsxml' );
    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_string($$metsXmlRef);
    my $root = $tree->getDocumentElement();

    my %fileGrpHash = ();

    $self->BuildFileGrpHash
      (
       $root,
       \%fileGrpHash
      );
    
    my %pageInfoHash = ();
    my %seq2PageNumberHash = ();
    my %featureRecord = ();

    $self->ParseStructMap
      (
       $root,
       \%fileGrpHash,
       \%pageInfoHash,
       \%seq2PageNumberHash,
       \%featureRecord,
      );

    my $firstSequence = Utils::min_of_list(keys ( %{ $pageInfoHash{sequence} } ));
    $self->SetFirstPageSequence($firstSequence);

    $self->SupressCheckoutSeqs(\%pageInfoHash, \%seq2PageNumberHash, \%featureRecord);

    my $lastSequence = Utils::max_of_list(keys ( %{ $pageInfoHash{sequence} } ));
    $self->SetLastPageSequence($lastSequence);

    # Note: MUST FOLLOW SUPPRESSION CALL ABOVE.
    $self->SetHasTOCFeature($featureRecord{hasPF_TOC});
    $self->SetHasTitleFeature($featureRecord{hasPF_TITLE});
    $self->SetHasFirstContentFeature($featureRecord{hasPF_FIRST_CONTENT});
    $self->SetHasMULTIFeature($featureRecord{hasPF_MULTI});

    # Note: MUST FOLLOW SUPPRESSION CALL ABOVE.
    $self->BuildPage2SequenceMap
      (
       \%seq2PageNumberHash,
       \%pageInfoHash,
      );
    
    $self->{pageinfo} = \%pageInfoHash;
    
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
# NOTES        :
#                If the item has page metadata suppress the sequences
#                labeled with CHECKOUT_PAGE.  If the item lacks page
#                metadata DO NOTHING.  Previously we suppressed the
#                next to last page sequence.  Eventually, the next to
#                last page suppression will be handled when
#                CHECKOUT_PAGE page metadata is available for all
#                books.  This per jwilkin. Mon Aug 16 13:52:26 2010 
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
                $$featureRecordRef{'hasPF_MULTI'} =
                    adjust_feature_seq($seq, $$featureRecordRef{'hasPF_MULTI'});
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
    else {   
        $featureHashRef = $MdpGlobals::gPageFeatureHash{'MARC.METADATA'};   
    }

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
    my $exclude_pattern_arr_ref = shift;

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
                 $exclude_pattern_arr_ref,
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
    return (undef, undef) 
      if (! $fileName);
    # POSSIBLY NOTREACHED

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
        my $ocrfilesize  = $pageInfoHash{'sequence'}{ $seq }{'ocrfilesize'};
        my $fileType = $pageInfoHash{'sequence'}{ $seq }{'filetype'};
        my $pagenum = $pageInfoHash{'sequence'}{ $seq }{'pagenumber'};
        my $featuresArrRef = $pageInfoHash{'sequence'}{ $seq }{'pagefeatures'};
        my $features = join( ',', @$featuresArrRef );

        $s .= qq{<tr><td>seq="$seqsArray[$i]"</td><td>ocrsz="$ocrfilesize"</td><td>pg="$pagenum"</td><td>imgfile="$imgfile"</td><td>ocrfile="$ocrfile"</td><td>img fileType="$fileType"</td><td>features="$features"</td></tr>\n};
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
    my $ses = $C->get_object('Session', 1);
    if (defined($ses)) {
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
}

sub GetOrientationForIdSequence
{
    my $self = shift;
    my ( $id, $sequence ) = @_;

    my $C = new Context;
    my $ses = $C->get_object('Session', 1);
    if (defined($ses)) {
        my $orientation_cache = $ses->get_persistent("orientation:$id") || {};
        return $$orientation_cache{$sequence} || $MdpGlobals::gDefaultOrientation;
    }
    else {
        return $MdpGlobals::gDefaultOrientation;
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

