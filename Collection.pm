package Collection;

=head1 NAME

Collection

=head1 DESCRIPTION

This class encapsulates database operations of several types

1. Modify collection metadata

2. Create new collection (check CollectionSet add new coll vs Collection responsiblities)

3. adds or delete items from collections

4. read item data for one item?

5.  provide sorted lists of item data.

Should this class only deal with managing lists of items?
Should modification of collection metadata and creation of new
collection be moved to CollectionSet class?

Modification of collection metadata (this corresponds to editcoll action)

  change status (public/private)

  change description

  change collection name

Tagging and annotation of items may go to a separate class in next phase
Tagging operations on a list of items goes where?

=head1 VERSION

$Id: Collection.pm,v 1.88 2010/01/27 17:54:08 pfarber Exp $

=head1 SYNOPSIS

my $co = new Collection;

my $item_list_ref = $co->list_items($coll_id);
my $item_list = $co->list_items( [sortkey],[start_rec_num, num_records_per_page]);

foreach my $item (@{$item_list})
{
    my $title = $item_list->{'Display_Title'};
    my $author = $item_list->{ 'Display_Author'}
}

record number counting starts at 1

$item_list is reference to array of hashes where keys are database
field names and values are the values for that row


The following operations assume $user_id is available in
$self->get_user_id;

Actions on groups of items in collection is Collection responsible for
making sure user owns collection?

$co->copy_items($coll_id,$item_array_ref);

$co->delete_items($coll_id,$item_array_ref);

Actions on collections

my $coll_id = $co->get_coll_id_from_coll_name($coll_id);

$co->edit_description($coll_id, $description);

$co->edit_collection_name($coll_id, $new_coll_name);

$co->change_status($coll_id, [public|private]);


=head1 TODO:

=over 4

=item  need to index sort fields in MySQL to make limit work efficiently!

=item  see notes for CollectionSet

=back

=head1 METHODS


=cut

my $DEBUG = undef;
#$DEBUG = "true";

BEGIN
{
    # enable strict under development
    if ( $ENV{'HT_DEV'} )
    {
        require "strict.pm";
        strict::import();
    }
}


# Perl MBooks modules
use Utils;
use DbUtils;
use CollectionSet;
use Debug::DUtils;
use Search::Constants;  # for index status constants
use Search::Site;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_initialize( @_ );
    return $self;
}

# ---------------------------------------------------------------------

=item _initialize

Description

=cut

# ---------------------------------------------------------------------
sub _initialize

