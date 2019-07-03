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
sub _initialize {
    my $self = shift;
    $self->{'dbh'} = shift;
    my $config = shift;
    $self->{'user_id'} = CollectionUser->new(shift);

    $self->{'config'} = $config;
    my $use_test_tables = DEBUG('usetesttbl') || $config->get('use_test_tables');

    if ($use_test_tables) {
        $self->{'coll_table_name'} = $config->get('test_coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('test_coll_item_table_name');
        $self->{'item_table_name'} = $config->get('test_item_table_name');
    }
    else {
        $self->{'coll_table_name'} = $config->get('coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('coll_item_table_name');
        $self->{'item_table_name'} = $config->get('item_table_name');
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

sub get_user
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
    my $user = CollectionUser->new(shift);

    my ( $owner_names, $owner_expr ) = CollectionSet->_get_owner_expr($user);

    # Utils::trim_spaces(\$username);

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;

    my $statement = qq{SELECT owner FROM $coll_table_name WHERE MColl_id = ? AND owner IN ( $owner_expr )};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id, @$owner_names);
    my @ary = $sth->fetchrow_array;

    return scalar @ary == 1;

    # my $owner = $ary[0];

    # DEBUG('dbcoll', qq{username = $username collection $coll_id owned by $owner"});

    # # When owner is an email address, compare case in-sensitively to avoid stuff like
    # # Mary.Smith@some.edu vs. Mary.smith@some.edu (both legit)
    # my ($test_username, $test_owner) = ($username, $owner);
    # if ($test_owner =~ m,@,) {
    #     ($test_username, $test_owner) = (lc($username), lc($owner));
    # }

    # return ($test_username eq $test_owner);
}

sub coll_owned_by_user_XXX
{
    my $self = shift;
    my $coll_id = shift;
    my $username = shift;

    Utils::trim_spaces(\$username);

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;

    my $statement = qq{SELECT owner FROM $coll_table_name WHERE MColl_id = ?};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
    my @ary = $sth->fetchrow_array;
    my $owner = $ary[0];

    DEBUG('dbcoll', qq{username = $username collection $coll_id owned by $owner"});

    # When owner is an email address, compare case in-sensitively to avoid stuff like
    # Mary.Smith@some.edu vs. Mary.smith@some.edu (both legit)
    my ($test_username, $test_owner) = ($username, $owner);
    if ($test_owner =~ m,@,) {
        ($test_username, $test_owner) = (lc($username), lc($owner));
    }

    return ($test_username eq $test_owner);
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

    my $statement = qq{SELECT owner_name FROM $coll_table_name WHERE MColl_id=?};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
    my @ary = $sth->fetchrow_array;
    my $owner_display_name = $ary[0];

    return $owner_display_name;
}

# ---------------------------------------------------------------------

=item get_coll_owner

Returns owner (as opposed to owner_display_name) which is the unique persistent
id for the user) for a given coll_id

=cut

# ---------------------------------------------------------------------
sub get_coll_owner {
    my $self = shift;
    my $coll_id = shift;

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;

    my $statement = qq{SELECT owner FROM $coll_table_name WHERE MColl_id=?};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
    my @ary = $sth->fetchrow_array;
    my $owner = $ary[0];

    return $owner;
}


# ---------------------------------------------------------------------

=item create_or_update_item_metadata

This adds an item to the item metadata table.  Caller is responsible
for also adding it to a collection

These need to be worked out assuming we separate extern_id from
item_id

=cut

# ---------------------------------------------------------------------
sub create_or_update_item_metadata {
    my $self = shift;
    my $metadata_ref = shift;

    my $dbh = $self->get_dbh;
    my $item_table_name = $self->get_item_table_name;
    my $id = $metadata_ref->{'extern_item_id'};

    DbUtils::begin_work($dbh);
    eval {
        if ($self->item_exists($id)) {
            # item already in table so just update the metadata
            DbUtils::update_row_by_key($dbh, $item_table_name, $metadata_ref, 'extern_item_id', $id);
        }
        else {
            # item not in item_metadata table so create new item and
            # return extern_item_id do sql insert.  Generate a new unique item_id.
            ### DbUtils::insert_new_row($dbh, $item_table_name, $metadata_ref);
            DbUtils::insert_or_update_row($dbh, $item_table_name, $metadata_ref, 'extern_item_id');
        }

        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with create_or_update_item_metadata: $err});
    }    

    return $id;
}


# ---------------------------------------------------------------------

=item _field_is_valid

Description

=cut

# ---------------------------------------------------------------------
sub _field_is_valid
{
    my $self = shift;
    my $fieldname = shift;
    my $value = shift;

    my $item_table_name = $self->get_item_table_name;
    my $dbh = $self->get_dbh;

}

# ---------------------------------------------------------------------

=item copy_items

copy_items($coll_id,\@ids)
This only adds existing items to an existing collection

=cut

# ---------------------------------------------------------------------
sub copy_items {
    my $self = shift;
    my $coll_id = shift;
    my $id_arr_ref = shift;
    my $force_ownership = shift;

    my $dbh = $self->get_dbh;
    my $coll_item_table_name = $self->get_coll_item_table_name;
    my $row_array_ref = [];
    my $col_names_array_ref = ['extern_item_id','MColl_ID'];
    # my $user_id = $self->get_user_id;
    my $user = $self->get_user;

    unless ($force_ownership) {
        ASSERT($self->coll_owned_by_user($coll_id, $user),
               qq{Collection $coll_id not owned by user $user});
    }

    foreach my $id (@$id_arr_ref) {
        if ($self->item_exists($id)) {
            push (@$row_array_ref, [$id, $coll_id]);
        }
        else {
            ASSERT (0, qq{item id $id does not exist in item table});
        }
    }

    DbUtils::begin_work($dbh);
    eval {
        # Add the items
        DbUtils::insert_one_or_more_rows($dbh, $coll_item_table_name, $col_names_array_ref, $row_array_ref);

        # Add count to collections table
        $self->update_item_count($coll_id);

        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with copy_items: $err});
    } 
}


