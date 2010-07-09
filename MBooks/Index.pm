package MBooks::Index;


=head1 NAME

MBooks::Index {ix)

=head1 DESCRIPTION

This class provides a Solr query interface to the Solr index.

=head1 SYNOPSIS

my $ix = new MBooks::Index($C);

my $indexed = $ix->item_is_properly_Solr_indexed($C, $item_id);

my $solr_coll_ids_arr_ref = $ix->get_item_solr_collids($C, $item_id);

my ($all_indexed) = $ix->get_coll_id_all_indexed_status($C, $coll_id);


=head1 METHODS

=over 8

=cut

use strict;

use Utils;
use Collection;
use Search::Constants;

use MBooks::Searcher::FullText;
use MBooks::Query::FullText;
use MBooks::Result::FullText;

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize Search::Index object.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
}




# ---------------------------------------------------------------------

=item __item_has_failure_sentinel

Description

=cut

# ---------------------------------------------------------------------
sub __item_has_failure_sentinel
{
    my $self = shift;
    my ($C, $item_id) = @_;
    
    my $has = 0;
    
    # check for the existence of ix_index_failure_string
    my $config = $C->get_object('MdpConfig');
    my $failure_sentinel = $config->get('ix_index_failure_string');
    my $query_string = qq{ocr:$failure_sentinel};
    my $id_arr_ref = $self->__get_result_ids_for_query($C, $query_string);

    if (grep(/^$item_id$/, @$id_arr_ref))
    {
        $has = 1;
    }
    
    return $has;
}


# ---------------------------------------------------------------------

=item item_is_properly_Solr_indexed

The item is properly Solr indexed if for every collection (coll_id)
the item_id is in, that coll_id is in a field in the indexed Solr
document

AND

The item did not fail a previous indexing attempt which is signaled by
the 'ocr' field consisting of the single string:
ix_index_failure_string in global.conf


=cut

# ---------------------------------------------------------------------
sub item_is_properly_Solr_indexed
{
    my $self = shift;
    my ($C, $item_id) = @_;

    my $co = $C->get_object('Collection');

    my $coll_ids_arr_ref = $co->get_coll_ids_for_item($item_id);

    # If item was deleted after we took the slice it won't be in any
    # collection
    if (scalar(@$coll_ids_arr_ref) == 0)
    {
        push(@$coll_ids_arr_ref, IX_NO_COLLECTION);
    }
    my $solr_coll_ids_arr_ref = $self->get_item_solr_collids($C, $item_id);

    my $indexed = 1;

    foreach my $coll_id (@$coll_ids_arr_ref)
    {
        if (! grep(/^$coll_id$/,  @$solr_coll_ids_arr_ref))
        {
            $indexed = 0;
            last;
        }
    }

    $indexed = 
        $indexed && (! $self->__item_has_failure_sentinel($C, $item_id));

    return $indexed;
}

# ---------------------------------------------------------------------

=item get_item_solr_collids

Get the list of coll_ids in the Solr index for this item_id

=cut

# ---------------------------------------------------------------------
sub get_item_solr_collids
{
    my $self = shift;
    my ($C, $item_id) = @_;

    my $query_string = qq{id:$item_id};
    my $Q = new MBooks::Query::FullText($C, $query_string, 'internal');

    my $rs = new MBooks::Result::FullText();

    my $config = $C->get_object('MdpConfig');
    my $engine_uri = $config->get('mbooks_solr_engine');
    my $searcher = new MBooks::Searcher::FullText($engine_uri);

    $rs = $searcher->get_Solr_internal_query_result($C, $Q, $rs);

    my $solr_coll_ids_arr_ref = $rs->get_result_coll_ids();

    return $solr_coll_ids_arr_ref;
}



# ---------------------------------------------------------------------

=item get_solr_item_ids

Get a slice of Solr item_ids

=cut

