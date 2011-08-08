package Document::Doc::vSolrMetadataAPI::Schema_LS_4;

=head1 NAME

Document::vSolrMetadataAPI::Schema_LS_4

=head1 DESCRIPTION

This class creates an VuFind Solr type 4 schema document for indexing
using the VuFind API and the VuFind Solr schema for facets.

Maps VuFind id to "record_no"

Maps the publishDate field to the stored date field for display

Processes the Vufind FullText field (MARC21 MARCXML for record) to
create the "allfields" field which concatentates all MARC fields over 99

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

# App
use Utils;
use Search::Constants;
use SharedQueue;

# SLIP
use Db;
use base qw(Document::Doc::vSolrMetadataAPI);

# ------------------------  Field List  -------------------------------
#
# So far all are multi-valued (arr)
#

my @g_FIELD_LIST =
  (
   'author',
   #	'author2', # remove for January index rebuild. For next rebuild include this here and in schema.xml
   'availability',
   'callnumber',
   'countryOfPubStr',
   'ctrlnum',
   'dateSpan',
   'era',
   'format',
   'fullgenre',
   'fullrecord',
   'genre',
   'geographicStr',
   'hlb3Str',
   'hlb3Delimited',
   'ht_availability',
   'ht_availability_intl',
   'ht_id_display',
   'htsource',
   'id',
   'isbn',
   'issn',
   'language',
   'lccn',
   'oclc',
   'publishDate',
   'publishDateRange',
   'record_no',
   'rptnum',
   'sdrnum',
   'serialTitle',
   'serialTitle_a',
   'serialTitle_ab',
   'series',
   'series2',
   # 'spelling',   use our allfields->spelling conversion instead of VuFinds
   'subgeographic',
   'sudoc',
   'title',
   'title_ab',
   'title_rest',
   'title_restProper',
   'titleSort',
   'title_top',
   'title_topProper',
   'topicStr',
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

=item get_auxiliary_field_data

Over-rides base class method, which see. Get the list of coll_ids for
the given id that are large so those coll_ids can be added as
<coll_id> fields of the Solr doc.

So, if sync-i found an id to have, erroneously, a *small* coll_id
field in its Solr doc and queued it for re-indexing, this routine
would create a Solr doc not containing that coll_id among its
<coll_id> fields.

=cut

# ---------------------------------------------------------------------
sub get_auxiliary_field_data {
    my $self = shift;
    my ($C, $dbh, $item_id, $primary_metadata_hashref, $state, $cached) = @_;

    my $status = IX_NO_ERROR;

    return ($primary_metadata_hashref, $status) if ($cached);

    my ($ok, $coll_id_arr_ref) = SharedQueue::get_coll_ids_for_id($C, $dbh, $item_id);
    if ($ok) {
        # If item is in one or more collections see if any of those collections are "large"
        my ($ok, $large_coll_id_arr_ref) = SharedQueue::get_large_coll_coll_ids($C, $dbh);
        if ($ok) {
            my $valid_coll_id_arr_ref = [];
            foreach my $coll_id (@$coll_id_arr_ref) {
                if (grep(/^$coll_id$/, @$large_coll_id_arr_ref)) {
                    push(@$valid_coll_id_arr_ref, $coll_id);
                }
            }

            if (scalar(@$valid_coll_id_arr_ref)) {
                $primary_metadata_hashref->{coll_id} = $valid_coll_id_arr_ref;
            }
            else {
                # O reserved for coll_id field of item not in any collection
                $primary_metadata_hashref->{coll_id} = [0];
            }
        }
        else {
            $status = IX_METADATA_FAILURE;
        }
    }
    else {
        $status = IX_METADATA_FAILURE;
    }

    # More metadata
    if ($status == IX_NO_ERROR) {
        # namespace-qualified id field
        $primary_metadata_hashref->{id} = [$item_id];

        # rights attribute field
        my $rights_attribute = Document::get_rights_f_id($C, $item_id);
        if ($rights_attribute) {
            $primary_metadata_hashref->{rights} = [$rights_attribute];
        }
        else {
            $status = IX_METADATA_FAILURE;
        }
    }

    return ($primary_metadata_hashref, $status);
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
    my ($C, $item_id, $metadata_hashref, $state) = @_;

    # get MARC XML and concatenate text contents of all fields > 99
    # i.e. no control 0xx fields!

    $metadata_hashref->{'allfields'} = getAllFields($metadata_hashref->{'fullrecord'});
    delete $metadata_hashref->{'fullrecord'};

    # map VuFind id to LS bib_id PIFiller/ListSearchResults uses
    # $record_no so we use that for now.  Is it worth changing here
    # and in ls UI code?

    $metadata_hashref->{'record_no'} = $metadata_hashref->{'id'};
    delete $metadata_hashref->{'id'};

    # Title is used as a proxy for metadata validity
    my @titles = @{$metadata_hashref->{'title'}};
    return unless (scalar(@titles) > 0);

    # save title as Vtitle before Mbooks specific processing reserved for "title" field
    $metadata_hashref->{'Vtitle'} = $metadata_hashref->{'title'};

    # save author to Vauthor for vufind processed field
    if (defined($metadata_hashref->{'author'})) {
        $metadata_hashref->{'Vauthor'} = $metadata_hashref->{'author'}
    }

    my @hathiTrust_str = grep(/^$item_id\|.*/, @{$metadata_hashref->{'ht_id_display'}});
    # 0      1            2          3
    # htid | ingestDate | enumcron | rightsCodeForThisItem
    my @ht_id_display = split(/\|/, $hathiTrust_str[0]);
    my $volume_enumcron = $ht_id_display[2];
    if ($volume_enumcron) {
        $metadata_hashref->{'title'}[0] .= qq{, $volume_enumcron};
    }
    delete $metadata_hashref->{'ht_id_display'};

    # copy publishDate into date field
    if (defined($metadata_hashref->{'publishDate'})) {
        $metadata_hashref->{'date'}[0] = $metadata_hashref->{'publishDate'}[0];
    }
}


# ---------------------------------------------------------------------

=item getAllFields

input is the VuFind "FullText" field which is the MARC21 MARCXML for the record,
output is concatenation of all the MARC fields above 99
Note that an earlier process escaped the xml so we reverse the process

=cut

# ---------------------------------------------------------------------
sub getAllFields{
    my $xmlref = shift;
    my $xml=$xmlref->[0];
    # clean up escaped xml until we find out where its escaped
    $xml =~s/\&lt\;/\</g;
    $xml =~s/\&gt\;/\>/g;

    my $g_PARSER = XML::LibXML->new();
    my $doc = $g_PARSER->parse_string($xml);
    my @nodelist= $doc->getElementsByTagName('datafield');
    my $bigstring;
    my $content;

    foreach my $node (@nodelist) {
        my $tag = $node->getAttribute('tag');

        if ($tag > 99) {
            if ($node->hasChildNodes()) {
                my @childnodes = $node->childNodes();
                foreach my $child (@childnodes) {
                    $content = $child->textContent;
                    $bigstring .= $content . " ";
                }
            }
            else {
                $content = $node->textContent;
                $bigstring .= $content . " ";
            }
        }
    }

    my $aryref = [];
    $aryref->[0]= $bigstring;
    return $aryref;
}

1;