# ---------------------------------------------------------------------

=item delete_items

delete_items($coll_id,\@ids)

Only removes the relationship between collection and items does not
affect item metadata checks that user is owner of collection

=cut

# ---------------------------------------------------------------------
sub delete_items {
    my $self = shift;
    my $coll_id = shift;
    my $id_arr_ref = shift;
    my $force_ownership = shift;

    my $dbh = $self->get_dbh();
    my $coll_item_table_name = $self->get_coll_item_table_name;

    unless ($force_ownership) {
        my $user = $self->get_user;
        ASSERT($self->coll_owned_by_user($coll_id, $user),
               qq{Can not delete items:  Collection $coll_id not owned by user $user});
    }

    my $id_string = $self->arr_ref2SQL_in_string($id_arr_ref);

    DbUtils::begin_work($dbh);
    eval {
        my $statement = qq{DELETE FROM $coll_item_table_name WHERE extern_item_id IN $id_string AND MColl_ID=?};
        DbUtils::prep_n_execute ($dbh, $statement, @$id_arr_ref, $coll_id);

        # update item count int collection table!
        $self->update_item_count($coll_id);

        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with delete_items: $err});
    }
}

#----------------------------------------------------------------------

=item delete_coll(coll_id)

Description

=cut

#----------------------------------------------------------------------
sub delete_coll {
    my $self = shift;
    my $coll_id = shift;
    my $force_ownership = shift;

    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;
    my $coll_item_table_name = $self->get_coll_item_table_name;
    my $user = $self->get_user;

    unless ($force_ownership) {
        ASSERT($self->coll_owned_by_user($coll_id, $user),
               qq{Collection $coll_id not owned by user $user});
    }

    DbUtils::begin_work($dbh);
    eval {
        DbUtils::del_row_by_key($dbh, $coll_table_name, 'MColl_ID', $coll_id);

        # DbUtils doesn't return a status so should we write our own?
        # return $status;
        DbUtils::del_one_or_more_rows_by_key($dbh, $coll_item_table_name, 'MColl_ID', $coll_id);

        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with delete_coll: $err});
    }
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
sub list_items {
    my $self = shift;
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice, $rights_ref, $id_arr_ref) = @_;

    ASSERT($sort_key, qq{no sort key supplied});
    ASSERT($direction, qq{no direction supplied});

    my $item_table = $self->get_item_table_name;
    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;

    my @metadata_fields = ( $self->get_item_display_fields_arr, (qw/rights extern_item_id/) );
    my $item_sort_fields_arr_ref = $self->get_item_sort_fields_arr_ref;


    # undefined $slice_start and for $recs_per_slice implies no LIMIT
    # clause below
    DEBUG('dbcoll', qq{slice start is $slice_start at $recs_per_slice records per slice});

    my $sort_key_in_sort_fields = grep(/$sort_key/, @$item_sort_fields_arr_ref);
    ASSERT($sort_key_in_sort_fields, qq{Collection::list_items $sort_key not in item_sort_fields});

    # SELECT FROM
    @metadata_fields = map { "a." . $_ } @metadata_fields;
    my $fields = join(",", @metadata_fields);

    my $SELECT = qq{SELECT $item_table.extern_item_id FROM $item_table, $coll_item_table };

    # WHERE
    my $WHERE = qq{WHERE $item_table.extern_item_id=$coll_item_table.extern_item_id AND $coll_item_table.MColl_ID=?};
    if (defined $id_arr_ref) {
        my $IN_clause = $self->arr_ref2SQL_in_string($id_arr_ref);
        $WHERE .= qq{ AND $item_table.extern_item_id IN $IN_clause };
    }

    # AND IN $rights_ref
    if (defined $rights_ref->[0]) {
        my $IN_clause = $self->arr_ref2SQL_in_string([ sort { $a <=> $b } @$rights_ref ]);
        $WHERE .= qq{ AND $item_table.rights IN $IN_clause };
    }

    # ORDER BY
    $direction = ($direction eq 'a') ? 'ASC' : 'DESC';
    $WHERE .= qq{ ORDER BY $sort_key $direction};

    # LIMIT
    my $LIMIT = '';
    my $offset = $slice_start - 1; # MySQL limit counts records from 0
    if ($offset >= 0) {
        $LIMIT = qq{ LIMIT $offset, $recs_per_slice};
    }

    # # NOTE: this odd construct is for efficiency
    #### add time() to bust MySQL cache
    #### $fields = time() . ", $fields";
    my $statement = qq{SELECT $fields FROM ( $SELECT $WHERE $LIMIT ) o JOIN $item_table a ON a.extern_item_id = o.extern_item_id ORDER BY $sort_key $direction};

    DEBUG('dbcoll', qq{list_items sql=$statement});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id, @$id_arr_ref, @$rights_ref);
    my $arr_ref = $sth->fetchall_arrayref({});

    return $arr_ref;
}