# ---------------------------------------------------------------------
sub get_solr_item_ids
{
    my $self = shift;
    my ($C, $offset, $size) = @_;

    my $rs = new MBooks::Result::FullText();
    my $config = $C->get_object('MdpConfig');
    my $engine_uri = $config->get('mbooks_solr_engine');
    my $searcher = new MBooks::Searcher::FullText($engine_uri);

    my $query_string = qq{q=*:*&start=$offset&rows=$size&fl=id};

    $rs = $searcher->get_Solr_raw_internal_query_result($C, $query_string, $rs);

    my $solr_ids_arr_ref = $rs->get_result_ids();

    return ($solr_ids_arr_ref, $offset + $size);
}

# ---------------------------------------------------------------------

=item __get_result_ids_for_query

Description

=cut

# ---------------------------------------------------------------------
sub __get_result_ids_for_query
{
    my $self = shift;
    my ($C, $query) = @_;

    my $Q = new MBooks::Query::FullText($C, $query, 'internal');

    my $rs = new MBooks::Result::FullText();

    my $config = $C->get_object('MdpConfig');
    my $engine_uri = $config->get('mbooks_solr_engine');
    my $searcher = new MBooks::Searcher::FullText($engine_uri);

    $rs = $searcher->get_Solr_internal_query_result($C, $Q, $rs);

    my $solr_item_ids_arr_ref = $rs->get_result_ids();

    return $solr_item_ids_arr_ref;
}

# ---------------------------------------------------------------------

=item  __get_counts_for_coll_id


Queries the Solr index for a collection to determine the number of items in that collection in the Solr Index.  If $count_failures is defined, then instead of returning the number of items indexed, it returns the number of items that are in the collection that are index failures (i.e. they have "ix_index_failure" in the OCR.)

=cut

# ---------------------------------------------------------------------
sub __get_counts_for_coll_id
{
    my $self = shift;
    my ($C, $coll_id,$count_failures) = @_;

    my $rs = new MBooks::Result::FullText();

    my $config = $C->get_object('MdpConfig');
    my $engine_uri = $config->get('mbooks_solr_engine');
    my $searcher = new MBooks::Searcher::FullText($engine_uri);
    
    my $query_params = qq{&fl=id&rows=1};
    my $query_string = qq{q=coll_id:$coll_id};;
    
    # build query here depending on whether we want a filter query for index failures
    if (defined ($count_failures))
    {
        $query_string .=  " AND ocr:ix_index_failure";
    }
    $query_string .=  $query_params;

    $rs = $searcher->get_Solr_raw_internal_query_result($C, $query_string, $rs);

    my $count = $rs->get_num_found();
    
    return $count
}



# ---------------------------------------------------------------------

=item get_coll_id_all_indexed_status

This uses counts to quickly see  whether the number of items in the collection in the mysql db matches 
the number of items in Solr and if so, then checks to make sure none of the items are index failures.

returns 1 if all indexed, 0 if not

Because indexing is done asynchronously with respect to when the item
is added to the collection in the database it may be that the item
can't be indexed and so we create a document with the
ix_index_failure_string as the OCR content and query for that here if
the mysql table and Solr item counts match to catch this case.

=cut

# ---------------------------------------------------------------------
sub get_coll_id_all_indexed_status
{
    my $self = shift;
    my ($C, $coll_id) = @_;

    my $all_indexed = 1;
    
    my $co = $C->get_object('Collection');
    my $dbCount = $co->count_all_items_for_coll($coll_id);

    my $count_failures;
        
    # If all items for this coll_id were not deleted:
    if ($dbCount > 0)
    {
        # count number of items in this collection in the Solr index
        my $solr_count = $self->__get_counts_for_coll_id($C,$coll_id,$count_failures);
        
        if ($dbCount != $solr_count)
        {
            $all_indexed = 0;
        }
        
        # if the counts are equal then check for index failures
        if ($all_indexed == 1)
        {
            #check to make sure there are no index failures for this collection. i.e. items with only "ix_index_failure" in 
            # the OCR field
            $count_failures="true";
            my $failure_count = $self->__get_counts_for_coll_id($C,$coll_id,$count_failures);
            if ($failure_count > 0)
            {
                $all_indexed = 0;
            }
        }
    }
    else
    {
        $all_indexed = 0;
    }
    return $all_indexed;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008 ©, The Regents of The University of Michigan, All Rights Reserved

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
