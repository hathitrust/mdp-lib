package CollectionUser;
use overload '""' => 'get_user_name';

sub new
{
    my $class = shift;
    my ( $user ) = @_;
    if ( ref($user) eq 'Auth::Auth' ) { return $user; }
    if ( ref($user) eq $class ) { return $user; }
    my $self = {};
    bless $self, $class;
    $$self{user_id} = $user;
    return $self;
}

sub get_user_names {
    my $self = shift;
    return ( $$self{user_id} );
}

sub get_user_name {
    my $self = shift;
    return $$self{user_id};
}

package CollectionSet;
use Collection;


=head1 NAME

CollectionSet

=head1 DESCRIPTION

This class encapsulates database queries that provide sorted lists of
collection metadata.  Currently there are three sets returned:
my_colls= collections owned by user $username pub_colls= all public
collections temp_colls collections associated with $SID (session)


=head1 VERSION

$Id: CollectionSet.pm,v 1.43 2010/03/29 16:39:00 tburtonw Exp $

=head1 SYNOPSIS

my $cs = CollectionSet->new($sid,$uniqname)

my $colls_ref = $CS->list_colls( coll_type, [sortkey],[start_rec_num, num_records_per_page]);
record number counting starts at 1

my $colls_ref=list_colls(mycolls);

$colls_ref is reference to array of hashes where keys are database field names
and values are the values for that row


foreach my $coll (@{$colls})
{
    my $collname=$coll->{'collname'};
    my $description=$coll->{ 'description'}
}


     $coll_hash_ref->{'collname'} = "My new collection";
     $coll_hash_ref->{'owner'} = "tburtonw";
     $coll_hash_ref->{'description'} = "Great Collection of Great Books";
     $coll_hash_ref->{'shared'} = "1";
     my $status = $CS->add_coll($coll_hash_ref);



=head1 TODO:

=over 4

=item need to index sort fields in MySQL to make limit work efficiently!

=item check various paging CPAN modules for ideas later

=item replace statements with bind parameters

=item check out SQL::Abstrac

=back

=head1 METHODS

=over 8

=cut

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
use MdpConfig;
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

    my $use_test_tables = DEBUG('usetesttbl') || $config->get('use_test_tables');
    
    if ($use_test_tables) {
        $self->{'coll_table_name'} = $config->get('test_coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('test_coll_item_table_name');
    }
    else {
        $self->{'coll_table_name'} = $config->get('coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('coll_item_table_name');
    }

    my @display_fields = $config->get('coll_table_display_field_names');
    $self->{'display_fields_arr_ref'} = \@display_fields;
    $self->{'config'} = $config;

}


#----------------------------------------------------------------------
sub get_user_id
{
    my $self=shift;
    return $self->{'user_id'};
}

sub get_user {
    my $self = shift;
    return $self->{'user_id'}; # ->get_user_names;
}

#----------------------------------------------------------------------
sub get_coll_table_name
{
    my $self = shift;
    return $self->{coll_table_name};
}
#----------------------------------------------------------------------
sub get_coll_item_table_name
{
    my $self = shift;
    return $self->{coll_item_table_name};
}

#----------------------------------------------------------------------
sub get_display_fields_arr_ref
{
    my $self=shift;
    return $self->{'display_fields_arr_ref'};
}

#----------------------------------------------------------------------

=item add_coll(coll_id,$coll_hash_ref)


$coll_hash_ref contains database fieldnames->values

WARNING!!  if caller tries to create a new collection with a duplicate
collection name it will trigger an assertion error
i.e. owner/coll_name must be unique Client application is responsible
for preventing assertion by calling exists_coll_name_for_owner()

=cut

#----------------------------------------------------------------------
sub add_coll
{
    my $self = shift;
    my $coll_hash_ref = shift;

    my $status = "";
    my $coll_table_name = $self->get_coll_table_name;
    my $coll_item_table_name = $self->get_coll_item_table_name;

    my $dbh = $self->{'dbh'};

    my $coll_name = $coll_hash_ref->{'collname'};
    my $owner_name = $coll_hash_ref->{'owner_name'};
    my $shared = $coll_hash_ref->{'shared'};
    my $description = $coll_hash_ref->{'description'};

    my $user = CollectionUser->new($coll_hash_ref->{'owner'});


    ASSERT(($shared == 0 || $shared == 1 || $shared == -1), qq{shared must be 0 or 1. It is $shared});
    ASSERT(($coll_name ne "" && defined($coll_name)),
           qq{CollectionSet::add_coll must have Collection name});

    # ASSERT(($owner ne "" && defined($owner)),
    #        qq{CollectionSet::add_coll must have owner identifier});

    ASSERT(($user ne "" && defined($user)),
           qq{CollectionSet::add_coll must have owner identifier});

    ASSERT(($owner_name ne "" && defined($owner_name)),
           qq{CollectionSet::add_coll must have owner_name for display});

    ASSERT(! $self->exists_coll_name_for_owner($coll_name, $user),
           qq{CollectionSet::add_coll Collection name $coll_name for $user is already in table $coll_table_name});

    if (length($coll_name) > 50) {
        $coll_name = substr($coll_name, 0, 50);
    }
    if (length($description) > 150) {
        $description = substr($description, 0, 150);
    }

    # find the right owner to use
    my $owner; my $count;
    foreach my $user_id ( $user->get_user_names ) {
        ( $count ) = $dbh->selectrow_array(qq{SELECT COUNT(owner) FROM $coll_table_name WHERE owner = ?}, undef, $user_id);
        print STDERR "AHOY CHECKING $user_id : $count\n";
        if ( $count > 0 ) {
            $owner = $user_id;
            last;
        }
    }
    $$coll_hash_ref{owner} = $owner;

    my $MColl_ID;
    DbUtils::begin_work($dbh);

    eval {

        ## ------------------------------------------------------------------

        $MColl_ID = DbUtils::generate_unique_id($dbh, $coll_table_name, 'MColl_ID');
        $$coll_hash_ref{'MColl_ID'} = $MColl_ID;
        DbUtils::insert_new_row($dbh, $coll_table_name, $coll_hash_ref);

        DbUtils::commit($dbh);

    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with add_coll: $err});
    }

    return $MColl_ID;
}