# ---------------------------------------------------------------------

=item arr_ref2SQL_in_string

Description

=cut

# ---------------------------------------------------------------------
sub arr_ref2SQL_in_string {
    my $self = shift;
    my $id_arr_ref = shift;

    my $s = '(' . join(',', map {'?'} @$id_arr_ref) . ')';
    return $s;
}


#======================================================================
#
# Methods for acting on collection metadata rather than lists of items
#
# Should these be moved to a true collection object and the list mgt
# functions be in a listMgr object?

# ---------------------------------------------------------------------

=item get_coll_record

Description

Fetches the row for $coll_id and caches the result.

=cut

# ---------------------------------------------------------------------
sub get_coll_record {
    my $self = shift;
    my $coll_id = shift;

    unless ( defined $self->{_collection_collid_record}->{$coll_id} ) {
        my $dbh = $self->get_dbh();
        my $coll_table_name = $self->get_coll_table_name;
        my $statement = qq{SELECT * from $coll_table_name WHERE MColl_ID=?};
        my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
        $self->{_collection_collid_record}->{$coll_id} = $sth->fetchrow_hashref;
    }
    return $self->{_collection_collid_record}->{$coll_id} || {};
}

# ----------------------------------------------------------------------
# shared_status is 1 if public 0 if private


# ---------------------------------------------------------------------

=item get_shared_status

Description

=cut

# ---------------------------------------------------------------------
sub get_shared_status {
    my $self = shift;
    my $coll_id = shift;

    my $status_string = "";
    my $status = $self->get_coll_record($coll_id)->{shared};

    # instead of returning 1 or 0 return strings
    if ($status == 0) {
        $status_string = 'private';
    }
    elsif ($status == 1) {
        $status_string = 'public'
    }
    elsif ($status == -1) {
        $status_string = 'draft';
    }
    else {
        ASSERT(0, qq{get_shared_status returned $status. It should be one or zero});
    }

    return $status_string;
}


# ---------------------------------------------------------------------

=item get_description

Description

=cut

# ---------------------------------------------------------------------
sub get_description {
    my $self = shift;
    my $coll_id = shift;

    return $self->get_coll_record($coll_id)->{description};
}


# ---------------------------------------------------------------------

=item get_coll_name

