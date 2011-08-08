package Document::vSolrMetadataAPI::Schema_LS_2;


=head1 NAME

Document::vSolrMetadataAPI::Schema_LS_2

=head1 DESCRIPTION

This class creates an VuFind Solr type 2 schema document for indexing
using the VuFind API and the VuFind Solr schema for facets.

=head1 VERSION

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;


# App
use Utils;
use Search::Constants;


# SLIP
use Db;
use base qw(Document::vSolrMetadataAPI);


# <field name="id"               type="string"         indexed="true" stored="true"  required="true"/>
# <field name="ocr"              type="CommonGramTest" indexed="true" stored="false" required="true"/>
# <field name="rights"           type="sint"           indexed="true" stored="true"  required="true"/>
# <field name="author"           type="textProper"     indexed="true" stored="true"  multiValued="true"/>
# <field name="author2"          type="textProper"     indexed="true" stored="false" multiValued="true"/>
# <field name="titleSort"        type="string"         indexed="true" stored="false" multiValued="false"/>
# <field name="title"            type="text"           indexed="true" stored="true"  multiValued="true" required="true"/>
# <field name="series"           type="text"           indexed="true" stored="true"  multiValued="true"/>
# <field name="series2"          type="text"           indexed="true" stored="true"  multiValued="true"/>
# <field name="language"         type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="format"           type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="ht_availability"  type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="htsource"         type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="topicStr"         type="string"         indexed="true" stored="false" multiValued="true"/>
# <field name="geographicStr"    type="string"         indexed="true" stored="false" multiValued="true"/>
# <field name="fullgenre"        type="text"           indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="genre"            type="text"           indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="hlb3"             type="text"           indexed="true" stored="false" multiValued="true" omitNorms="true"/> 
# <field name="hlb3Str"          type="string"         indexed="true" stored="false" multiValued="true"/>
# <field name="publishDate"      type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="publishDateRange" type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="era"              type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>
# <field name="countryOfPubStr"  type="string"         indexed="true" stored="false" multiValued="true" omitNorms="true"/>

# ------------------------  Field List  -------------------------------
#
# So far all are multi-valued (arr)  
#
my @g_FIELD_LIST = 
    (
     'ht_id_display',

     'author',
     'author2',
     'titleSort',
     'title',
     'series',
     'series2',
     'language',
     'format',
     'ht_availability',
     'htsource',
     'topicStr',
     'geographicStr',
     'fullgenre',
     'genre',
     'hlb3',
     'hlb3Str',
     'publishDate',
     'publishDateRange',
     'era',
     'countryOfPubStr',
    );


# ---------------------------------------------------------------------

=item get_field_list

Description

=cut

# ---------------------------------------------------------------------
sub get_field_list {
    return \@g_FIELD_LIST;
}

# ---------------------------------------------------------------------

=item PUBLIC: post_process_metadata

Description: Massage field values that come back from VuFind specific
to the schema in question for this subclass.

This mapping adheres to the LS Schema above.

=cut

# ---------------------------------------------------------------------
sub post_process_metadata {
    my $self = shift;
    my ($C, $item_id, $metadata_hashref) = @_;

    my @titles = @{$metadata_hashref->{'title'}};

    # Title is used as a proxy for metadata validity
    return unless (scalar(@titles) > 0);

    my @hathiTrust_str = grep(/^$item_id\|.*/, @{$metadata_hashref->{'ht_id_display'}});
    # 0      1            2          3  
    # htid | ingestDate | enumcron | rightsCodeForThisItem
    my @ht_id_display = split(/\|/, $hathiTrust_str[0]);
    my $volume_enumcron = $ht_id_display[2];
    if ($volume_enumcron) {
        $metadata_hashref->{'title'}[0] .= qq{, $volume_enumcron};
    }
    delete $metadata_hashref->{'ht_id_display'};
}

1;
