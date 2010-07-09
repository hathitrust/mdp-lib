package MBooks::Query::VuFindSolr;

#
#XXX WARNING!! this is really specialized to get metadata for a list of mdp/hathi ids
# Its not a general class for searching the VuFindSolr instance
# Perhaps it needs a new name 
#
#



use strict;

use Utils;
use Debug::DUtils;
use Collection;
use base qw(Search::Query);


# ---------------------------------------------------------------------

=item AFTER_Query_initialize

  Use Template
Design Pattern.

=cut

# ---------------------------------------------------------------------
sub AFTER_Query_initialize
{
    my $self = shift;
    my $C = shift;
}


# ---------------------------------------------------------------------

=item get_id_arr_ref

Description

=cut

# ---------------------------------------------------------------------
sub get_id_arr_ref {
    my $self = shift;
    return $self->{'id_arr_ref'};
}


# ---------------------------------------------------------------------
sub get_query_string_from_ids {
    my $self = shift;
    my $id_arr_ref = shift;

    ASSERT(scalar(@$id_arr_ref) <= 1024, qq{more than 1024 ids });

    my $query = join(' OR ', map {qq{ht_id:"$_"}} @$id_arr_ref);

    return $query;   
}

# ---------------------------------------------------------------------

=item get_Solr_metadata_query_from_ids

Creates a solr query based on a list of HathiTrust ids and  the 
XXX TODO: implment conf file step: fields in the global.conf file

=cut

# ---------------------------------------------------------------------
sub get_Solr_metadata_query_from_ids
{
    my $self = shift;
    my $id_arr_ref = shift;
    
    # pass this in after reading it from config file.  See Phil's bin/l/ls/index code
    # need sort title and display title
    my $field_list_arr_ref= [ 'author',
                              'title',
                              'titleSort',
                              #'title_ab',  # Could this be short version for long titles 
                              'publishDate',
                              'ht_id_display',
                              'id',
                            ];
    
    my $field_list = join(',', @$field_list_arr_ref);
        
    my $query_string = $self->get_query_string_from_ids($id_arr_ref);
    my $INTERN_Q = qq{q=$query_string};
    my $FL = qq{&fl=$field_list};
    my $VERSION = qq{&version=} . $self->get_Solr_XmlResponseWriter_version();
    my $START_ROWS = qq{&start=0&rows=1000000};
    my $INDENT = qq{&indent=off};

    my $solr_query_string =
        $INTERN_Q . $FL . $VERSION . $START_ROWS . $INDENT;

    return $solr_query_string;
}

#----------------

1;