Description

=cut

# ---------------------------------------------------------------------

sub get_coll_name {
    my $self = shift;
    my $coll_id = shift;
    return $self->get_coll_record($coll_id)->{collname};
}

sub get_coll_featured {
    my $self = shift;
    my $coll_id = shift;
    return $self->get_coll_record($coll_id)->{featured};
}

sub get_coll_branding {
    my $self = shift;
    my $coll_id = shift;
    return $self->get_coll_record($coll_id)->{branding};
}

sub get_coll_contact_info {
    my $self = shift;
    my $coll_id = shift;
    return $self->get_coll_record($coll_id)->{contact_info};
}

# ---------------------------------------------------------------------

=item _edit_metadata

Description

=cut

# ---------------------------------------------------------------------
sub _edit_metadata {
    my $self = shift;
    my $coll_id = shift;
    my $field = shift;
    my $value = shift;
    my $max_length = shift;

    my $user = $self->get_user;
    my $dbh = $self->get_dbh();
    my $coll_table_name = $self->get_coll_table_name;
    my $coll_name = $self->get_coll_name($coll_id);

    ASSERT($self->coll_owned_by_user($coll_id, $user),
           qq{Can not edit this collection: Collection $coll_name id = $coll_id not owned by user $user});

    if (defined($max_length)) {
        if (length($value) > $max_length) {
            $value = substr($value, 0, $max_length);
        }
    }

    DbUtils::begin_work($dbh);
    eval {
        # Add the items
        my $statement = qq{UPDATE $coll_table_name SET $field=?  WHERE MColl_ID=?};
        my $sth = DbUtils::prep_n_execute($dbh, $statement, $value, $coll_id);

        # clear the cache
        delete $self->{_collection_collid_record}->{$coll_id};

        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with _edit_metadata : $field : $err});
    }    
}


#----------------------------------------------------------------------

=item edit_status

saves public/private shared status to database

$co->edit_status($coll_id,$status)
$status is string "private" or "public"

=cut

#----------------------------------------------------------------------
sub edit_status {
    my $self = shift;
    my $coll_id = shift;
    my $status = shift;

    # default of 1 is public
    my $value = 1;

    ASSERT(scalar($status =~ m,^(public|private|draft)$,),
           qq{argument to edit_status must be either 'public' or 'private'});

    if ($status =~ /^private$/i) {
        $value = 0;
    } elsif ($status =~ /^draft$/i) {
        $value = -1;
    }

    $self->_edit_metadata($coll_id, 'shared', $value);
}


#----------------------------------------------------------------------

=item edit_description

$co->edit_description($coll_id, $desc)

Saves description to datbase client is responsible for making sure
$desc is less than 150 characters.


=cut

#----------------------------------------------------------------------
sub edit_description {
    my $self = shift;
    my $coll_id = shift;
    my $description = shift;

    $self-> _edit_metadata($coll_id, 'description', $description, 255);
}


#----------------------------------------------------------------------

=item edit_coll_name

$co->edit_coll_name($coll_id, $name)

Replaces existing coll_name with $name client is responsible for
making sure coll_name is unique for this user

=cut

#----------------------------------------------------------------------
sub edit_coll_name {
    my $self = shift;
    my $coll_id = shift;
    my $coll_name = shift;

    $self->_edit_metadata($coll_id, 'collname', $coll_name, 100);
}


#----------------------------------------------------------------------
#                            utility routines
# ---------------------------------------------------------------------


# ---------------------------------------------------------------------

=item item_in_collection

Description

=cut

# ---------------------------------------------------------------------
sub item_in_collection {
    my $self = shift;
    my $id = shift;
    my $coll_id = shift;

    my $items_hr = $self->get_ids_for_coll($coll_id, {});
    return ( $$items_hr{$id} );

    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;

    my $statement = qq{SELECT count(*) FROM $coll_item_table WHERE MColl_ID=? AND extern_item_id=?};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id, $id);
    my $result = scalar($sth->fetchrow_array);

    return ($result > 0);
}


# ---------------------------------------------------------------------

=item item_exists

Description

=cut

# ---------------------------------------------------------------------
sub item_exists {
    my $self = shift;
    my $id = shift;

    my $result = 0;

    if ($id) {
        my $item_table = $self->get_item_table_name;
        my $dbh = $self->get_dbh;

        my $statement = qq{SELECT count(*) FROM $item_table WHERE extern_item_id=?};
        my $sth = DbUtils::prep_n_execute($dbh, $statement, $id);

        $result = scalar($sth->fetchrow_array);
    }

    return ($result > 0);
}