{
    my $self = shift;
    $self->{'dbh'} = shift;
    my $config = shift;
    $self->{'user_id'} = shift;

    $self->{'config'} = $config;

    if (DEBUG('usetesttbl'))
    {
        $self->{'coll_table_name'} = $config->get('test_coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('test_coll_item_table_name');
        $self->{'item_table_name'} = $config->get('test_item_table_name');
        $self->{'index_queue_table_name'} = $config->get('test_index_queue_table_name');
        $self->{'index_failures_table_name'} = $config->get('test_index_failures_table_name');
    }
    else
    {
        $self->{'coll_table_name'} = $config->get('coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('coll_item_table_name');
        $self->{'item_table_name'} = $config->get('item_table_name');
        $self->{'index_queue_table_name'} = $config->get('index_queue_table_name');
        $self->{'index_failures_table_name'} = $config->get('index_failures_table_name');
    }

    my @item_display_fields = $config->get('item_table_display_field_names');
    $self->{'item_display_fields_arr_ref'} = \@item_display_fields;

    my @sort_fields = $config->get('item_table_sort_field_names');
    $self->{'item_sort_fields_arr_ref'} = \@sort_fields;
}



# ---------------------------------------------------------------------

=item get_config

Description

=cut

# ---------------------------------------------------------------------
sub get_config
{
    my $self = shift;
    return $self->{'config'}
}


# ---------------------------------------------------------------------

=item get_dbh

Description

=cut

# ---------------------------------------------------------------------
sub get_dbh
{
    my $self = shift;
    return $self->{'dbh'};
}

# ---------------------------------------------------------------------

=item get_user_id

Description

=cut

# ---------------------------------------------------------------------
sub get_user_id
{
    my $self = shift;
    return $self->{'user_id'};
}



# ---------------------------------------------------------------------

=item get_coll_table_name

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_table_name
{
    my $self = shift;
    return $self->{coll_table_name};
}


# ---------------------------------------------------------------------

=item get_coll_item_table_name

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_item_table_name
{
    my $self = shift;
    return $self->{coll_item_table_name};
}


# ---------------------------------------------------------------------

=item get_item_table_name

Description

=cut

# ---------------------------------------------------------------------
sub get_item_table_name
{
    my $self = shift;
    return $self->{item_table_name};
}


# --------------------------------------------------------------------
# ---------------------------------------------------------------------

=item get_index_queue_table_name

Description

=cut

# ---------------------------------------------------------------------
sub get_index_queue_table_name
{
    my $self = shift;
    return $self->{index_queue_table_name};
}
# ---------------------------------------------------------------------

=item get_index_failures_table_name

Description

=cut

# ---------------------------------------------------------------------
sub get_index_failures_table_name
{
    my $self = shift;
    return $self->{index_failures_table_name};
}


# ---------------------------------------------------------------------

=item get_item_display_fields_arr

Description

=cut

# ---------------------------------------------------------------------
sub get_item_display_fields_arr
{
    my $self = shift;
    return @{$self->{'item_display_fields_arr_ref'}};
}

# ---------------------------------------------------------------------

=item get_item_sort_fields_arr_ref

Description

=cut

# ---------------------------------------------------------------------
sub get_item_sort_fields_arr_ref
{
    my $self = shift;
    return $self->{'item_sort_fields_arr_ref'};
}



# ---------------------------------------------------------------------

=item coll_owned_by_user

Description

=cut

# ---------------------------------------------------------------------
sub coll_owned_by_user
{
    my $self = shift;
    my $coll_id = shift;
    my $username = shift;

    Utils::trim_spaces(\$username);

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;

    my $statement = qq{SELECT owner FROM $coll_table_name WHERE MColl_id = };
    $statement .= "\'" . $coll_id . "\' \;";

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $owner = $ary[0];

    DEBUG('dbcoll', qq{username = $username collection $coll_id owned by $owner"});

    return ($username eq $owner);
}
# ---------------------------------------------------------------------

=item get_coll_owner_display_name

Returns owner_name (as opposed ot owner which is the unique persistent
id for the user) for a given coll_id

=cut

# ---------------------------------------------------------------------
sub get_coll_owner_display_name
{
    my $self = shift;
    my $coll_id = shift;

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;

    my $statement = qq{SELECT owner_name FROM $coll_table_name WHERE MColl_id='$coll_id'};

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $owner_display_name = $ary[0];

    return $owner_display_name;
}


# ---------------------------------------------------------------------

=item create_or_update_item_metadata

This adds an item to the item metadata table.  Caller is responsible
for also adding it to a collection

These need to be worked out assuming we separate extern_id from
item_id

=cut

# ---------------------------------------------------------------------
sub create_or_update_item_metadata
{
    my $self = shift;
    my $metadata_ref = shift;

    my $dbh = $self->get_dbh;
    my $item_table_name = $self->get_item_table_name;
    my $item_id = $self->get_item_id_from_extern_id($metadata_ref->{'extern_item_id'});

    # XXX insert any integrity checks for metadata_ref here there
    # should be a general validity check routine for sanity of data
    # &validate_fields($metadata_ref); &quote_fields ($metadata_ref);
    # WARNING what is the preprocessing necessary for date fields?
    # where is the display_title vs sort_title figured out? probably
    # in client that reads marc xml

    if (defined($item_id))
    {
        # item already exists so update the metadata do sql update
        DbUtils::update_row_by_key ($dbh, $item_table_name, $metadata_ref, 'item_id', $item_id);
    }
    else
    {
        # item not in item_metadata table so create new item and
        # return item_id do sql insert.  Generate a new unique item_id.
        $item_id = DbUtils::generate_unique_id($dbh, $item_table_name, 'item_id');
        $$metadata_ref{'item_id'} = $item_id;
        DbUtils::insert_new_row($dbh, $item_table_name, $metadata_ref);
    }

    return $item_id;
}


# ---------------------------------------------------------------------

=item _field_is_valid

# XXX currently implemented for item table.  Do we want to generalize and
# have tablename as argument?

=cut

# ---------------------------------------------------------------------
sub _field_is_valid
{
    my $self = shift;
    my $fieldname = shift;
    my $value = shift;

    my $item_table_name = $self->get_item_table_name;
    my $dbh = $self->get_dbh;

    # my @fields =

    # XXX see recent additions to ../lib/App/DbUtils.pm
    # check that fieldname is ok
    # run field specific validity checks


}


# ---------------------------------------------------------------------

=item get_item_id_from_extern_id

XXX Do we want to do any normalization/validity checking or will
caller be responsible for making sure barcode is reasonable?

XXX what do we do if barcode is not in db?  right now we will return
undef

=cut

# ---------------------------------------------------------------------
sub get_item_id_from_extern_id
{
    my $self = shift;
    my $extern_id = shift;

    my $item_table_name = $self->get_item_table_name;
    my $dbh = $self->get_dbh;

    my $quoted_extern_id = $dbh->quote($extern_id);
    my $statement = qq{SELECT item_id from $item_table_name WHERE extern_item_id = $quoted_extern_id};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $item_id = $ary[0];

    return $item_id;
}

# ---------------------------------------------------------------------

=item get_item_id_from_extern_id

Description

=cut

# ---------------------------------------------------------------------
sub get_extern_id_from_item_id
{
    my $self = shift;
    my $item_id = shift;

    my $item_table_name = $self->get_item_table_name;
    my $dbh = $self->get_dbh;

    my $quoted_item_id = $dbh->quote($item_id);
    my $statement = qq{SELECT extern_item_id from $item_table_name WHERE item_id=$quoted_item_id};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $extern_item_id = $ary[0];

    return $extern_item_id;
}


# ---------------------------------------------------------------------

=item copy_items

copy_items($coll_id,\@item_ids)
This only adds existing items to an existing collection

=cut

# ---------------------------------------------------------------------
sub copy_items
{
    my $self = shift;
    my $coll_id = shift;
    my $item_id_ref = shift;

    my $dbh = $self->get_dbh;
    my $coll_item_table_name = $self->get_coll_item_table_name;
    my $row_array_ref = [];
    my $col_names_array_ref= ['item_id','MColl_ID'];
    my $user_id = $self->get_user_id;

    ASSERT($self->coll_owned_by_user($coll_id, $user_id),
           qq{Collection $coll_id not owned by user $user_id});

    foreach my $item_id (@{$item_id_ref})
    {
        if ($self->item_exists($item_id))
        {
            push (@{$row_array_ref}, [$item_id,$coll_id]);
        }
        else
        {
            # XXX Should we instead test to make sure there is at least
            # one valid id and ignore bad data?
            ASSERT (0,qq{item id $item_id does not exist in item table});
        }
    }

    # Add the items
    DbUtils::insert_one_or_more_rows($dbh, $coll_item_table_name, $col_names_array_ref, $row_array_ref);

    # Add count to collections table
    $self->update_item_count($coll_id);
}


# ---------------------------------------------------------------------

=item delete_items

delete_items($coll_id,\@item_ids)

only removes the relationship between collection and items does not
affect item metadata checks that user is owner of collection

=cut

# ---------------------------------------------------------------------
sub delete_items
{
    my $self = shift;
    my $coll_id = shift;
    my $item_id_ref = shift;

    my $dbh = $self->get_dbh();
    my $coll_item_table_name = $self->get_coll_item_table_name;
    my $user_id = $self->get_user_id;

    ASSERT($self->coll_owned_by_user($coll_id, $user_id),
           qq{Can not delete items:  Collection $coll_id not owned by user $user_id});

    my $quoted_coll_id = $dbh->quote($coll_id);

    my $id_string = $self->arr_ref2SQL_in_string($item_id_ref);

    my $statement =qq{DELETE FROM $coll_item_table_name WHERE item_id in $id_string and MColl_ID = $quoted_coll_id ;};

    DbUtils::prep_n_execute ($dbh, $statement);

    # update item count int collection table!
    $self->update_item_count($coll_id);
}



#----------------------------------------------------------------------

=item list_items

record number counting starts at 1.

returns reference to array of hashrefs where keys are database field
names and values are the values for that row

if optional slice arguments (start_rec_num, num_records_per_slice) are
supplied it only returns the first num_records_per_slice starting with
start_rec_num.  Otherwise it returns all matching rows.

=cut

#----------------------------------------------------------------------
sub list_items
{
    my $self = shift;
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice, $rights_ref, $id_arr_ref) = @_;

    my $item_table = $self->get_item_table_name;
    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;

    my @metadata_fields = $self->get_item_display_fields_arr;
    push(@metadata_fields, 'rights');
    push(@metadata_fields, 'extern_item_id');

    my $item_sort_fields_arr_ref = $self->get_item_sort_fields_arr_ref;

    ASSERT($sort_key, qq{no sort key supplied});
    ASSERT($direction, qq{no direction supplied});

    # undef $slice_start and for $recs_per_slice implies no LIMIT
    # clause below
    DEBUG('dbcoll',
          qq{slice start is $slice_start at $recs_per_slice records per slice});

    # XXX check that sort_key is in $self->{'item_sort_fields_ref'} ??
    my $sort_key_in_sort_fields = grep(/$sort_key/,@{$item_sort_fields_arr_ref} );

    ASSERT($sort_key_in_sort_fields,
           qq{Collection::list_items $sort_key not in item_sort_fields });

    # qualify field names: "$item_table.fieldname" and join in comma
    # delimited string
    @metadata_fields = map {"$item_table." . $_} @metadata_fields;
    my $fields = join (", ", @metadata_fields);

    my $statement = '';

    # XXX verify that this sql works!!  AND (test_item.rights = 5 or
    # test_item.rights =7)
    my $SELECT = qq{SELECT } . $fields;
    my $FROM = qq{FROM $item_table, $coll_item_table};

    # XXX do we need to do a left join and then do something if there
    # is an item without metadata?
    my $WHERE = qq{WHERE $item_table.item_id = $coll_item_table.item_id AND $coll_item_table.MColl_ID = $coll_id};
    if (defined ($id_arr_ref))
    {
        my $IN = $self->arr_ref2SQL_in_string($id_arr_ref);
        $WHERE .= qq{ AND $item_table.item_id in $IN };
    }

    # limit to items with rights attributes listed in $rights_ref
    if (defined ($rights_ref->[0]))
    {
        my $AND =qq{ AND } . '( ';

        foreach my $rights (@{$rights_ref})
        {
            $AND .= qq{$item_table.rights = $rights OR };
        }

        # remove last "OR" and insert closing paren
        $AND =~ s,OR\s*$, \) ,;

        # append to WHERE
        $WHERE .= $AND;
    }

    if ($direction eq 'a')
    {
        $direction = 'ASC';
    }
    else
    {
        $direction = 'DESC';
    }

    my $ORDER = qq{ORDER BY $sort_key $direction};
    my $LIMIT = "";
    my $offset = $slice_start - 1; # MySQL limit counts records from 0
    if ($offset >= 0)
    {
        $LIMIT = "LIMIT $offset \,$recs_per_slice";
    }

    $statement = join (' ',qq{$SELECT $FROM $WHERE $ORDER $LIMIT}). "\;";

    DEBUG('dbcoll', qq{list_items sql=$statement});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $array_ref = $sth->fetchall_arrayref({});

     foreach my $item_hash_ref (@$array_ref)
     {
         my $author = $$item_hash_ref{'author'};
         $$item_hash_ref{'author'} = $author;
         
         my $display_title = $$item_hash_ref{'display_title'};
         $$item_hash_ref{'display_title'} = $display_title;
     }

    return $array_ref;
}

# ---------------------------------------------------------------------

=item arr_ref2SQL_in_string

Description

=cut

# ---------------------------------------------------------------------
sub arr_ref2SQL_in_string
{
    my $self = shift;
    my $id_arr_ref = shift;

    my $dbh = $self->get_dbh();
    my $id_string = "";

    foreach my $id (@{$id_arr_ref})
    {
        my  $quoted_id = $dbh->quote($id);
        $id_string .= $quoted_id . "\, ";
    }

    $id_string =~ s,\,\s*$,,;
    $id_string = '( ' . $id_string . ' ) ';

    return $id_string;
}


#======================================================================
#
# Methods for acting on collection metadata rather than lists of items
#
# Should these be moved to a true collection object and the list mgt
# functions be in a listMgr object?
# ----------------------------------------------------------------------
# shared_status is 1 if public 0 if private


# ---------------------------------------------------------------------

=item get_shared_status

Description

=cut

# ---------------------------------------------------------------------
sub get_shared_status
{
    my $self = shift;
    my $coll_id = shift;

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;
    my $status_string="";

    my $statement = qq{SELECT shared from $coll_table_name WHERE MColl_ID = $coll_id};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $status = $ary[0];

    # instead of returning 1 or 0 return strings
    if ($status == 0)
    {
        $status_string = 'private';
    }
    elsif ($status == 1)
    {
        $status_string = 'public'
    }
    else
    {
        ASSERT(0,qq{get_shared_status returned $status. It should be one or zero});
    }

    return $status_string;
}


# ---------------------------------------------------------------------

=item get_description

XXX do we need any special handling if $description is NULL?  What
does mysql return? What does DBI return?

=cut

# ---------------------------------------------------------------------
sub get_description
{
    my $self = shift;
    my $coll_id = shift;

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;
    my $statement = qq{SELECT description from $coll_table_name WHERE MColl_ID = $coll_id};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $description = $ary[0];

    return $description;
}


# ---------------------------------------------------------------------

=item get_coll_name

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_name
{
    my $self = shift;
    my $coll_id = shift;

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;
    my $statement = qq{SELECT collname from $coll_table_name WHERE MColl_ID = $coll_id};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $coll_name = $ary[0];

    return $coll_name;
}


# ---------------------------------------------------------------------

=item _edit_metadata

Description

=cut

# ---------------------------------------------------------------------
sub _edit_metadata
{
    my $self = shift;
    my $coll_id = shift;
    my $field = shift;
    my $value = shift;

    my $user_id = $self->get_user_id;
    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;
    my $coll_name = $self->get_coll_name($coll_id);

    ASSERT($self->coll_owned_by_user($coll_id, $user_id),
           qq{Can not edit this collection: Collection $coll_name id = $coll_id not owned by user $user_id});

    # XXX Insert any anti SQL injection processing here
    # $value=&cleanit($value);

    $value = DbUtils::quote($dbh, $value);
    my $statement = qq{UPDATE $coll_table_name SET $field = $value  WHERE MColl_ID = $coll_id};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    # XXX Do we need error trapping here? Check DBUtils
}

#----------------------------------------------------------------------

=item edit_status

saves public/private shared status to database

$co->edit_status($coll_id,$status)
$status is string "private" or "public"

=cut

#----------------------------------------------------------------------
sub edit_status
{
    my $self = shift;
    my $coll_id = shift;
    my $status = shift;

    # default of 1 is public
    my $value = 1;

    ASSERT(scalar($status =~ m,^(public|private)$,),
           qq{argument to edit_status must be either 'public' or 'private'});

    if ($status =~ /^private$/i)
    {
        $value = 0;
    }

    $self->_edit_metadata($coll_id, 'shared', $value);
}


#----------------------------------------------------------------------

=item edit_description

$co->edit_description($coll_id, $desc)

Saves description to datbase client is responsible for making sure
$desc is less than 255 characters.


=cut

#----------------------------------------------------------------------
sub edit_description
{
    my $self = shift;
    my $coll_id = shift;
    my $value = shift;
    my $dbh = $self->get_dbh;

    # truncate desc if more than 255 chars and then the following
    # assert should never get triggered check for off by one error

    ASSERT (length($value) <= 255,
            qq{Can't add new description because it is too long\nMaximum size of description is 255 characters});

    # XXX Do we need to check for SQL injection hacking? taint mode?

    # specific processing
    $self-> _edit_metadata($coll_id,'description',$value);
}


#----------------------------------------------------------------------

=item edit_coll_name

$co->edit_coll_name($coll_id, $name)

Replaces existing coll_name with $name client is responsible for
making sure coll_name is unique for this user


=cut

#----------------------------------------------------------------------
sub edit_coll_name
{
    my $self = shift;
    my $coll_id = shift;
    my $coll_name = shift;

    my $value = $coll_name;
    my $owner = $self->get_user_id;
    my $dbh = $self->get_dbh;
    my $config = $self->get_config;

    my $CS= CollectionSet->new($dbh,$self->{config},$owner) ;

    ASSERT(! $CS->exists_coll_name_for_owner($coll_name, $owner),qq{Can't change collection name because a collection owned by $owner already exists with that name $coll_name });

    # specific processing
    # check proposed changed name isn't already in use
    # need to use CollectionSet->exists_coll_name_for_owner()

    $self->_edit_metadata($coll_id, 'collname',$value);
}


#----------------------------------------------------------------------
#                            utility routines
# ---------------------------------------------------------------------


# ---------------------------------------------------------------------

=item item_in_collection

Description

=cut

# ---------------------------------------------------------------------
sub item_in_collection
{
    my $self = shift;
    my $item_id = shift;
    my $coll_id = shift;

    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;

    my $statement = "SELECT count(*) FROM $coll_item_table  WHERE MColl_ID = $coll_id and item_id = $item_id\;";

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $result = scalar($sth->fetchrow_array);

    return  ($result > 0);
}


# ---------------------------------------------------------------------

=item item_in_a_collection

Description

=cut

# ---------------------------------------------------------------------
sub item_in_a_collection
{
    my $self = shift;
    my $item_id = shift;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;
    my $statement = "SELECT count(*) FROM  $coll_item_table  WHERE  item_id = $item_id\;";
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my  $result = scalar($sth->fetchrow_array);

    #XXX  confirm this works
    return ($result > 0);
}

# ---------------------------------------------------------------------

=item item_exists

Description

=cut

# ---------------------------------------------------------------------
sub item_exists
{
    my $self = shift;
    my $item_id = shift;

    my $result = 0;

    if ($item_id)
    {
        my $item_table = $self->get_item_table_name;
        my $dbh = $self->get_dbh;
        $item_id = $dbh->quote($item_id);


        my $statement = "SELECT count(*) FROM  $item_table  WHERE  item_id = $item_id\;";
        my $sth = DbUtils::prep_n_execute($dbh, $statement);

        $result = scalar($sth->fetchrow_array);
    }

    return ($result > 0);
}


# ---------------------------------------------------------------------

=item item_exists_extern_id

Description

=cut

# ---------------------------------------------------------------------
sub item_exists_extern_id
{
    my $self = shift;
    my $extern_id = shift;


    my $result = 0;

    if ($extern_id)
    {
        my $item_table = $self->get_item_table_name;
        my $dbh = $self->get_dbh;
        my $quoted_extern_id = $dbh->quote($extern_id);
        my $statement = "SELECT count(*) FROM  $item_table  WHERE  extern_item_id = $quoted_extern_id\;";
        my $sth = DbUtils::prep_n_execute($dbh, $statement);

        $result = scalar($sth->fetchrow_array);
    }

    return ($result > 0);
}

# ---------------------------------------------------------------------

=item get_coll_ids_for_item

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_ids_for_item
{
    my $self = shift;
    my $item_id = shift;

    my $coll_item_table = $self->get_coll_item_table_name();
    my $dbh = $self->get_dbh;
    my @coll_ids = ();

    my $statement =
        qq{SELECT MColl_ID FROM $coll_item_table WHERE item_id='$item_id';};

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ary_of_ary_ref = $sth->fetchall_arrayref([0]);
    foreach my $ary_ref(@{$ary_of_ary_ref})
    {
        push(@coll_ids, $ary_ref->[0]);
    }

    return \@coll_ids;
}

# ---------------------------------------------------------------------

=item get_collnames_for_item

Description

=cut

# ---------------------------------------------------------------------
sub get_collnames_for_item
{
    my $self = shift;
    my $item_id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;
    my @collnames = ();

    my $statement = qq{SELECT $coll_table.collname FROM $coll_table, $coll_item_table WHERE $coll_table.MColl_ID = $coll_item_table.MColl_ID and item_id = $item_id ORDER BY  $coll_table.collname;};

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ary_of_ary_ref = $sth->fetchall_arrayref([0]);
    foreach my $ary_ref(@{$ary_of_ary_ref})
    {
        push (@collnames,$ary_ref->[0] );
    }

    return  (\@collnames);
}


# ---------------------------------------------------------------------

=item get_collnames_for_item_and_user

Description

=cut

# ---------------------------------------------------------------------
sub get_collnames_for_item_and_user
{
    my $self = shift;
    my $item_id = shift;
    my $user_id =shift;

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;
    my @collnames=();

    my $statement = qq{SELECT $coll_table.collname FROM $coll_table, $coll_item_table WHERE $coll_table.owner = \'$user_id\' and $coll_table.MColl_ID = $coll_item_table.MColl_ID and item_id = $item_id ORDER BY  $coll_table.collname \;};

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ary_of_ary_ref = $sth->fetchall_arrayref([0]);
    foreach my $ary_ref(@{$ary_of_ary_ref})
    {
        push(@collnames, $ary_ref->[0] );
    }

    return \@collnames;
}

# ---------------------------------------------------------------------

=item get_coll_data_for_item_and_user

returns array of hashrefs with id and coll_name for all collections
owned by the user containing the item

=cut

# ---------------------------------------------------------------------
sub get_coll_data_for_item_and_user
{
    my $self = shift;
    my $item_id = shift;
    my $user_id =shift;

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;
    my @collnames=();

    my $statement = qq{SELECT $coll_table.MColl_ID,$coll_table.collname FROM $coll_table, $coll_item_table WHERE $coll_table.owner = \'$user_id\' and $coll_table.MColl_ID = $coll_item_table.MColl_ID and item_id = $item_id ORDER BY  $coll_table.collname \;};

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $coll_data_ref = $sth->fetchall_arrayref({});

    # array of hashrefs
    return $coll_data_ref;
}


# ---------------------------------------------------------------------

=item count_full_text

Description

=cut

# ---------------------------------------------------------------------
sub count_full_text
{
    my $self = shift;
    my $coll_id = shift;
    my $rights_ref = shift;
    my $id_array_ref =shift;
    my $id_string;

    my $item_table = $self->get_item_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;

    ASSERT (defined ($rights_ref->[0]),qq{rights ref must be defined!});

    my $SELECT = qq{SELECT count($item_table.item_id) } ;
    my $FROM = qq{FROM $item_table, $coll_item_table};
    my $WHERE = qq{WHERE $item_table.item_id = $coll_item_table.item_id AND $coll_item_table.MColl_ID = $coll_id};
    if (defined ($id_array_ref))
    {
        $id_string =$self->arr_ref2SQL_in_string($id_array_ref);
        $WHERE .= qq{ AND $item_table.item_id in $id_string  };
    }

    my $AND = qq{ AND } . '( ';

    foreach my $rights (@{$rights_ref})
    {
        $AND .= qq{$item_table.rights = $rights OR };
    }

    # remove last "OR" and insert closing paren
    $AND =~ s,OR\s*$, \) ,;

    # append to WHERE
    $WHERE .= $AND;

    my $statement = join (' ',qq{$SELECT $FROM $WHERE}). "\;";
    DEBUG('dbcoll', qq{count_full_text sql=$statement});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $countref = $sth->fetchall_arrayref([0]);
    my $count = $countref->[0]->[0];

    return $count;
}


# ---------------------------------------------------------------------

=item count_all_items_for_coll

Description

=cut

# ---------------------------------------------------------------------
sub count_all_items_for_coll
{
    my $self = shift;
    my $coll_id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $statement = qq{SELECT num_items from $coll_table WHERE MColl_ID= $coll_id};

    DEBUG('dbcoll', qq{count_all_items_for_coll sql=$statement});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $countref = $sth->fetchall_arrayref([0]);
    my $count = $countref->[0]->[0];

    return $count;
}
# ---------------------------------------------------------------------

=item get_item_ids_for_coll

my $id_ary_ref=$co->get_item_ids_for_coll($coll_id);

=cut

# ---------------------------------------------------------------------
sub get_item_ids_for_coll
{
    my $self = shift;
    my $coll_id = shift;
    my $coll_item_table = $self->get_coll_item_table_name;

    my $statement = qq{SELECT item_id from $coll_item_table WHERE MColl_ID='$coll_id' ORDER by item_id};

    DEBUG('dbcoll', qq{get_item_ids_for_coll sql=$statement});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ids_ary_of_ary_ref = $sth->fetchall_arrayref([0]);

    my $ids_ary_ref = [];
    my $count = 0;
    foreach my $ary_ref (@{$ids_ary_of_ary_ref})
    {
        $ids_ary_ref->[$count] = $ary_ref->[0];
        $count++;
    }

    return $ids_ary_ref;
}

# ---------------------------------------------------------------------

=item get_metadata_for_item_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_metadata_for_item_ids
{
    my $self = shift;
    my $item_id_ref = shift;
    my $item_table = $self->get_item_table_name;

    my @metadata_fields = $self->get_item_display_fields_arr;
    push(@metadata_fields, 'rights');
    push(@metadata_fields, 'extern_item_id');
    push(@metadata_fields, 'sort_title');

    my $dbh = $self->get_dbh();

    my $id_string = $self->arr_ref2SQL_in_string($item_id_ref);

    # qualify field names: "$item_table.fieldname" and join in comma
    # delimited string
    @metadata_fields = map {"$item_table." . $_} @metadata_fields;
    my $fields = join (", ", @metadata_fields);

    my $SELECT = qq{SELECT } . $fields;
    my $WHERE = qq{ WHERE item_id in $id_string};
    my $FROM = qq{ FROM $item_table };

    my $statement = $SELECT . $FROM  .  $WHERE . "\;";
    DEBUG('dbcoll', qq{get_metadata_for_item_ids sql=$statement});

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $item_data_ary_of_hashref = $sth->fetchall_arrayref({});

    # array of hashrefs where each hash is fieldname=>value
    return $item_data_ary_of_hashref;

    # XXX alternative is to use different DBI construct and get data
    # row by row return a hashref key = item_id value = hashref
    # containing fieldnames and values
}

# ---------------------------------------------------------------------

=item get_metadata_for_item

Description

=cut

# ---------------------------------------------------------------------
sub get_metadata_for_item
{
    my $self = shift;
    my $item_id = shift;
    my $item_table = $self->get_item_table_name;

    my @metadata_fields = $self->get_item_display_fields_arr;
    push(@metadata_fields, 'rights');
    push(@metadata_fields, 'extern_item_id');
    push(@metadata_fields, 'sort_title');

    my $dbh = $self->get_dbh();

    $item_id = $dbh->quote($item_id);

    # qualify field names: "$item_table.fieldname" and join in comma
    # delimited string
    @metadata_fields = map {"$item_table." . $_} @metadata_fields;
    my $fields = join (", ", @metadata_fields);

    my $SELECT = qq{SELECT } . $fields;
    my $WHERE = qq{ WHERE item_id = $item_id};
    my $FROM = qq{ FROM $item_table };

    my $statement = $SELECT . $FROM  .  $WHERE . "\;";
    DEBUG('dbcoll', qq{get_metadata_for_item sql=$statement});

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    # XXX replace with better dbi call we only should get one row
    my $item_data_ary_of_hashref = $sth->fetchall_arrayref({});
    #  array of hashrefs where each hash is fieldname=>value
    my $item_data_hashref = $item_data_ary_of_hashref->[0];

    return $item_data_hashref;
}

# ---------------------------------------------------------------------

=item count_all_items_for_coll_from_coll_items

Description

=cut

# ---------------------------------------------------------------------
sub count_all_items_for_coll_from_coll_items
{
    my $self = shift;
    my $coll_id = shift;

    my $coll_item_table = $self->get_coll_item_table_name;

    my $SELECT = qq{SELECT count(item_id) } ;
    my $FROM = qq{FROM $coll_item_table};
    my $WHERE = qq{WHERE MColl_ID = $coll_id};

    my $statement = join (' ',qq{$SELECT $FROM $WHERE}). "\;";
    DEBUG('dbcoll', qq{count_all_items_for_coll_from_coll_items sql=$statement});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $countref = $sth->fetchall_arrayref([0]);
    my $count = $countref->[0]->[0];

    return $count;
}


# ---------------------------------------------------------------------

=item update_item_count

updates the collection table to match the actual counts of items in
the coll_items table

# XXX should this be CollectionSet's responsibility?

=cut

# ---------------------------------------------------------------------
sub update_item_count
{
    my $self = shift;
    my $coll_id = shift;

    my $dbh = $self->get_dbh();
    my $coll_table = $self->get_coll_table_name;
    my $coll_item_count = $self->count_all_items_for_coll_from_coll_items($coll_id);

    my $statement = qq{UPDATE $coll_table SET num_items = $coll_item_count where MColl_ID=$coll_id\;};

    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $collection_table_count = $self->count_all_items_for_coll($coll_id);

    ASSERT($coll_item_count == $collection_table_count,qq{update_item_count failed for $coll_id });
}

# ---------------------------------------------------------------------


# ---------------------------------------------------------------------

=item  get_full_text_ids($result_id_arrayref, $rights_ref);

returns arrayref of ids that are full-text, given list(ref to array)
of ids and rights ref


=cut

# ---------------------------------------------------------------------
sub get_full_text_ids
{
    my $self = shift;
    my $id_ary_ref = shift;
    my $rights_ref = shift;

    my $item_table = $self->get_item_table_name;
    my $dbh = $self->get_dbh();

    my $IN = $self->arr_ref2SQL_in_string($id_ary_ref);
    my $WHERE = qq{ WHERE item_id in $IN };

    # limit to items with rights attributes listed in $rights_ref
    my $AND =qq{ AND } . '( ';

    foreach my $rights (@{$rights_ref})
    {
        $AND .= qq{ rights = $rights OR };
    }

    # remove last "OR" and insert closing paren
    $AND =~ s,OR\s*$, \) ,;

    # append to WHERE
    $WHERE .= $AND;

    my $statement = qq{SELECT item_id FROM $item_table  $WHERE  \;};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ref_ary_of_ary_ref=$sth->fetchall_arrayref([0]);

    # XXX use different dbi function so we don't have to do
    # conversion!  this is a ref to array refs to arrays convert to
    # ref to array
    my $return_ref;
    my $count = 0;

    foreach my $arr_ref (@{$ref_ary_of_ary_ref})
    {
        $return_ref->[$count]=$arr_ref->[0];
        $count++;
    }

    return $return_ref
}

# ---------------------------------------------------------------------

=item one_or_more_items_in_coll

returns true of one or more items in $item_id_ary_ref is in the collection
$co->one_or_more_items_in_coll($coll_id,$item_id_ref)

=cut

# ---------------------------------------------------------------------
sub one_or_more_items_in_coll
{
    my $self = shift;
    my $coll_id = shift;
    my $item_id_ref =shift;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh();

    my $INLIST = $self->arr_ref2SQL_in_string($item_id_ref);
    
    my $statement = qq{SELECT count(*) from $coll_item_table WHERE MColl_ID='$coll_id' AND item_id in $INLIST };
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $count = $ary[0];
    return ($count > 0);
}



#======================================================================
# indexing related stuff 

# read index_failures table
# add,read,delete index_queue table

# ---------------------------------------------------------------------

=item  is_item_index_failure

$co->is_item_index_failure($item_id)


=cut

# ---------------------------------------------------------------------
sub is_item_index_failure 
{
    my $self = shift;
    my $item_id = shift;
    
    my $index_failures = $self->get_index_failures_table_name;
    my $dbh = $self->get_dbh();
    my $statement = qq{SELECT count(*) FROM $index_failures WHERE  item_id = $item_id ;};

    
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my @ary = $sth->fetchrow_array;
    my $count = $ary[0];
    return ($count > 0);

}

# ---------------------------------------------------------------------

=item add_to_queue_helper

Perform add_to_queue for each site

=cut

# ---------------------------------------------------------------------
sub add_to_queue_helper
{
    my $self = shift;
    
    my $item_id = shift;
    my $coll_ids_string = shift;
    my $priority = shift;
    my $site = shift;
    
    my $index_queue = $self->get_index_queue_table_name;
    
    my $INSERT_SQL;
    $INSERT_SQL .= qq{INSERT into $index_queue (item_id, coll_ids, priority, time_added, site) };
    $INSERT_SQL .= qq{ VALUES };
    $INSERT_SQL .= qq{ ( '$item_id', $coll_ids_string, $priority, now(), '$site' ) };
    
    my $PRIORITY_SQL = qq{ priority = if ($priority < priority, $priority, priority) };
    
    my $UPDATE_SQL;
    $UPDATE_SQL .= qq{ ON DUPLICATE KEY UPDATE  };
    $UPDATE_SQL .= qq{ coll_ids = $coll_ids_string, };
    $UPDATE_SQL .= $PRIORITY_SQL;
    
    my $statement = $INSERT_SQL . $UPDATE_SQL;
    
    DEBUG('dbcoll', qq{add_to_queue_helper sql=$statement});
    
    my $sth = DbUtils::prep_n_execute($self->get_dbh(), $statement);    
}

# ---------------------------------------------------------------------

=item  add_to_queue

$co->add_to_queue($coll_id,$\@item_ids, $priority)

=cut

# ---------------------------------------------------------------------
sub add_to_queue
{
    my $self = shift;
    my $item_id_ref = shift;
    my $priority = shift;
    
    ASSERT(ref($item_id_ref) eq 'ARRAY',
           qq{Argument is not a ref to an array, must have a ref to array of item ids});
    ASSERT(scalar($item_id_ref) >= 1,
           qq{ must have a ref to one or more items});
    ASSERT(defined($priority),
           qq{  priority undefined});

    foreach my $item_id (@{$item_id_ref})
    {
        # get collids for item and create bar delimited string
        my $ary_ref = $self->get_coll_ids_for_item($item_id);
        my @coll_ids = @{$ary_ref};
        my $coll_ids_string;
        
        if (scalar(@coll_ids) == 0)
        {
            # if an item is not in any collection $coll_ids_string should set collid to 0
            $coll_ids_string = IX_NO_COLLECTION;
        }
        else
        {
            $coll_ids_string = join('|', @coll_ids);
        }
        $coll_ids_string = $self->get_dbh()->quote($coll_ids_string);

        # Add item_id to the queue for every site's indexer to process to
        # keep indexes synched across sites
        my $config = $self->get_config;
        foreach my $site (Search::Site::get_site_names($config))
        {
            $self->add_to_queue_helper($item_id, $coll_ids_string, $priority, $site);
        }
    }
}
    
# ---------------------------------------------------------------------

=item collnames_recently_added

Description

=cut

# ---------------------------------------------------------------------
sub collnames_recently_added
{
    my $self = shift;
    my $limit = shift;

    my $dbh = $self->get_dbh();
    my $coll_table = $self->get_coll_table_name;

    my $statement = qq{SELECT collname, MColl_ID FROM $coll_table WHERE shared='1' ORDER BY modified DESC LIMIT $limit;};
    
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $array_ref = $sth->fetchall_arrayref({});

    return $array_ref;
}



#======================================================================

1;

__END__

=head1 AUTHOR

Tom Burton-West, University of Michigan, tburtonw@umich.edu

=head1 COPYRIGHT

Copyright 2007 ©, The Regents of The University of Michigan, All Rights Reserved

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