# ---------------------------------------------------------------------

=item change_owner

usage:  $CS->chang_owner($old_owner,$new_owner)
 WARNING! Caller is responsible for checking that this action should be allowed i.e.
for saving temporary collections, that the current session is the same as the old owner.

=cut

# ---------------------------------------------------------------------
sub change_owner
{
    my $self = shift;
    my $old_user_id = shift;
    my $new_user_id = shift;
    my $user_display_name = shift;
    
    my $coll_table = $self->get_coll_table_name;
    my $dbh = $self->{'dbh'};
    
    DbUtils::begin_work($dbh);
    eval {
        my $statement = qq{UPDATE $coll_table SET owner=?, owner_name=? WHERE owner=?};
        my $sth = DbUtils::prep_n_execute($dbh, $statement, $new_user_id, $user_display_name, $old_user_id);
        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with change_owner: $err});
    }
}

# ---------------------------------------------------------------------

=item get_coll_data_from_user_id

my $ary_hashref = $CS->get_coll_data_from_user_id($user_id); returns
reference to an array of hashrefs with the keys being MColl_ID and
collname returns undef if bad user_id

=cut

# ---------------------------------------------------------------------
sub get_coll_data_from_user_id
{
    my $self = shift;
    my $user = CollectionUser->new(shift);

    my $coll_table = $self->get_coll_table_name;
    my $dbh = $self->{'dbh'};

    my @owner_names = $user->get_user_names;
    my $owner_expr = join(',', map { '?' } @owner_names);

    my $statement = qq{SELECT collname, MColl_ID, num_items FROM $coll_table WHERE owner IN ($owner_expr) ORDER BY collname};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, @owner_names);
    my $coll_data_ref = $sth->fetchall_arrayref({});

    # array of hashrefs
    return $coll_data_ref;
}



# ---------------------------------------------------------------------

=item exists_coll_name_for_owner

Description

=cut

# ---------------------------------------------------------------------
sub exists_coll_name_for_owner
{
    my $self = shift;
    my $coll_name = shift;
    my $user = CollectionUser->new(shift);

    my ( $owner_names, $owner_expr ) = $self->_get_owner_expr($user);

    my $coll_table_name = $self->get_coll_table_name;
    my $coll_item_table_name = $self->get_coll_item_table_name;
    my $dbh = $self->{'dbh'};

    # my $quoted_coll_name = DbUtils::quote($dbh, $coll_name);

    my $statement = qq{SELECT count(*) FROM $coll_table_name WHERE collname=?};
    $statement .= qq{ AND owner IN ($owner_expr)};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_name, @$owner_names);
    my $result = scalar($sth->fetchrow_array);
    # check for case changes
    if ($result > 0)
    {
        # get collname and compare
        $statement = qq{SELECT collname FROM $coll_table_name WHERE collname=?};
        $statement .= qq{ AND owner IN ($owner_expr)};
        $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_name, @$owner_names);
        my $name_in_db=$sth->fetchrow_array;
        return ($coll_name eq $name_in_db);
        
    }
    else
    {
        return ($result > 0);
    }
    
}



# ---------------------------------------------------------------------

=item exists_coll_id

Description

=cut

# ---------------------------------------------------------------------
sub exists_coll_id
{
    my $self = shift;
    my $coll_id = shift;

    my $coll_table_name = $self->get_coll_table_name;
    my $dbh = $self->{'dbh'};

    my $statement = qq{SELECT count(*) FROM $coll_table_name WHERE MColl_id=?};

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);
    my $result = scalar($sth->fetchrow_array);

    return ($result > 0);
}

#----------------------------------------------------------------------

=item delete_all_colls_for_user

deletes all collections in collection table and all items in coll_item table 
owned by provided $user_id

delete_all_colls_for_user($user_id)

=cut