# ---------------------------------------------------------------------

=item get_coll_ids_for_item

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_ids_for_item {
    my $self = shift;
    my $id = shift;

    my $coll_item_table = $self->get_coll_item_table_name();
    my $dbh = $self->get_dbh;
    # my $q_id = $dbh->quote($id);

    my $statement = qq{SELECT MColl_ID FROM $coll_item_table WHERE extern_item_id=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $id);
    my $ref_to_ary_of_ary_ref = $sth->fetchall_arrayref([0]);
    my $coll_ids_ary_ref = [ map {$_->[0]} @$ref_to_ary_of_ary_ref ];

    return $coll_ids_ary_ref;
}

# ---------------------------------------------------------------------

=item get_collnames_for_item

Description

=cut

# ---------------------------------------------------------------------
sub get_collnames_for_item {
    my $self = shift;
    my $id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;
    # my $q_id = $dbh->quote($id);

    my $statement = qq{SELECT $coll_table.collname FROM $coll_table, $coll_item_table WHERE $coll_table.MColl_ID=$coll_item_table.MColl_ID AND extern_item_id=? ORDER BY $coll_table.collname};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $id);
    my $ref_to_ary_of_ary_ref = $sth->fetchall_arrayref([0]);
    my $collnames_ary_ref = [ map {$_->[0]} @$ref_to_ary_of_ary_ref ];

    return $collnames_ary_ref;
}


# ---------------------------------------------------------------------

=item get_collnames_for_item_and_user

Description

=cut

# ---------------------------------------------------------------------
sub get_collnames_for_item_and_user {
    my $self = shift;
    my $id = shift;
    my $user_id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;
    # my $q_id = $dbh->quote($id);

    my $statement = qq{SELECT $coll_table.collname FROM $coll_table, $coll_item_table WHERE $coll_table.owner=? AND $coll_table.MColl_ID=$coll_item_table.MColl_ID AND extern_item_id=? ORDER BY $coll_table.collname};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $user_id, $id);
    my $ref_to_ary_of_ary_ref = $sth->fetchall_arrayref([0]);
    my $collnames_ary_ref = [ map {$_->[0]} @$ref_to_ary_of_ary_ref ];

    return $collnames_ary_ref;
}

# ---------------------------------------------------------------------

=item get_coll_id_for_collname_and_user

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_id_for_collname_and_user {
    my $self = shift;
    my $collname = shift;
    my $user_id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $dbh = $self->get_dbh;

    my $statement = qq{SELECT MColl_ID FROM $coll_table WHERE owner_name=? AND collname=?};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $user_id, $collname);
    my $MColl_ID = $sth->fetchrow_array();

    return $MColl_ID;
}

# ---------------------------------------------------------------------

=item get_coll_data_for_item_and_user

returns array of hashrefs with id and coll_name for all collections
owned by the user containing the item

=cut

# ---------------------------------------------------------------------
sub get_coll_data_for_item_and_user {
    my $self = shift;
    my $id = shift;
    my $user_id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;

    my $statement = qq{SELECT $coll_table.MColl_ID, $coll_table.collname FROM $coll_table, $coll_item_table WHERE $coll_table.owner=? AND $coll_table.MColl_ID=$coll_item_table.MColl_ID AND extern_item_id=? ORDER BY $coll_table.collname};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $user_id, $id);
    my $ref_to_ary_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_ary_of_hashref;
}

sub get_coll_data_for_items_and_user {
    my $self = shift;
    my $idlist = shift;
    my $user_id = shift;

    return {} unless ( scalar @$idlist );

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh;

    my $expr = []; my $params = [];
    foreach my $item_hashref ( @$idlist ) {
        push @$expr, '?';
        push @$params, $item_hashref->{'extern_item_id'};
    }

    $expr = join(',', @$expr);

    my $statement = qq{SELECT $coll_table.MColl_ID, $coll_table.collname, $coll_item_table.extern_item_id FROM $coll_table, $coll_item_table WHERE $coll_table.owner=? AND $coll_table.MColl_ID=$coll_item_table.MColl_ID AND extern_item_id IN ( $expr ) ORDER BY $coll_table.collname};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $user_id, @$params);
    my $ref_to_ary_of_hashref = $sth->fetchall_arrayref({});
    my $result = {};
    foreach my $ref ( @$ref_to_ary_of_hashref ) {
        my $id = $$ref{extern_item_id};
        unless ( ref($$result{$id}) ) {
            $$result{$id} = [];
        }
        push @{ $$result{ $id } }, $ref;
    }

    return $result;
}

