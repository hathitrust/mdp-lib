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
BEGIN {
    $Date::Manip::Backend = 'DM5';
}
use Date::Manip qw( Date_Cmp ParseDate );

# MDP
use MdpGlobals;
use Debug::DUtils;
use Utils;
use Utils::Extract;
use Context;
use Auth::Auth;
use Identifier;
use MarcMetadata;
use MetsReadingOrder;
use DataTypes;

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
sub GetMetsXmlFromFile {
    my $metsXmlFilename = shift;

    my $metsXmlRef = Utils::read_file( $metsXmlFilename );

    return $metsXmlRef;
}

sub GetMetsXmlFilename {
    my ($itemFileSystemLocation, $id) = @_;

    my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);
    return $itemFileSystemLocation . qq{/$stripped_id} . $MdpGlobals::gMetsFileExtension;
}

sub GetMetsXmlModTime {
    my ( $id ) = @_;
    my $itemFileSystemLocation = Identifier::get_item_location($id);
    my $barcode = Identifier::get_id_wo_namespace($id);
    my $mets_filename = qq{$itemFileSystemLocation/$barcode.mets.xml};

    my $mets_mtime = (stat($mets_filename))[9];
    return $mets_mtime;
}

our @watermark_config;
sub GetSources
{
    my ( $self ) = @_;

    my $digitization_source = lc $self->Get('digitization_source');
    my $collection_source = lc $self->Get('collection_source');

    return ( $digitization_source, $collection_source );
}

sub _ComputeSourcesFromId {
    my ( $self ) = @_;

    # no collection source in METS, punt to using namespace + source attribute lookup
    # NOTE: REMOVE AFTER METS UPLIFT - ROGER
    my $C = new Context;
    my $id = $self->GetId();
    my $rights = $C->get_object('Access::Rights',1);
    my $source_attribute;
    if (ref $rights){
        $source_attribute = $rights->get_source_attribute($C, $id);
    }
    my $namespace = Identifier::the_namespace( $id );
    # get the data from the config file
    unless ( scalar @watermark_config ) {
        my $tmp = Utils::read_file(qq{$ENV{SDRROOT}/watermarks/config.txt});
        @watermark_config = split(/\n/, $$tmp);
    }
    my ( $line ) = grep(/^$namespace\|$source_attribute\|/, @watermark_config); chomp $line;
    return () unless ( $line ); # no watermark found
    my @config = split(/\|/, $line);
    my $digitization_source = $config[2];
    my $collection_source = $config[3];

    return ( $digitization_source, $collection_source );
}

# ---------------------------------------------------------------------

sub GetLanguage {
    my $self = shift;
    return $self->{_mmdo}->get_language();
}

=item GetMetadata

Description

=cut

# ---------------------------------------------------------------------
sub GetMetadata {
    my $self = shift;
    return $self->{_mmdo}->get_metadata();
}


# ---------------------------------------------------------------------

=item InitMetadata

Description

=cut

# ---------------------------------------------------------------------
sub InitMetadata {
    my $self = shift;
    my ($C, $id) = @_;

    my $mmdo = $self->{_mmdo} || ( $self->{_mmdo} = new MarcMetadata($C, $id) );
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

    my $cache_mdpItem = 1;
    my $ignore_existing_cache = 0;
    my $cache_max_age = 0;

    if (defined($config) && defined($cgi)) {
        $ignore_existing_cache = $cgi->param('newsid') || 0;
        $cache_mdpItem = ($config->get('mdpitem_use_cache') eq 'true');
        $cache_max_age = $config->get('mdpitem_max_age') || 0;
    }

    my $cache_key = qq{mdpitem};
    my $cache_dir = Utils::get_true_cache_dir($C, 'mdpitem_cache_dir');
    my $cache = Utils::Cache::Storable->new($cache_dir, $cache_max_age, GetMetsXmlModTime($id));

    DEBUG('cache', qq{<h3>Start get mdpitem from cache </h3>});

    $mdpItem = $cache->Get($id, $cache_key) unless (! $cache_mdpItem);

    DEBUG('cache', qq{<h3>Finish get mdpitem from cache, got item=} . ($mdpItem ? 'yes' : 'no') . qq{</h3>});

    return ($cache, $cache_key, $cache_mdpItem, $ignore_existing_cache, $mdpItem);
}