#----------------------------------------------------------------------
sub delete_all_colls_for_user
{
    my $self = shift;
    my $user = CollectionUser->new(shift);
    my $dbh = $self->{'dbh'};
    my $coll_table = $self->get_coll_table_name;
    my $coll_item_table = $self->get_coll_item_table_name;
    
    my ($statement, $sth);

    my ( $owner_names, $owner_expr ) = $self->_get_owner_expr($user);

    DbUtils::begin_work($dbh);
    eval {
        #  delete from coll_item table
        $statement  = qq{ DELETE $coll_item_table };
        $statement .= qq{from $coll_item_table,$coll_table};
        $statement .= qq{  WHERE $coll_item_table.MColl_ID = $coll_table.MColl_ID};
        $statement .= qq{ and $coll_table.owner IN ($owner_expr) };

        $sth = DbUtils::prep_n_execute($dbh, $statement, @$owner_names);

        # XXX check for errors ?
        $statement = qq{DELETE from $coll_table WHERE owner IN ($owner_expr)\;};
        $sth = DbUtils::prep_n_execute($dbh, $statement, @$owner_names);
        # XXX check for errors ?

        DbUtils::commit($dbh);
    };
    if ( my $err = $@ ) {
        eval { $dbh->rollback; };
        ASSERT(0, qq{Problem with delete_all_colls_for_user: $err});
    }
   

}



#----------------------------------------------------------------------

=item list_colls(coll_type, sortkey, direction, slice_start, recs_per_slice);

record number counting starts at 1.  coll_type is currently one of
(pub_colls|my_colls|temp_colls) returns reference to array of hashrefs
where keys are database field names and values are the values for that
row if optional slice arguments (start_rec_num, num_records_per_slice)
are supplied it only returns the first num_records_per_slice starting
with start_rec_num.  Otherwise it returns all matching rows.

=cut

# ---------------------------------------------------------------------
sub list_colls
{
    my $self = shift;
    my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @_;

    my $coll_table_name = $self->get_coll_table_name;
    my $display_fields_array_ref = $self->get_display_fields_arr_ref;

    ASSERT($sortkey, qq{});
    ASSERT($direction, qq{});
    # undef $slice_start and for $recs_per_slice implies no LIMIT clause below

    DEBUG('dbcoll',
          qq{slice start="$slice_start" at records="$recs_per_slice" per slice});

    my $fields = join ("\, ", @{$display_fields_array_ref});
    my $statement = '';

    my $SELECT = qq{SELECT } . $fields;
    my $FROM = qq{FROM $coll_table_name};
    my ($WHERE, @params) = $self->_get_where($coll_type);

    if ($direction eq 'a')
    {
        $direction = 'ASC';
    }
    else
    {
        $direction = 'DESC';
    }

    my $ORDER =  qq{ORDER BY $sortkey $direction};
    my $offset = $slice_start -1; # MySQL limit counts records from 0
    my $LIMIT = qq{};
    if ($offset >= 0)
    {
        $LIMIT = qq{LIMIT $offset, $recs_per_slice};
    }

    $statement = qq{$SELECT $FROM $WHERE $ORDER $LIMIT;};

    DEBUG('dbcoll', qq{sql statement="$statement"});

    my $dbh = $self->{'dbh'};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, @params);
    my $array_ref = $sth->fetchall_arrayref({});

    $sth->finish;

    return $array_ref;
}

# ---------------------------------------------------------------------

=item _get_where

Description

=cut

# ---------------------------------------------------------------------
sub _get_where
{
    my $self = shift;
    my $coll_type = shift;
    my $where = "WHERE ";
    # my $user_id = $self->get_user_id;
    my $user = $self->get_user;
    my @params;

    my ( $owner_names, $owner_expr ) = $self->_get_owner_expr($user);

    ASSERT(($coll_type eq 'my_colls') || ( $coll_type eq 'my-collections') || ($coll_type eq 'pub_colls') || ($coll_type eq 'all_colls') || ($coll_type eq 'featured_colls'),
           qq{CollectionSet::list_colls(coll_type) is $coll_type.  Should be my_colls or pub_colls});


    if ($coll_type eq "pub_colls")
    {
        $where .= qq{shared = 1};
    }
    elsif ($coll_type eq "all_colls")
    {
        # $where .= qq{(shared = 1 AND num_items > 0) OR (owner = ?)};
        # push @params, $user_id;
        push @params, @$owner_names;
        $where .= qq{( shared = 1 AND num_items > 0 ) OR ( owner IN ($owner_expr) )};
    }
    elsif ($coll_type eq "featured_colls")
    {
        $where .= qq{(shared = 1 AND num_items > 0 AND (featured IS NOT NULL OR featured != ''))};
    }
    else
    {
        $where .= qq{owner IN ($owner_expr)};
        push @params, @$owner_names;
    }

    return ($where, @params);
}

sub _get_owner_expr
{
    my $self = shift;
    my ( $user ) = @_;

    my @owner_names = $user->get_user_names;
    my $owner_expr = join(',', map { '?' } @owner_names);

    return ( \@owner_names, $owner_expr );
}


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