# ---------------------------------------------------------------------

=item count_full_text

Description

=cut

# ---------------------------------------------------------------------
sub count_full_text {
    my $self = shift;
    my $coll_id = shift;
    my $rights_ref = shift;
    my $id_array_ref = shift || [];

    ASSERT(defined ($rights_ref->[0]), qq{rights ref must be defined!});

    unless ( scalar @$id_array_ref ) {
        my $coll_item_table = $self->get_coll_item_table_name;
        my $coll_table = $self->get_coll_table_name;
        my $item_table = $self->get_item_table_name;

        my $expr = [ map { '?' } @$rights_ref ];
        $expr = join(',', @$expr);

        my $count = 0;
        my $dbh = $self->get_dbh;
        my $statement = qq{SELECT SQL_CALC_FOUND_ROWS b.extern_item_id FROM $coll_item_table a JOIN $item_table b WHERE a.extern_item_id = b.extern_item_id AND a.MColl_ID = ? AND b.rights IN ($expr) LIMIT 1};
        my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id, sort @$rights_ref);
        $sth = DbUtils::prep_n_execute($dbh, qq{SELECT FOUND_ROWS()});
        ( $count ) = $sth->fetchrow_array();
        return $count;
    }

    my $rights_hr = { map { $_ => 1 } @$rights_ref }; 
    my $items_hr = $self->get_ids_for_coll($coll_id, {});
    # unless ( scalar @$id_array_ref ) {
    #     $id_array_ref = [ keys %$items_hr ];
    # }
    my $count = 0;
    foreach my $id ( @$id_array_ref ) {
        my $rights = $$items_hr{$id};
        my $check = $$rights_hr{$rights};
        $count += 1 if ( $check );
    }
    return $count;
}

# ---------------------------------------------------------------------

=item collection_is_large

Description

=cut

# ---------------------------------------------------------------------
sub collection_is_large {
    my $self = shift;
    my $coll_id = shift;
    my $num_items_in_coll = shift;

    my $small_collection_max_items = $self->get_config()->get('filter_query_max_item_ids');
    unless (defined $num_items_in_coll) {
        $num_items_in_coll  = $self->count_all_items_for_coll($coll_id);
    }

    return ($num_items_in_coll > $small_collection_max_items);
}

sub collection_is_very_large {
    my $self = shift;
    my $coll_id = shift;
    my $num_items_in_coll = shift;

    my $large_collection_max_items = $self->get_config()->get('delete_check_max_item_ids');
    unless (defined $num_items_in_coll) {
        $num_items_in_coll  = $self->count_all_items_for_coll($coll_id);
    }

    return ($num_items_in_coll >= $large_collection_max_items);
}

# ---------------------------------------------------------------------

=item count_rights_for_coll

Description

=cut

# ---------------------------------------------------------------------
sub count_rights_for_coll {
    my $self = shift;
    my $coll_id = shift;
    my $rights_attr = shift;

    my $coll_item_table = $self->get_coll_item_table_name;
    my $item_table = $self->get_item_table_name;
    my $statement = qq{SELECT COUNT($item_table.rights) FROM $item_table, $coll_item_table WHERE $coll_item_table.MColl_ID=? AND $item_table.rights=? AND $item_table.extern_item_id=$coll_item_table.extern_item_id};

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id, $rights_attr);
    my $countref = $sth->fetchall_arrayref([0]);
    my $count = $countref->[0]->[0] || 0;

    DEBUG('dbcoll', qq{count_rights_for_coll sql=$statement count="$count"});

    return $count;
}

# ---------------------------------------------------------------------

=item count_all_items_for_coll

Description

=cut

# ---------------------------------------------------------------------
sub count_all_items_for_coll {
    my $self = shift;
    my $coll_id = shift;

    my $coll_table = $self->get_coll_table_name;
    my $statement = qq{SELECT num_items from $coll_table WHERE MColl_ID=?};

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
    my $countref = $sth->fetchall_arrayref([0]);
    my $count = $countref->[0]->[0] || 0;

    DEBUG('dbcoll', qq{count_all_items_for_coll sql=$statement count="$count"});

    return $count;
}