# ---------------------------------------------------------------------

=item _{delete|restore}_DOM_objects

Support caching of non-serializable data

=cut

# ---------------------------------------------------------------------
my $_METS_preserved;
sub _delete_DOM_objects {
    my $self = shift;

    $_METS_preserved = delete $self->{_METS};
    $self->GetMetadataObject->delete_document_root();
}

sub _restore_DOM_objects {
    my $self = shift;

    $self->{_METS} = $_METS_preserved;
    $self->GetMetadataObject->restore_document_root();
}

# ---------------------------------------------------------------------

=item GetMdpItem

Description

=cut

# ---------------------------------------------------------------------
sub GetMdpItem {
    my $class = shift;
    my ($C, $id, $itemFileSystemLocation) = @_;

    $itemFileSystemLocation = Identifier::get_item_location($id) unless ($itemFileSystemLocation);

    my ($cache, $cache_key, $cache_mdpItem, $ignore_existing_cache, $mdpItem) =
      __handle_mdpitem_cache_setup($C, $id);

    # if we already have instantiated and saved in the cache the full
    # mdpitem for the id being requested, we have everything we need
    # and can return

    # if the cached verison has metadatafailure == 1, re-compute

    if ($mdpItem  && ($mdpItem->Get('id') eq $id) && (! $mdpItem->MetadataFailure())) {
        # item was already cached and we have it in $mdpItem.  Test to
        # see if the item files got zipped since the last time we
        # accessed this mdpItem object.
        if (! $mdpItem->ItemIsZipped()) {
            my $zipfile = $itemFileSystemLocation . qq{/$id.zip};
            if (-e $zipfile) {
                $mdpItem->Set('zipfile', $zipfile);
                $mdpItem->SetItemZipped();
            }
        }

        DEBUG('cache, all', qq{<h3>Using cached mdpItem object for id="$id"</h3>});
    }
    else {
        $mdpItem = $class->new($C, $id);

        DEBUG('cache,all', qq{<h3>metadata status=} . ($mdpItem->MetadataFailure() ? 'fail' : 'OK') . qq{</h3>});

        # don't cache if we've got a metadatafailure or cache was not ititialized because ignored
        if ($cache_mdpItem && ! $mdpItem->MetadataFailure()) {
            DEBUG('cache', qq{<h3>Cache MdpItem: id=$id existing_cache_ignored=$ignore_existing_cache</h3>});

            # do some zigzag to avoid serializing the XML::LibXML structure(s)
            $mdpItem->_delete_DOM_objects();
            $cache->Set($id, $cache_key, $mdpItem, $ignore_existing_cache);
            $mdpItem->_restore_DOM_objects();
        }
    }

    DEBUG('mdpitem,all', sub {return $mdpItem->DumpPageInfoToHtml();});

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
sub new {
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
sub _initialize {
    my $self = shift;
    my ( $C, $id ) = @_;

    if ($self->Get('initialized')) {
        return;
    }
    $self->Set('initialized', 1);

    $self->InitMetadata($C, $id);

    $self->SetId( $id );
    $self->Set('namespace', Identifier::the_namespace($id));

    my $itemFileSystemLocation = Identifier::get_item_location($id);
    $self->Set( 'filesystemlocation', $itemFileSystemLocation );
    silent_ASSERT( -d $itemFileSystemLocation, qq{Invalid document id provided.});

    my $stripped_id = Identifier::get_pairtree_id_wo_namespace($id);

    # Reduce size of METS and replace /METS:dmdSec/[@ID='DMD1'] with
    # MARCXML
    my $metsXmlFilename = GetMetsXmlFilename($itemFileSystemLocation, $id);
    $self->Set( 'metsxmlfilename', $metsXmlFilename );

    my $metsXmlRef = GetMetsXmlFromFile( $metsXmlFilename );
    $self->StoreMETS($metsXmlRef);

    my $zipfile = $itemFileSystemLocation . qq{/$stripped_id.zip};
    if (-e $zipfile) {
        $self->SetItemZipped();
        $self->Set('zipfile', $zipfile);
    }

    $self->SetSources();
    $self->SetItemType();
    $self->SetMarkupLanguage();
    $self->SetPageInfo();
}


sub Set {
    my $self = shift;
    my ( $key, $value ) = @_;
    $self->{ $key } = $value;
}

sub Get {
    my $self = shift;
    my $key = shift;
    return $self->{ $key };
}

sub SetId {
    my $self = shift;
    my $id = shift;
    $self->{ 'id' } = $id;
}

sub _GetMetsRoot {
    my $self = shift;
    unless ( ref($$self{_METS}) ) {
        my $metsXmlRef = shift || $self->Get( 'metsxml' );
        my $parser = XML::LibXML->new();
        my $tree = $parser->parse_string($$metsXmlRef);
        my $root = $tree->getDocumentElement();
        $$self{_METS} = $root;
    }
    return $$self{_METS};
}

sub SetSources {
    my $self = shift;
    my $root = $self->_GetMetsRoot();
    my $collection_source = $root->findvalue(q{//HT:contentProvider[@display='yes']});
    my $digitization_source = $root->findvalue(q{//HT:digitizationAgent[@display="yes"]});

    unless ( $collection_source ) {
        ( $digitization_source, $collection_source ) = $self->_ComputeSourcesFromId();
        $self->Set('computed_source', 1);
    }

    $self->Set('collection_source', $collection_source);
    $self->Set('digitization_source', $digitization_source);
}

sub SetItemType {
    my $self = shift;

    my $root = $self->_GetMetsRoot();

    my $item_type = DataTypes::getDataType($root);

    $self->Set('item_type', $item_type);

    my $item_sub_type = DataTypes::getDataSubType($root);
    $self->Set('item_sub_type', $item_sub_type) unless ( $item_sub_type eq $item_type );

    # initialize subclass...
    my $subclass = uc(substr($item_type, 0, 1)) . substr($item_type, 1);
    if ( $item_type ne $item_sub_type ) {
        if ( $item_sub_type eq lc $item_sub_type ) { $item_sub_type = uc(substr($item_sub_type, 0, 1)) . substr($item_sub_type, 1);}
        $subclass .= "::$item_sub_type";
    }
    my $err;
    if ( $err = eval "require MdpItem::$subclass" ) {
        bless $self, "MdpItem::$subclass";
        $self->Set('item_subclass', $subclass);
    }
}

sub SetMarkupLanguage {
    my $self = shift;
    my $root = $self->_GetMetsRoot();
    my $markup_language = DataTypes::getMarkupLanguage($root);
    $self->Set('markup_language', $markup_language);
}

sub GetFullMetsRef {
    my $self = shift;
    return $self->Get('metsxml');
}

sub GetItemType {
    my $self = shift;
    return $self->Get('item_type');
}

sub GetItemSubType {
    my $self = shift;
    return $self->Get('item_sub_type');
}

sub GetItemSubClass {
    my $self = shift;
    return $self->Get('item_subclass');
}

sub GetMarkupLanguage {
    my $self = shift;
    return $self->Get('markup_language');
}

sub ItemIsZipped {
    my $self = shift;
    return $self->{'itemiszipped'};
}

sub SetItemZipped {
    my $self = shift;
    $self->{'itemiszipped'} = 1;
}

sub HasServeablePDF {
    my $self = shift;
    # 2016-03-30 roger - eventually this will be something real
    return ( $$self{id} =~ m,^ku01, );
}

sub GetId {
    my $self = shift;
    return $self->{ 'id' };
}

sub InitFeatureIterator {
    my $self = shift;
    $self->{'featuretableindex'} = 0;;
}

sub GetNextFeature {
    my $self = shift;

    my $featureTableRef = $self->Get( 'featuretable' );
    if (defined $featureTableRef) {
        return \$$featureTableRef{ $self->{'featuretableindex'}++ };
    }
    else {
        return undef;
    }
}

sub PeekNextFeature {
    my $self = shift;

    my $featureTableRef = $self->Get( 'featuretable' );
    if (defined $featureTableRef) {
        return \$$featureTableRef{ ($self->{'featuretableindex'}) };
    }
    else {
        return undef;
    }
}

sub GetPageFeatures {
    my $self = shift;
    my $seq = shift;

    if (defined $self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}) {
        return @{$self->{'pageinfo'}{'sequence'}{$seq}{'pagefeatures'}};
    }
    else {
        return ();
    }
}

sub SetContentHandler {
    my $self = shift;
    my $handler = shift;

    $self->{ 'contenthandler' } = $handler;
}

sub GetContentHandler {
    my $self = shift;

    return $self->{ 'contenthandler' };
}

sub GetContainsJp2Jpg {
        my $self = shift;
        return $self->{ 'containsjp2jpg' };
}

sub SetContainsJp2Jpg {
    my $self = shift;
    my $jp2 = shift;

    $self->{ 'containsjp2jpg' } = $jp2;

}

sub SetPageCount {
    my $self = shift;
    my $pages = shift;

    $self->{ 'pagecount' } = $pages;

}

sub GetPageCount {
        my $self = shift;
        return $self->{ 'pagecount' };
}

sub SetHasPageNumbers {
    my $self = shift;
    my $has = shift;
    $self->{ 'haspagenumbers' } = $has;
}

sub HasPageNumbers {
    my $self = shift;
    return $self->{ 'haspagenumbers' };
}

sub SetHasPageFeatures {
    my $self = shift;
    my $has = shift;
    $self->{ 'haspagefeatures' } = $has;
}

sub HasPageFeatures {
    my $self = shift;
    return $self->{ 'haspagefeatures' };
}

sub SetHasCoordOCR {
    my $self = shift;
    my $value = shift || 0;
    $self->{ 'hascoordocr' } = ($MdpGlobals::ghOCREnabled ? 1 : 0);
}

sub HasCoordOCR {
    my $self = shift;
    return $self->{ 'hascoordocr' };
}

sub SetHasBookCoverFeature {
    my $self = shift;
    my $seq = shift;
    $self->{ 'hasbookcoverfeature' } = $seq;
}

sub HasBookCoverFeature {
    my $self = shift;
    return $self->{ 'hasbookcoverfeature' };
}

sub SetHasFirstContentFeature {
    my $self = shift;
    my $has = shift;
    $self->{ 'hasfirstcontentfeature' } = $has;
}

sub HasFirstContentFeature {
    my $self = shift;
    return $self->{ 'hasfirstcontentfeature' };
}

sub SetHasTitleFeature {
    my $self = shift;
    my $seqOfTitle = shift;
    $self->{ 'hastitlefeature' } = $seqOfTitle;
}

sub HasTitleFeature {
    my $self = shift;
    return $self->{ 'hastitlefeature' };
}

sub SetHasTOCFeature {
    my $self = shift;
    my $seqOfTOC = shift;
    $self->{ 'hastocfeature' } = $seqOfTOC;
}

sub HasTOCFeature {
    my $self = shift;
    return $self->{ 'hastocfeature' };
}

sub SetHasMULTIFeature {
    my $self = shift;
    my $seqOfMULTI = shift;
    $self->{ 'hasmultifeature' } = $seqOfMULTI;
}

sub HasMULTIFeature {
    my $self = shift;
    return $self->{ 'hasmultifeature' };
}

sub Version {
    my $self = shift;
    my ($version, $was_deleted) = @_;

    if (defined $version) {
        $self->{mostrecentversion} = $version;
        $self->{mostrecentversionwasdeleted} = $was_deleted;
    }
    return ($self->{mostrecentversion}, $self->{mostrecentversionwasdeleted});
}

# ---------------------------------------------------------------------

=item StoreMETS

Description

=cut

# ---------------------------------------------------------------------
sub StoreMETS {
    my $self = shift;
    my $metsXmlRef = shift;

    # remove all xml bits since we don't need them in the output
    $$metsXmlRef =~ s,<\?xml\s+.*?\?>,,s;
    my $root = $self->_GetMetsRoot($metsXmlRef);

    # If not debug=xml, remove other unneeded elements. UC content has
    # an extra dmdSec. The amdSec not used by
    # pageturner. METS:amdSec//PREMIS:event is required for Version label.
    if (! DEBUG('xml')) {
        my ($dmdSec2) = $root->findnodes("//METS:dmdSec[\@ID='DMD2']");
        $root->removeChild($dmdSec2) if ($dmdSec2);
    }

    # Replace child of dmdSec/ID=DMD1 with actual metadata
    my ($dmdSec1) = $root->findnodes("//METS:dmdSec[\@ID='DMD1']");
    if ( $dmdSec1 ) {
        $dmdSec1->removeChildNodes() if ($dmdSec1);
    } else {
        # um, create a dmdSec1?
        $dmdSec1 = $root->ownerDocument->createElementNS( $root->lookupNamespaceURI('METS'), 'dmdSec' );
        $dmdSec1 = $root->appendChild($dmdSec1);
        $dmdSec1->setAttribute('ID', 'DMD1');
    }

    my $metadataRef = $self->GetMetadata();
    if ($metadataRef) {
        my $parser = XML::LibXML->new();
        my $fragment = $parser->parse_xml_chunk($$metadataRef);
        $dmdSec1->appendChild( $fragment );
    }

    my $metsXML = $root->serialize();
    $self->Set('metsxml', \$metsXML);
}

sub SetRequestedSize {
    my $self = shift;
    my $size = shift;
    $self->{ 'requestedsize' } = $size;
}

sub GetRequestedSize {
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
    my $validSeq = $self->GetValidSequence( scalar $cgi->param( 'seq' ) );
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
        # $orientationToUse = $self->GetOrientationForIdSequence( $id, $requestedSequence ) ||
        #     $MdpGlobals::gDefaultOrientation;
        $orientationToUse = $MdpGlobals::gDefaultOrientation;
        $self->SetOrientationForIdSequence( $id, $requestedSequence, $orientationToUse );
    }

    $cgi->param( 'orient', $orientationToUse );
}

sub GetValidSequence {
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

sub GetRequestedPageSequence {
    my $self = shift;
    return $self->{ 'requestedpagesequence' };
}

sub GetPage2SequenceMap {
    my $self = shift;
    return $self->{ 'pageinfo' }{ 'page2sequencemap' };
}

sub SetLastPageSequence {
    my $self = shift;
    my $lastPageSequence = shift;
    $self->{ 'lastpagesequence' } = $lastPageSequence;
}

sub GetLastPageSequence {
    my $self = shift;
    return $self->{ 'lastpagesequence' };
}

sub SetFirstPageSequence {
    my $self = shift;
    my $firstPageSequence = shift;
    $self->{ 'firstpagesequence' } = $firstPageSequence;
}

sub GetFirstPageSequence {
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
sub GetSequenceForPageNumber {
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

sub GetPhysicalPageSequence {
    my $self = shift;
    my ( $seq ) = @_;
    my $tmp = $self->Get('seqOrderMap') || {};
    return $$tmp{"v2p",$seq} || $seq;
}

sub GetVirtualPageSequence {
    my $self = shift;
    my ( $seq ) = @_;
    my $tmp = $self->Get('seqOrderMap') || {};
    return $$tmp{"p2v",$seq} || $seq;
}

sub GetStoredFileType {
    my $self = shift;
    my $pageSequence = shift;

    if ( $pageSequence !~ m,^\d+$, ) {
        # not a number!
        my $fileGrpHash = $$self{fileGrpHash};
        if ( $$fileGrpHash{$pageSequence} ) {
            return $$fileGrpHash{$pageSequence}{filetype};
        }
    }

    my $pageInfoHashRef = $self->{ 'pageinfo' };

    return $$pageInfoHashRef{ 'sequence' }{ $pageSequence }{ 'filetype' };
}

sub GetStoredFileGroup {
    my $self = shift;
    my $pageSequence = shift;

    if ( $pageSequence !~ m,^\d+$, ) {
        # not a number!
        my $fileGrpHash = $$self{fileGrpHash};
        if ( $$fileGrpHash{$pageSequence} ) {
            return $$fileGrpHash{$pageSequence}{filegrp};
        }
    }

    my $pageInfoHashRef = $self->{ 'pageinfo' };

    return $$pageInfoHashRef{ 'sequence' }{ $pageSequence }{ 'filegrp' };
}

sub GetStoredFileMimeType {
    my $self = shift;
    my $pageSequence = shift;

    if ( $pageSequence !~ m,^\d+$, ) {
        # not a number!
        my $fileGrpHash = $$self{fileGrpHash};
        if ( $$fileGrpHash{$pageSequence} ) {
            return $$fileGrpHash{$pageSequence}{mimetype};
        }
    }

    my $pageInfoHashRef = $self->{ 'pageinfo' };

    return $$pageInfoHashRef{ 'sequence' }{ $pageSequence }{ 'filegrp' };
}

# Metadata accessors
sub GetMetadataObject {
    my $self = shift;
    return $self->{_mmdo};
}

sub MetadataFailure {
    my $self = shift;
    return $self->{_mmdo}->metadata_failure;
}

sub GetFullTitle {
    my $self = shift;
    return $self->{_mmdo}->get_title(@_);
}

sub GetAuthor {
    my $self = shift;
    return $self->{_mmdo}->get_author(@_);
}

sub GetPublisher {
    my $self = shift;
    return $self->{_mmdo}->get_publisher(@_);
}

sub GetVolumeData {
    my $self = shift;
    return $self->{_mmdo}->get_enumcron(@_);
}

sub GetFormat {
    my $self = shift;
    return $self->{_mmdo}->get_format(@_);
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
    my ($pgftr, $order, $featureRecordRef) = @_;

    $featureRecordRef->{hasPF_BOOKCOVER} = $order
      if (! $featureRecordRef->{hasPF_BOOKCOVER} &&
        ( ($pgftr =~ m,BOOK_COVER,o) || (($pgftr =~ m,COVER,o) && ($pgftr =~ m,RIGHT,o)) ));
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

# ---------------------------------------------------------------------

=item DeleteExtraneousMETSElements

Description

=cut

# ---------------------------------------------------------------------
sub DeleteExtraneousMETSElements {
    my $self = shift;
    my $metsXmlRef = shift;

   # remove all xml bits since we don't need them in the output
    $$metsXmlRef =~ s,<\?xml\s+.*?\?>,,s;

    # If not debug=xml, remove other unneeded elements. UC content has
    # an extra dmdSec. The amdSec not used by
    # pageturner. METS:amdSec//PREMIS:event is required for Version label.
    if (! DEBUG('xml')) {
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

    my %type_map = (
        'zip archive' => 'zip',
    );

    my $fileGrps = $root->findnodes(q{/METS:mets/METS:fileSec/METS:fileGrp[METS:file]});
    foreach my $fileGrpNode ( $fileGrps->get_nodelist ) {
        my $filegrp = $fileGrpNode->getAttribute('USE');
        if ( $type_map{$filegrp} ) { $filegrp = $type_map{$filegrp}; }

        my $fileNodes = $fileGrpNode->findnodes(q{METS:file});
        my $has_key = qq{has_$filegrp};
        $self->Set($has_key, scalar @$fileNodes);

        if ( $self->Get($has_key) ) {
            my $totalFileSize = 0;
            foreach my $node ( $fileNodes->get_nodelist ) {
                my $id = $node->getAttribute('ID');
                my $filesize = $node->getAttribute('SIZE');
                # my $filename = ($node->childNodes)[1]->getAttribute('xlink:href');
                my $filename = $node->findvalue('./METS:FLocat/@xlink:href');
                my ($filetype) = ($filename =~ m,^.*?\.(.*?)$,ios);
                my $filemimetype = $node->getAttribute('MIMETYPE');

                $fileGrpHashRef->{$id}{filename} = $filename;
                $fileGrpHashRef->{$id}{filetype} = $filetype;
                $fileGrpHashRef->{$id}{mimetype} = $filemimetype;
                $fileGrpHashRef->{$id}{filesize} = $filesize;
                $fileGrpHashRef->{$id}{filegrp} =  $filegrp . 'file'; # compatibility?
                $totalFileSize += $filesize;
            }

            $self->Set($has_key, 0) if ($totalFileSize == 0);

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

    print STDERR "AHOY ParseStructMap OG : " . ref($self) . "\n";

    # tombstone objects have an empty structMap
    my $xpath = q{/METS:mets/METS:structMap//METS:div[@ORDER]};
    my $structMap = $root->findnodes($xpath);

    my $hasPNs = 0;
    my $hasPFs = 0;

    my %featureTable;
    my $featureTableCt = 0;
    my $featureHashRef = $self->GetFeatureHash();
    my @featureTags = keys( %$featureHashRef );

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
        my @pageFeatures = split(/,\s*/, $pgftr);
        $pageInfoHashRef->{sequence}{$order}{pagefeatures} = \@pageFeatures;
        my $order_has_PFs = (scalar(@pageFeatures) > 0);
        $hasPFs ||= $order_has_PFs;

        add_to_feature_table($order, $pgnum, \@featureTags, \@pageFeatures, $featureHashRef,
                             \%featureTable, \$featureTableCt)
          if ($order_has_PFs);

        handle_feature_record($pgftr, $order, $featureRecordRef);
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

=item ParseVersionFromPREMIS

Description

=cut

# ---------------------------------------------------------------------
sub ParseVersionFromPREMIS {
    my $self = shift;
    my $tree = shift;

    use constant NS_PREMIS  => 'info:lc/xmlns/premis-v2';
    use constant NS_PREMIS1 => 'http://www.loc.gov/standards/premis';

    my $xpc = XML::LibXML::XPathContext->new($tree);
    $xpc->registerNs('premis', NS_PREMIS);
    $xpc->registerNs('premis1', NS_PREMIS1);

    my $date_xpath = './premis:eventDateTime | ./premis1:eventDateTime';

    my $most_recent;
    my $was_deleted = 0;
    my $deletion_event_xpath = '//premis:event[premis:eventType="deletion"] | //premis1:event[premis1:eventType="deletion"]';

    foreach my $event ($xpc->findnodes($deletion_event_xpath)) {
        my $date = $xpc->findvalue($date_xpath, $event);
        if (
            (! defined $most_recent)
            ||
            (Date_Cmp(ParseDate($date), ParseDate($most_recent)) == 1)
           ) {
            $most_recent = $date;
            $was_deleted = 1;
        }
    }

    if (! defined $most_recent) {
        # Not deleted, use ingestion date
        my $ingestion_event_xpath = '//premis:event[premis:eventType="ingestion"] | //premis1:event[premis1:eventType="ingestion"]';

        foreach my $event ($xpc->findnodes($ingestion_event_xpath)) {
            my $date = $xpc->findvalue($date_xpath, $event);
            if (
                (! defined $most_recent)
                ||
                (Date_Cmp(ParseDate($date), ParseDate($most_recent)) == 1)
               ) {
                $most_recent = $date;
            }
        }
    }

    return ($most_recent, $was_deleted);
}

sub SetFileGroupMap {
    my $self = shift;
    my $fileGrpHash = shift;
    $$self{fileGrpHash} = $fileGrpHash;
}

sub GetFileGroupMap {
    my $self = shift;
    return $$self{fileGrpHash};
}

sub GetFileById {
    my $self = shift;
    my $fileid = shift;
    my $fileGrpHash = $self->GetFileGroupMap;
    if ( $$fileGrpHash{$fileid} ) {
        return $$fileGrpHash{$fileid}{filename};
    }
    return undef;
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

    my %pageInfoHash = ();
    my %seq2PageNumberHash = ();
    my %featureRecord = ();

    $self->ParseReadingOrder();

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

    ### CHECKOUT_PAGE IS NO LONGER SUPRESSED
    ### $self->SupressCheckoutSeqs(\%pageInfoHash, \%seq2PageNumberHash, \%featureRecord);

    my $lastSequence = Utils::max_of_list(keys ( %{ $pageInfoHash{sequence} } ));
    $self->SetLastPageSequence($lastSequence);

    # Note: MUST FOLLOW SUPPRESSION CALL ABOVE.
    $self->SetHasBookCoverFeature($featureRecord{hasPF_BOOKCOVER});
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

    my ($version, $was_deleted) = $self-> ParseVersionFromPREMIS($root);
    $self->Version($version, $was_deleted);

    $self->{pageinfo} = \%pageInfoHash;

    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(END)</h3>} . Utils::display_stats());
}

sub ParseReadingOrder {
    my $self = shift;
    my $root = $self->_GetMetsRoot();
    my ( $readingOrder, $scanningOrder, $coverTag ) = MetsReadingOrder::parse($root);
    $self->Set('readingOrder', $readingOrder);
    $self->Set('scanningOrder', $scanningOrder);
    $self->Set('coverTag', $coverTag);
    DEBUG('readingOrder, all', qq{<h3>Reading Order ="$readingOrder" / Scanning Order = "$scanningOrder" / Cover Tag = "$coverTag"</h3>});
}

# would be overridden in type specific files
sub GetItemCover {
    my $self = shift;
    my $seq;
    $seq = $self->HasTitleFeature() || $self->HasTOCFeature() || $self->HasFirstContentFeature() || $self->HasBookCoverFeature() || 1;
    return $seq;
}

# ---------------------------------------------------------------------

=item adjust_feature_seq

Deleting this seq moves the saved feature seqs down by 1.

=cut

# ---------------------------------------------------------------------
sub adjust_feature_seq {
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
#                Deprecated - 2014-02-25.
# ----------------------------------------------------------------------
sub SupressCheckoutSeqs {
    my $self = shift;
    my ( $pageInfoHashRef, $seq2PageNumberHashRef, $featureRecordRef ) = @_;

    # Don't suppress pages for development viewing using debug=nosup
    # switch
    return if (DEBUG('nosup'));

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
sub GetSequenceNumbers {
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
sub GetFeatureHash {
    my $self = shift;

    return $MdpGlobals::gPageFeatureHashRef;
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
sub GetPageNumBySequence {
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
sub GetFileNameBySequence {
    my $self = shift;
    my $sequence = shift;
    my $which = shift;

    my $pageInfoHashRef = $self->Get( 'pageinfo' );
    my $fileName = $$pageInfoHashRef{ 'sequence' }{ $sequence }{ $which };

    return $fileName;
}

sub GetFileSizeBySequence {
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
sub GetDirPathMaybeExtract {
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
sub GetFilePathMaybeExtract {
    my $self = shift;
    my $sequence = shift;
    my $which = shift;
    my $suffix = shift;

    my $filePath;

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
sub DumpPageInfoToHtml {
    my $self = shift;

    my $s;
    my %pageInfoHash = % { $self->{'pageinfo'} };
    my @seqsArray = keys( %{ $pageInfoHash{'sequence'} } );
    @seqsArray = sort { $a <=> $b } ( @seqsArray );

    my $basename = $self->Get( 'filesystemlocation' );
    $s .= qq{<h4>Base directory="$basename"</h4>\n};

    $s .= qq{<h4>File Groups</h4>\n};
    $s .= qq{<pre>} . Data::Dumper::Dumper($self->GetFileGroupMap) . q{</pre>};

    $s .= qq{<h4>Volume information</h4>\n};
    my $vol = $self->GetVolumeData();
    if ($vol) {
        $s .= qq{<p>vol="$vol"</p>\n};
    }
    else {
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
        my $coordocrfile = $pageInfoHash{'sequence'}{ $seq }{'coordOCRfile'} || 'NOTDEFINED';
        my $ocrfilesize  = $pageInfoHash{'sequence'}{ $seq }{'ocrfilesize'};
        my $fileType = $pageInfoHash{'sequence'}{ $seq }{'filetype'};
        my $pagenum = $pageInfoHash{'sequence'}{ $seq }{'pagenumber'};
        my $featuresArrRef = $pageInfoHash{'sequence'}{ $seq }{'pagefeatures'};
        my $features = join( ',', @$featuresArrRef );

        $s .= qq{<tr><td>seq="$seqsArray[$i]"</td><td>ocrsz="$ocrfilesize"</td><td>pg="$pagenum"</td><td>imgfile="$imgfile"</td><td>ocrfile="$ocrfile"</td><td>coordocrfile="$coordocrfile"</td><td>img fileType="$fileType"</td><td>features="$features"</td></tr>\n};
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

sub SetOrientationForIdSequence {
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

sub GetOrientationForIdSequence {
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
sub GetOrientationInDegrees {
    my $self = shift;
    my $rotation = $self->GetOrientationForIdSequence(
                                                      $self->GetId(),
                                                      $self->GetRequestedPageSequence(),
                                                     );

    return $MdpGlobals::gValidRotationValues{ $rotation };

}


# ---------------------------------------------------------------------

=item get_modtime

Class method call to GetMetsXmlModTime

=cut

# ---------------------------------------------------------------------
sub get_modtime {
    my $self = shift;
    return GetMetsXmlModTime($self->GetId());
}

1;



__END__;

