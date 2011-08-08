package Document::Doc::vSolrMetadataAPI::Schema_PTS_1;

=head1 NAME

Document::Doc::vSolrMetadataAPI::Schema_PTS_1

=head1 DESCRIPTION

This class creates Pageturner item-level search Solr document metadata.

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
use base qw(Document::Doc::vSolrMetadataAPI);

# ------------------------  Field List  -------------------------------
#
# So far all are multi-valued (arr)
#
my @g_FIELD_LIST =
  qw (
         id
         title
         author
         ht_id_display
         publishDate
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

Over-rides base class method, which see.

=cut

# ---------------------------------------------------------------------
sub get_auxiliary_field_data {
    my $self = shift;
    my ($C, $dbh, $item_id, $primary_metadata_hashref, $state, $cached) = @_;

    my $status = IX_NO_ERROR;
    return ($primary_metadata_hashref, $status)
      if ($cached);

    # Aux metadata: Volume id + rights fields
    $primary_metadata_hashref->{vol_id} = [$item_id];

    my $rights_attribute = Document::get_rights_f_id($C, $item_id);
    if ($rights_attribute) {
        $primary_metadata_hashref->{rights} = [$rights_attribute];
    }
    else {
        $status = IX_METADATA_FAILURE;
    }

    return ($primary_metadata_hashref, $status);
}


# ---------------------------------------------------------------------

=item PUBLIC: post_process_metadata

Description: Massage field values that come back from VuFind specific
to the schema in question for this subclass.

This mapping adheres to the Schema above.

=cut

# ---------------------------------------------------------------------
sub post_process_metadata {
    my $self = shift;
    my ($C, $item_id, $metadata_hashref, $state, $cached) = @_;

    # The vufind id is called record_no in our code and our id for a
    # page-level document for one page of an item is the volume id
    # e.g. mdp.39015015823563 concatenated with the state
    # variable. This is called 'hid' and is <uniqueKey>hid</uniqueKey>
    # in schema.xml. Everything else will have been cached.
    #
    if (defined($metadata_hashref->{'id'})) {
        $metadata_hashref->{'record_no'} = $metadata_hashref->{'id'};
        delete $metadata_hashref->{'id'};
    }
    $metadata_hashref->{hid} = [$item_id . qq{_$state}];

    # Nothing else to do after the first call.
    return if ($cached);

    # Title is used as a proxy for metadata validity
    my @titles = @{$metadata_hashref->{'title'}};
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

    # copy publishDate into date field
    if (defined($metadata_hashref->{'publishDate'})) {
        $metadata_hashref->{'date'}[0] = $metadata_hashref->{'publishDate'}[0];
        delete $metadata_hashref->{'publishDate'}
    }
}



1;