# ---------------------------------------------------------------------

=item get_ids_for_coll

my $id_ary_ref = $co->get_ids_for_coll($coll_id);

=cut

# ---------------------------------------------------------------------
sub get_ids_for_coll {
    my $self = shift;
    my $coll_id = shift;
    my $format = shift;

    $format = ref($format) || 'ARRAY';
    my $results_ref;
    unless ( $results_ref = $$self{'_collection_ids',$coll_id,$format} ) {
        my $coll_item_table = $self->get_coll_item_table_name();
        my $statement = qq{SELECT a.extern_item_id, b.rights FROM $coll_item_table a JOIN mb_item b ON a.extern_item_id = b.extern_item_id WHERE a.MColl_ID = ? };

        DEBUG('dbcoll', qq{get_item_ids_for_coll sql=$statement});

        my $dbh = $self->get_dbh();
        my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
        my $ids_ary_of_ary_ref = $sth->fetchall_arrayref([0, 1]);

        if ( $format eq 'HASH' ) {
            $results_ref = { map { @$_ } @$ids_ary_of_ary_ref };
        } else {
            $results_ref = [ map {$_->[0]} @$ids_ary_of_ary_ref ];
        }
        $$self{'_collection_ids',$coll_id,$format} = $results_ref;
    }

    return $results_ref;
}


# ---------------------------------------------------------------------

=item get_metadata_for_item_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_metadata_for_item_ids {
    my $self = shift;
    my $id_arr_ref = shift;

    my $item_table = $self->get_item_table_name;

    my @metadata_fields = $self->get_item_display_fields_arr;
    push(@metadata_fields, 'rights');
    push(@metadata_fields, 'extern_item_id');
    push(@metadata_fields, 'sort_title');

    my $dbh = $self->get_dbh();

    my $id_string = $self->arr_ref2SQL_in_string($id_arr_ref);

    # qualify field names: "$item_table.fieldname" and join in comma
    # delimited string
    @metadata_fields = map { "$item_table." . $_ } @metadata_fields;
    my $fields = join (", ", @metadata_fields);

    my $SELECT = qq{SELECT } . $fields;
    my $WHERE = qq{ WHERE extern_item_id in $id_string};
    my $FROM = qq{ FROM $item_table };

    my $statement = $SELECT . $FROM  .  $WHERE;
    DEBUG('dbcoll', qq{get_metadata_for_item_ids sql=$statement});

    my $sth = DbUtils::prep_n_execute($dbh, $statement, @$id_arr_ref);
    my $ref_to_ary_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_ary_of_hashref;
}

# ---------------------------------------------------------------------

=item get_metadata_for_item

Description

=cut

# ---------------------------------------------------------------------
sub get_metadata_for_item {
    my $self = shift;
    my $id = shift;

    my $item_table = $self->get_item_table_name;

    my @metadata_fields = $self->get_item_display_fields_arr();
    push(@metadata_fields, 'rights');
    push(@metadata_fields, 'extern_item_id');
    push(@metadata_fields, 'sort_title');
    push(@metadata_fields, 'book_id');

    my $dbh = $self->get_dbh();
    # my $q_id = $dbh->quote($id);

    # qualify field names: "$item_table.fieldname" and join in comma
    # delimited string
    @metadata_fields = map { "$item_table." . $_ } @metadata_fields;
    my $fields = join (", ", @metadata_fields);

    my $SELECT = qq{SELECT } . $fields;
    my $WHERE = qq{ WHERE extern_item_id=?};
    my $FROM = qq{ FROM $item_table };

    my $statement = $SELECT . $FROM  .  $WHERE;
    DEBUG('dbcoll', qq{get_metadata_for_item sql=$statement});

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $id);
    my $ref_to_ary_of_hashref = $sth->fetchall_arrayref({});
    my $id_hashref = $ref_to_ary_of_hashref->[0];

    return $id_hashref;
}

# ---------------------------------------------------------------------

=item count_all_items_for_coll_from_coll_items

Description

=cut

