package Metadata;

sub new {
    my $class = shift;
    my $self = {};
    
    $self = bless $self, $class;
    $self->__initialize(@_);

    return $self;
}

sub __initialize {
    my $self = shift;
    my ( $C, $id, $root ) = @_;

    $self->{_root} = $root;
}

sub metadata_failure {
    my $self = shift;
    return 0;
}

sub delete_document_root {
    my $self = shift;
}

sub restore_document_root {
    my $self = shift;
}

sub get_language {

}

sub get_language_code {

}

sub get_title {

}

sub get_author {

}

sub get_publisher {

}

sub get_format {

}

sub get_publication_date {

}

sub get_metadata {

}

package MdpItem::EMMA;

use strict;

use base 'MdpItem';

use Debug::DUtils;
use Utils;

use constant EMMA_NS => q{https://emma.lib.virginia.edu/schema};

sub quack {
    my $self = shift;
    return "COIN COIN";
}

=item InitMetadata

Description

=cut

# ---------------------------------------------------------------------
sub InitMetadata {
    my $self = shift;
    my ($C, $id) = @_;

    my $mmdo = $self->{_mmdo} || ( $self->{_mmdo} = new Metadata($C, $id, $self) );
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

    # my $metadataRef = $self->GetMetadata();
    # if ($metadataRef) {
    #     my $parser = XML::LibXML->new();
    #     my $fragment = $parser->parse_xml_chunk($$metadataRef);
    #     $dmdSec1->appendChild( $fragment );
    # }

    my $metsXML = $root->serialize();
    $self->Set('metsxml', \$metsXML);
}

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

    # my %remediatedFileMap = ();
    # $self->BuildRemediatedFileMap
    #   (
    #     $root,
    #     \%remediatedFileMap
    # );

    # $self->SetRemediatedFileMap(\%remediatedFileMap);    

    my ($version, $was_deleted) = $self-> ParseVersionFromPREMIS($root);
    $self->Version($version, $was_deleted);

    DEBUG('time', qq{<h3>MdpItem::SetPageInfo(END)</h3>} . Utils::display_stats());
}

sub SetSources {
    my $self = shift;
    my $root = $self->_GetMetsRoot();

    # track the repository id
    my $xpc = XML::LibXML::XPathContext->new($root);
    $xpc->registerNs('emma', EMMA_NS);
    my $recordId = $xpc->findvalue('//emma:emma_repositoryRecordId');
    $self->Set('repositoryRecordId', $recordId);
}

sub GetRemediatedFileId {
    my $self = shift;
    my $fileGrpHash = $self->GetFileGroupMap();
    foreach my $fileid ( keys %$fileGrpHash ) {
        if ( $$fileGrpHash{$fileid}{filegrp} eq 'remediatedfile' ) {
            return $fileid;
        }
    }
    return undef;
}

sub GetRemediatedFileIds {
    my $self = shift;
    my @retval = ();
    my $fileGrpHash = $self->GetFileGroupMap();
    foreach my $fileid ( keys %$fileGrpHash ) {
        if ( $$fileGrpHash{$fileid}{filegrp} eq 'remediatedfile' ) {
            push @retval, $fileid;
        }
    }
    return @retval;
}


1;