# ---------------------------------------------------------------------
sub count_all_items_for_coll_from_coll_items {
    my $self = shift;
    my $coll_id = shift;

    my $coll_item_table_name = $self->get_coll_item_table_name;

    my $SELECT = qq{SELECT count(extern_item_id) } ;
    my $FROM = qq{FROM $coll_item_table_name};
    my $WHERE = qq{WHERE MColl_ID=?};

    my $statement = join (' ', qq{$SELECT $FROM $WHERE});

    my $dbh = $self->get_dbh();
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
    my $countref = $sth->fetchall_arrayref([0]);
    my $count = $countref->[0]->[0];

    DEBUG('dbcoll', qq{count_all_items_for_coll_from_coll_items sql=$statement count="$count"});

    return $count || 0;
}


# ---------------------------------------------------------------------

=item update_item_count

updates the collection table to match the actual counts of items in
the coll_items table

Tue Mar 22 12:20:57 2011: Made the update and test atomic so
batch_collection.pl can work in parallel

=cut

# ---------------------------------------------------------------------
sub update_item_count {
    my $self = shift;
    my $coll_id = shift;

    my ($statement, $sth);
    my $dbh = $self->get_dbh();

    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;

    my $coll_item_count;

    DbUtils::begin_work($dbh);
    eval {
        $coll_item_count = $self->count_all_items_for_coll_from_coll_items($coll_id);

        $statement = qq{UPDATE $coll_table SET num_items=? WHERE MColl_ID=?};
        $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_item_count, $coll_id);


        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with copy_items: $err});
    }

    my $collection_table_count = $self->count_all_items_for_coll($coll_id, 1);
    DEBUG('dbcoll', qq{DEBUG: update_item_count statement=$statement count="$collection_table_count"});
    ASSERT($coll_item_count == $collection_table_count, qq{update_item_count failed for $coll_id});
}

# ---------------------------------------------------------------------

=item  get_full_text_ids($result_id_arrayref, $rights_ref);

returns arrayref of ids that are full-text, given list(ref to array)
of ids and rights ref


=cut

# ---------------------------------------------------------------------
sub get_full_text_ids {
    my $self = shift;
    my $id_ary_ref = shift;
    my $rights_ref = shift;

    my $item_table = $self->get_item_table_name;
    my $dbh = $self->get_dbh();

    my $IN_clause = $self->arr_ref2SQL_in_string($id_ary_ref);
    my $WHERE = qq{ WHERE extern_item_id IN $IN_clause };

    # limit to items with rights attributes listed in $rights_ref
    my $AND = qq{ AND } . '( ';

    foreach my $rights (@{$rights_ref}) {
        $AND .= qq{ rights = ? OR };
    }
    # remove last "OR" and insert closing paren
    $AND =~ s,OR\s*$, \) ,;

    # append to WHERE
    $WHERE .= $AND;

    my $statement = qq{SELECT extern_item_id FROM $item_table $WHERE};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, @$id_ary_ref, @$rights_ref);
    my $ref_to_ary_of_ary_ref = $sth->fetchall_arrayref([0]);

    my $ids_ary_ref = [ map {$_->[0]} @$ref_to_ary_of_ary_ref ];

    return $ids_ary_ref;
}

# ---------------------------------------------------------------------

=item  get_item_id_slice

Return a slice of ID from mb_item


=cut

# ---------------------------------------------------------------------
sub get_item_id_slice {
    my $self = shift;
    my ($offset, $size) = @_;

    my $item_table = $self->get_item_table_name;
    my $dbh = $self->get_dbh();

    my $statement = qq{SELECT extern_item_id FROM $item_table LIMIT ?, ?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $offset, $size);
    my $ref_to_ary_of_ary_ref = $sth->fetchall_arrayref([0]);

    my $ids_ary_ref = [ map {$_->[0]} @$ref_to_ary_of_ary_ref ];

    return $ids_ary_ref;
}

# ---------------------------------------------------------------------

=item one_or_more_items_in_coll

returns true of one or more items in $item_id_ary_ref is in the collection
$co->one_or_more_items_in_coll($coll_id,$id_arr_ref)

=cut

# ---------------------------------------------------------------------
sub one_or_more_items_in_coll {
    my $self = shift;
    my $coll_id = shift;
    my $id_arr_ref = shift;

    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh = $self->get_dbh();

    my $IN_clause = $self->arr_ref2SQL_in_string($id_arr_ref);

    my $statement = qq{SELECT count(*) from $coll_item_table WHERE MColl_ID=? AND extern_item_id IN $IN_clause };
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id, @$id_arr_ref);
    my @ary = $sth->fetchrow_array;
    my $count = $ary[0];

    return ($count > 0);
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
Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-14 ©, The Regents of The University of Michigan, All Rights Reserved

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
