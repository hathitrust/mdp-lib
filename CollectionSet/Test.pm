#$Id: Test.pm,v 1.10 2008/05/21 20:17:53 pfarber Exp $#

package CollectionSet::Test;
use CollectionSet;
use Collection;
use DbUtils;


use base qw (Test::Class);
use Test::More;

#Move this to invoking program
my $DEBUG="true";
#$DEBUG=undef;

my $VERBOSE=undef;
$VERBOSE="true";
#====================================================================
# Tests
# New
#    list_coll tests
#    list_coll_slice
#    list_colls_arguments
#    list_colls_mycolls
#    list_colls_public
#    list_colls_sort
#    list_colls_temp   not implemented
#    add_coll
# delete_coll
# ASSERT_coll_not_owned_by_user_delete_coll
# exists_coll_name_for_owner not yet implemented
# get_coll_data_for_user
# change_owner
# delete_all_colls_for_user
#=====================================================================
# Actual tests


sub testNew:Test(2)
{
    my $self=shift;
    my $CS=$self->{CS};
    
    diag("testing constructor new") if $VERBOSE;
    
    my @methods=qw (new list_colls add_coll delete_coll);
    
    isa_ok($CS, CollectionSet);
    can_ok($CS,@methods);
    
}



#----------------------------------------------------------------------

sub list_coll_slice:Test(4)
{
    my $self=shift;
    my $CS=$self->{CS};

    my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @{$self->get_list_coll_arg_arrayref()};
    

    if ($DEBUG && $VERBOSE)
    {
        my $out=join(' ',@args);
        print "arguments to list_colls are: $out\n";
    }
    
     $slice_start = 1;
     $recs_per_slice = 2;

    diag("testing slice") if $VERBOSE;
    
     @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);
    if ($DEBUG && $VERBOSE)
    {
        my $out=join(' ',@args);
        print "arguments to list_colls are: $out\n";
    }
    
    
    my $colls_ref=$CS->list_colls (@args);
    
    
    like ($colls_ref->[0]->{collname},qr/Books/,'First collection name contains Books');
    cmp_ok  ( $#{$colls_ref} +1, '==', 2,"two records in slice" );

    $slice_start = $slice_start + 1;
    @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);
    $colls_ref=$CS->list_colls (@args);
    cmp_ok  ( $#{$colls_ref} +1, '==', 2,"two records in slice" );
    is ($colls_ref->[0]->{collname},'Favorites','First collection in 2nd slice is Favorites');
}
#----------------------------------------------------------------------
sub list_colls_arguments:Test(no_plan)
{
    #API list_colls(coll_type, [sortkey], [start_rec_num,num_records_per_slice])

    #This needs work.  Don't duplicate tests already done for specific use cases
    # need to determine behavior of Utils::ASSERT under ENV{DLPS_TESTING}
    #  die/warn/return from sub with message???
    # How much checking should CollectionSet do
    # i.e. should it check for slice start > slice size? bad types of sortkeys
    # or does the API for arguements to list_colls need improvement so mistakes are
    # harder to make and we don't need to check?

    my $self=shift;
    my $CS=$self->{CS};
    my $fields_array_ref = $CS->get_display_fields_arr_ref;
    diag("testing list_colls argument processing") if $VERBOSE ;
    #one argument with bad coll type
 #   my $colls_ref=$CS->list_colls('bad_type');
    #two arguments 
    my $sortkey="description";
  #   $colls_ref=$CS->list_colls('my_colls',$sortkey);
   # is ($colls_ref->[2]->{collname},'Favorites','Third collection name is Favorites');
    
    #2 args with bad second arg
     $sortkey=1;
  #  $colls_ref=$CS->list_colls('my_colls',$sortkey);
   # is ($colls_ref->[2]->{collname},'Favorites','bad sortkey');

    #3 arguments  see 
    
    #4 arguments
#WARNING uncommenting this test correctly causes list_colls to ASSERT and die/warn
# but we don't have a good way to handle testing that an assertion happened 
    my $start=1;
    my $slice_size=2;
   # $colls_ref=$CS->list_colls('my_colls',$start,$slice_size,"foobar");
    #is ($colls_ref->[2]->{collname},'Favorites','four argumentss');
}


sub list_colls_mycolls:Test(no_plan){
    my $self=shift;
    my $CS=$self->{CS};
    my $fields_array_ref = $CS->get_display_fields_arr_ref;
    
    diag("testing list_colls with default sort by collection name") if $VERBOSE ;

  my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @{$self->get_list_coll_arg_arrayref()};
      
    my @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);

    my $colls_ref=$CS->list_colls(@args);
    
    my $num_tests = 3 + (2 * scalar(@{$fields_array_ref}));
    $self->num_method_tests('list_colls_mycolls',"$num_tests");
   
    foreach my $field (@{$fields_array_ref})
    {
        ok( defined($colls_ref->[0]->{"$field"}),"$field is defined");
        isnt($colls_ref->[0]->{"$field"}, " ", "$field isn't blank");
    }
    
    like ($colls_ref->[0]->{collname},qr/Books/,'First collection name contains Books');
    is ($colls_ref->[1]->{collname},'Favorites','Second collection name is Favorites');
    like ($colls_ref->[2]->{collname}, qr/English/,'Third collection name contains English');    

}


sub list_colls_public:Test(2)
{
    my $self=shift;
    my $CS=$self->{CS};
    my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @{$self->get_list_coll_arg_arrayref()};
    $coll_type = 'pub_colls';
    my @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);
    my $colls_ref=$CS->list_colls(@args);

    diag( "this tests public_colls with default sort by collection name") if $VERBOSE;
    
    is ($colls_ref->[0]->{collname},'Automotive Engineering','First public collection name is Automotive  Engineering');
    is ($colls_ref->[1]->{collname},'Book Illustrations','Second collection name is Book Illustrations');

}

sub list_colls_sort:Test(3)
{
    my $self=shift;
    my $CS=$self->{CS};
   
   my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @{$self->get_list_coll_arg_arrayref()};
    $sortkey = 'description';
     my @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);

    my $colls_ref=$CS->list_colls(@args);
    diag("this tests my_colls collection sorted by description") if $VERBOSE;
    
    like ($colls_ref->[0]->{collname},qr/Books/,'First collection name contains Books');
    like ($colls_ref->[1]->{collname}, qr/English/,'Second collection name contains English'); 
    is ($colls_ref->[2]->{collname},'Favorites','Third collection name is Favorites');
}



sub list_colls_temp :Test(1)
{
    local $TODO = "foo";
    my $self=shift;
    my $CS=$self->{CS};

    
    my $msg= qq{list_colls_temp test not implemented yet. temp_coll no longer type, need username with SID};
    local $TODO=$msg;
    
    return (qq{$msg}); 
    
    diag("testing list_colls with type= temp_colls default sort by collection name") if $VERBOSE;

 my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @{$self->get_list_coll_arg_arrayref()};
    $coll_type='temp_colls';
    
    
    
my @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);

    my $colls_ref=$CS->list_colls(@args);
    like ($colls_ref->[0]->{collname},qr/Books/,'First collection name in temp_colls contains Books');
}

#-------------------------------------------------------------------------------------

sub add_coll :Test(3)
{
    diag("add_coll test") if $VERBOSE;
    
    my $self=shift;
    my $CS=$self->{CS};
    my $dbh=$self->{'dbh'};
    
    

    my $coll_hash_ref={};

     $coll_hash_ref->{'collname'} = "Add Test Record collection";    
     $coll_hash_ref->{'owner'} = "add_coll_test";    
     $coll_hash_ref->{'description'} = "Add Test Collection of Great Books";    
     $coll_hash_ref->{'shared'} = "0";    

    my $last_id=12; # why does thisdie? DbUtils::get_last_insert_id($dbh);
 #   my $last_id = DbUtils::get_last_insert_id($dbh); 
    my $new_coll_id = $CS->add_coll($coll_hash_ref);
    is ($new_coll_id,$last_id + 1, "new id should be $last_id +1" );
        
         #set CollectionSet uniquename member to owner so that list_colls(my_colls) will return rows for this owner
         $CS->{'user_id'} = $coll_hash_ref->{'owner'};
         my $owner=$coll_hash_ref->{'owner'};
     
    my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = @{$self->get_list_coll_arg_arrayref()};
   
    $coll_type = 'my_colls';
    my @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);
    my $colls_ref=$CS->list_colls(@args);

         is ($colls_ref->[0]->{collname},qq{Add Test Record collection},"First collection name in mycolls for $owner  is 'Add Test Record collection'");

         is (scalar(@{$colls_ref}),1,"should be one book");
     

         #how do we make sure we added one and only one row?
         #should teardown remove all entries added here?

         #add tests to make sure it asserts out if missing owner or collection name?

    
}
#---------------------------------------------------------------------------
sub delete_coll:Test(4)
{
    diag("delete_coll test") if $VERBOSE;
    
         my $self = shift;
         my $CS = $self->{CS};
         my $coll_id =  $self->{'added_testrecord_id'};
         my $owner = 'test_program';
         
         $CS->{'user_id'} = $owner;

         # should these be helper methods in CollectionSet.pm?
         my $count_before=0;
         my $count_after=0;

         #check to make sure item exists before deleting
         my $ID_exists=$CS->exists_coll_id($coll_id);
         ok ($ID_exists, "$coll_id is in database");
         
         $count_before=$self->_count_owned($CS,$owner);
         
         $CS->delete_coll($coll_id);
         
         $count_after = $self->_count_owned($CS,$owner);

         cmp_ok($count_after,'==', ($count_before-1),"before $count_before after $count_after ");
         $ID_exists=$CS->exists_coll_id($coll_id);
         ok (! $ID_exists, "$coll_id is not in database");
#need to add test to make sure coll_item table entries are also deleted!!
    my $coll_item_table = $CS->get_coll_item_table_name;
    

         
}

#---------------------------------------------------------------------------
sub ASSERT_coll_not_owned_by_user_delete_coll #:Test(1)
{
    diag("ASSERT coll_not_owned_by_user delete_coll test") if $VERBOSE;
    
    my $self = shift;
    my $CS = $self->{CS};
    my $coll_id =  $self->{'added_testrecord_id'};
    my $owner = 'no_owner';
         
    my $method_ref =  sub {$CS->delete_coll(@_)};
    my $arg_ref = [$coll_id];
    
    $self->ASSERT_test($method_ref,$arg_ref);
}

#---------------------------------------------------------------------------
# ---------------------------------------------------------------------
#   mysql> select collname, MColl_ID from mockupcoll4 where owner = 'tburtonw';
#+-----------------------+----------+
#    | collname              | MColl_ID |
#    +-----------------------+----------+
#    | Stuff for English 324 |        8 |
#    | Favorites             |        7 |
#    | Books & Stuff         |       11 |
#    +-----------------------+----------+
#    3 rows in set (0.00 sec)

#    mysql> select owner, collname, MColl_ID from mockupcoll4 order by owner;
#+---------+------------------------+----------+
#    | owner   | collname               | MColl_ID |
#    +---------+------------------------+----------+
#    | diabob  | Automotive Engineering |        9 |
#    | johnson | Book Illustrations     |       10 |
#    | tburtonw | Stuff for English 324  |        8 |
#    | tburtonw | Favorites              |        7 |
#    | tburtonw | Books & Stuff          |       11 |
#    +---------+------------------------+----------+




sub get_coll_data_from_user_id:Test(no_plan)
{
    my $self = shift;
    my $CS = $self->{CS};
    my $user_id='tburtonw';
    my $ary_hashref = $CS->get_coll_data_from_user_id($user_id);
    my $num_colls = $#{$ary_hashref} +1;
    is ($num_colls, 3,qq{number of collections for $user_id is 3});
        like ($ary_hashref->[0]->{collname},qr/Books/,qq{first collname is Books});
    like ($ary_hashref->[1]->{collname},qr/Favorites/,qq{second collname is Favorites});
    like ($ary_hashref->[2]->{collname},qr/Stuff for English/,qq{third collname is Stuff for English});

    is ($ary_hashref->[0]->{MColl_ID},11,qq{first coll id is 11});
    is ($ary_hashref->[1]->{MColl_ID},7,qq{ second coll id is 7});
    
    $user_id='diabob';
    $ary_hashref = $CS->get_coll_data_from_user_id($user_id);
    $num_colls = $#{$ary_hashref} +1;

    is ($num_colls, 1,qq{number of collections for $user_id is 1});
    like ($ary_hashref->[0]->{collname},qr/Automotive Engineering/,qq{first collname for user $user_id is Automotive Engineering});
    is ($ary_hashref->[0]->{MColl_ID},9,qq{first coll id for user $user_id is 9});
    
    #What happens if bad user id?
    $user_id=666;
    
    $ary_hashref = $CS->get_coll_data_from_user_id($user_id);
    is ($ary_hashref->[0]->{collname},undef,qq{first collname for non-existant user $user_id is undef});
}


# ---------------------------------------------------------------------

#---------------------------------------------------------------------------
sub change_owner  :Test(no_plan)
{
    diag("testing change_owner") if $VERBOSE;
    
    my $self = shift;
    my $CS = $self->{CS};
    my $dbh = $CS->{'dbh'};
    my $coll_table_name = $CS->{'coll_table_name'};
    my $user_id = 'tburtonw';
    my $fake_session_id ='cb2b1fbae2265d12dbec7240c9f0c1f0';

    my $co= Collection->new($dbh,$self->{config},$user_id) ;
    
    # do we need to modify the $CS member data? doe it have a user id?

    # create two collections    
    my $meta_ref={
                  'collname' => "testtemp1",
                  'owner' => "$fake_session_id",
                  'shared' => "1",
                  'description' => "test temp colleciton1",
                 };    

    my $coll1_id=$CS->add_coll($meta_ref);
    #coll2
    my $meta_ref2={};
    $meta_ref2->{'owner'} = "$fake_session_id";   
    $meta_ref2->{'collname'} = "temp2";   
    $meta_ref->{'description'} = "temp2 collection";   
    $meta_ref->{'shared'} = "0";   
    my $coll2_id = $CS->add_coll($meta_ref2);

    my $coll1_owner = $co->get_coll_owner($coll1_id);
    my $coll2_owner = $co->get_coll_owner($coll2_id);

    is ($coll1_owner,$fake_session_id,qq{Before change_owners: collection $coll1_id owned by $fake_session_id} );
    is ($coll2_owner,$fake_session_id,qq{Before change_owners: collection $coll2_id owned by $fake_session_id} );

    # get list of coll_ids owned by owner=session_id and stick in %before
    my $temp_colls_ref = $CS->get_coll_data_from_user_id($fake_session_id);

    if ($DEBUG)
    {
        is ($temp_colls_ref->[1]->{'collname'},$meta_ref->{'collname'},qq{collname for $fake_session_id 1 is $meta_ref->{'collname'}});
        is ($temp_colls_ref->[0]->{'collname'},$meta_ref2->{'collname'},qq{collname for $fake_session_id 2 is $meta_ref2->{'collname'}});    
    }
    
    my $existing_colls_ref = $CS->get_coll_data_from_user_id($user_id);
    my %existing=();
    foreach my $ref (@{$existing_colls_ref})
    {
        my $id=$ref->{'MColl_ID'};
        $existing{$id}=1;
    }
    


    # EXECUTE
      $CS->change_owner($fake_session_id,$user_id);

    #VERIFY
    # get list of coll_ids owned by owner = user_id
    my $after_colls_ref = $CS->get_coll_data_from_user_id($user_id);
    # check that both colls are now owned by new owner
    my $after_coll1_owner = $co->get_coll_owner($coll1_id);
    my $after_coll2_owner = $co->get_coll_owner($coll2_id);
                                        
    is ($after_coll1_owner,$user_id,qq{after change_owners collection $coll1_id owned by $user_id} );
    is ($after_coll1_owner,$user_id,qq{after_change_owners collection $coll2_id owned by $user_id} );

    my $after_colls_ref = $CS->get_coll_data_from_user_id($user_id);
    my %after=();
    foreach my $after_ref (@{$after_colls_ref})
    {
        my $id=$after_ref->{'MColl_ID'};
        $after{$id}=1;
    }

    if ($DEBUG)
    {
        diag("checking all collections owned by $user_id");
        foreach my $ref (@{$temp_colls_ref})
        {
            my $id = $ref->{'MColl_ID'};
            is ($after{$id},1,qq{$id is now owned by $user_id});
        }
    
        foreach my $before_ref (@{$existing_colls_ref})
        {
            my $id = $before_ref->{'MColl_ID'};
            is ($after{$id},1,qq{$id is still owned by $user_id});
        }
    }
    
    
}

#---------------------------------------------------------------------------

sub delete_all_colls_for_user: Test(no_plan)
{
    diag("delete_all_colls_for_user") if $VERBOSE;
    
    my $self = shift;
    my $CS = $self->{CS};
    my $dbh = $CS->{'dbh'};
    
    my $coll_table = $CS->{'coll_table_name'};
    my $coll_item = $CS->get_coll_item_table_name;
    my $user_id = 'tburtonw';
    #XXX $co object should be created in test fixture
    my $co= Collection->new($dbh,$self->{config},$user_id) ;

    #SETUP

    #    mysql> select MColl_ID from test_collection where owner ='tburtonw';
    #    +----------+
    #    | MColl_ID |
    #    +----------+
    #    |        8 |
    #    |        7 |
    #    |       11 |
    #    +----------+
    #    mysql> select test_coll_item.MColl_ID,test_coll_item.item_id from test_coll_item,test_collection 
    #    where test_coll_item.MColl_ID = test_collection.MColl_ID and test_collection.owner='tburtonw';
    #    +----------+---------+
    #    | MColl_ID | item_id |
    #    +----------+---------+
    #    |        8 |       3 |
    #    |        7 |       3 |
    #    |       11 |       3 |
    #    |       11 |       4 |
    #    |       11 |       5 |
    #    |       11 |       6 |
    #    +----------+---------+
    my @Before_coll_ids=(7,8,11);
    my @Before_item_ids=(3,4,5,6);

    
#    my $statement =qq{select MColl_ID from test_collection where owner ='tburtonw'\;};
    

##my    $statement = qq{SELECT $coll_item.MColl_ID, $coll_item.item_id from $coll_item,$coll_table};
#    $statement .= qq{  WHERE $coll_item.MColl_ID = $coll_table.MColl_ID};
#    $statement .= qq{ and $coll_table.owner = $user_id };
    
#    $statement .= qq{ order by MColl_ID\; };
    
 #   print "debug: statement = $statement\n";
    

  #  my $sth = DbUtils::prep_n_execute( $dbh, $statement );
  #my $ary_of_ary_ref = $sth->fetchall_arrayref([0]);
   # foreach my $ary_ref(@{$ary_of_ary_ref})
    #{
     #   print "foo: $ary_ref->[0]\n";
    #}
    
    #my $arr_ref=$sth->fetchall_arrayref({});
    #print "\n debug before \n\n";
    #$sth->dump_results;
    
   # print "foo";
    
    #foreach my $hashref (@{$arr_ref})
#    {
#        print "$hashref->{'MColl_ID'} : $hashref->{item_id}\n";
#        print "bar";
        
        
#    }
    #print "\n\n";
    #exit;
    

    
    my $coll_id=11;
    my $item_id =3;
    print "getting collnames for $item_id $user_id\n";
    my $aryref=$co->get_collnames_for_item_and_user($item_id,$user_id);
    foreach my $collname (@{$aryref})
    {
        print "$item_id $user_id $collname\n";
    }
                          

    
      ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});
    $item_id=4;
    
   ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});
    $item_id=5;
    
       ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});
$item_id=6;    
   ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});

    $coll_id=8;
    $item_id=3;
    
 ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});
    $coll_id=7;
    $item_id=3;
    
       ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});

    foreach my $coll (@Before_coll_ids)
    {
        ok($CS->exists_coll_id($coll),qq{Collection $coll does not exist});
    }


    #EXECUTE
    $CS->delete_all_colls_for_user($user_id);
    #VERIFY
    diag("\nafter\n");
    
    $coll_id=11;
    $item_id =3;
      ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});
    $item_id=4;
    
   ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});
    $item_id=5;
    
       ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});
$item_id=6;    
   ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});

    $coll_id=8;
    $item_id=3;
    
 ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});
    $coll_id=7;
    $item_id=3;
    
       ok (!$co->item_in_collection($item_id,$coll_id),qq{Item $item_id not in collection $coll_id});

    foreach my $coll (@Before_coll_ids)
    {
        ok(!$CS->exists_coll_id($coll),qq{Collection $coll does not exist});
    }
}
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
#  Utilities
#---------------------------------------------------------------------------
# helper for testing add and deleting
sub _count_owned
{
    my $self = shift;
    my $CS = shift;
    my $owner = shift;
    
    my $dbh = $CS->{'dbh'};
    my $coll_table_name = $CS->{'coll_table_name'};
    my $statement = qq{SELECT count(*) FROM $coll_table_name WHERE owner = };
    $statement .= "\'" . $owner . "\' \;";
    
    my $sth = DbUtils::prep_n_execute( $dbh, $statement );
    my @ary = $sth->fetchrow_array;
    my $count = $ary[0];
    return $count;
}

#---------------------------------------------------------------------------


sub _get_dbh
{

    my $db_host = 'dev.mysql';
    my $db_name = 'dlxs';
    my $dbSourceName = join(':', 'DBI:mysql', $db_name,  $db_host);
    my $dbUser = "dlxsadm";
    my $dbPassword = 'a!!pri^';

   # my $dbUser = "dlxs";
   # my $dbPassword = 'getyer0wn';

    my $dbh;
    eval
    {
        $dbh = DbUtils::Connect_DBI(
                                     $dbSourceName,
                                     $dbUser,
                                     $dbPassword,
                                    );
    };
    Utils::ASSERT( ( ! $@ ), qq {Database connect error: $@} );
    return ($dbh);
}

#=====================================================================
# Setup and Teardown 
#  these methods excuted before and after each test
#=====================================================================
sub A_create_test_tables:Test(setup=>no_plan)
{
    my $self = shift;
    $self->do_create_test_tables();
}

sub do_create_test_tables{
    my $self = shift;
    my $config = $self->{'config'};
    my $db_dev_server   = $config->get('db_dev_server' );
    my $db_name   = $config->get('db_name');
    my $db_user   = $config->get('db_user');
    my $db_passwd   = $config->get('db_passwd');
    
    my $create_SQL = '../Collection/make_test_tables.sql';
    
    $command = qq{mysql -h $db_dev_server -u $db_user  $db_name -p$db_passwd} . ' < ' .  $create_SQL;

    print "load command is $command\n";

    system $command;

    #XXX there should be a test to confirm these were set up correctly if debug is set on
#   XXX This needs work.  Redo the tests based on new table and data
   if ($DEBUG)
   {
        diag(" testing    creation of test database table $table_name")  if $VERBOSE;
        $self->num_method_tests('A_create_test_tables','6');
        $self->_testStartupDb;
    }
}



sub B_get_CS:Test(setup=>no_plan)
{
    diag("setting up CS Collection Set") if $DEBUG;
    my $self = shift;
    my $dbh=_get_dbh;
    my $user_id='tburtonw';

    my $CS= CollectionSet->new($dbh,$self->{config},$user_id) ;

    $self->{CS}=$CS;
  if ($DEBUG)
    {
        $self->num_method_tests('B_get_CS','2');
        test_get_CS($self->{CS});
        
    }

    
}

sub test_get_CS
{
  #  my $self=shift;
    my $CS=shift;
    
    isa_ok($CS, CollectionSet,"CollectionSet is set up");
    is($CS->get_coll_table_name,'test_collection',"for testing coll table should be test_collection");
    
}

#----------------------------------------------------------------------
sub C_add_test_record:Test(setup=>no_plan)
{
    
    
    diag("adding test recordCollection Set") if $DEBUG;
    my $self = shift;
    my $CS=$self->{CS};

    my $coll_table_name = $CS->get_coll_table_name;
    my $dbh = $CS->{'dbh'};

    my $coll_hash_ref={};
   
     $coll_hash_ref->{'collname'} = "My test collection";    
     $coll_hash_ref->{'owner'} = "test_program";    
     $coll_hash_ref->{'description'} = "Description of test collection";    
     $coll_hash_ref->{'shared'} = "0";    
     $coll_hash_ref->{'MColl_id'} = "NULL";    


    DbUtils::insert_new_row($dbh, $coll_table_name, $coll_hash_ref);
    my $new_record_id = DbUtils::get_last_insert_id($dbh); 
    $self->{'added_testrecord_id'} = $new_record_id;
    
  if ($DEBUG)
    {
        $self->num_method_tests('C_add_test_record','1');
        test_add_test_record($self->{CS},$new_record_id);
    }


}

sub test_add_test_record
{
    my $CS = shift;
    my $coll_id = shift;
    
    my $ID_exists = $CS->exists_coll_id($coll_id);
    ok ($ID_exists, "coll_id $coll_id is in database");
}


#========================================================================
# STARTUP and TEARDOWN (SHUTDOWN)
#========================================================================

sub A_get_config:Test(startup=>no_plan)
{
    my $self=shift;
    
    
    my $config = new MdpConfig($ENV{'SDRROOT'} . '/cgi/m/mdp/MBooks/Config/global.conf');
    $self->{'config'} = $config;

    #set this to tell program to use test tables lines below are so test program and SUT will both use the env variable to choose which table names to read
    $ENV{'DEBUG'}='usetesttbl';

    if ( $ENV{'DEBUG'} eq 'usetesttbl' )
    {
        $self->{'coll_table_name'} = $config->get('test_coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('test_coll_item_table_name');
        $self->{'item_table_name'} = $config->get('test_item_table_name');
      }
    else {
        
        $self->{'coll_table_name'} = $config->get('coll_table_name');
        $self->{'coll_item_table_name'} = $config->get('coll_item_table_name');
        $self->{'item_table_name'} = $config->get('item_table_name');
    }
      
    if ($DEBUG)
    {
        diag("testing config ")if $VERBOSE;
        isa_ok($self->{'config'}, MdpConfig, "config object okay");
        isa_ok($self->get_config(), MdpConfig, "get_config method");
        is ($self->get_coll_table_name(), 'test_collection',"collection table in config object is test_collection");
    }
}




sub A_create_test_db:Test(shutdown=>no_plan)
{
    my $self = shift;
    $self->do_create_test_tables();
}




#----------------------------------------------------------------------
#   XXX This needs work.  Redo the tests based on new table and data
sub _testStartupDb{
    my $self=shift;
    my $CS=$self->{CS};
    my $dbh=$CS->{'dbh'};
    my $table_name = $self->get_coll_table_name();
    
        my $sort_key = 'collname';
        
        my $statement = 'SELECT * FROM ';
        $statement .= " $table_name ";
        $statement .= 'ORDER BY ';
        $statement .= "$sort_key \;";        

        
#    $statement="select * from $table_name";
    diag("coll table name is $table_name\n statment is $statement\n");
    
        
        my $sth = DbUtils::prep_n_execute($dbh, $statement);
        my $array_ref = $sth->fetchall_arrayref({});
        
         is (scalar(@{$array_ref}), 5,"five records in sample database");   
         is ($array_ref->[0]->{'collname'}, 'Automotive Engineering',"First record sample db Auto engineering");
        like ($array_ref->[1]->{collname},qr/Book Illustrations/,'Second collection name contains Book Illustrations');
        like ($array_ref->[2]->{collname}, qr/Books and Stuff/,'Third collection name contains Books and Stuff'); 
        is ($array_ref->[3]->{collname},'Favorites','fourth collection name is Favorites');   
        like ($array_ref->[4]->{collname},qr/Stuff for English/,'fifth collection name contains Stuff for English');   
    

}

#----------------------------------------------------------------------

sub C_set_list_colls_defaults:Test(startup=>no_plan)
{
    
    my $self=shift;
    my ($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice) = undef;
    $coll_type = 'my_colls';
    $sortkey = 'collname';
    $direction="a";
    my @args=($coll_type, $sortkey, $direction, $slice_start, $recs_per_slice);

    if ($DEBUG && $VERBOSE)
    {
       
        my @args_out=();
        foreach my $arg (@args)
        {
            if (! defined ($arg))
            {
                $arg="undef";
            }
            push @args_out, $arg;
        }
        
        my $out=join(' ',@args_out);
        print "\n---\narguments to list_colls are: $out\n--\n";
    }
    $self->{'list_colls_args'}=\@args;

    if ($DEBUG)
    {
        diag(" set list_colls defaults")  if $VERBOSE;
        my $num = scalar(@args);
        $self->num_method_tests('C_set_list_colls_defaults',6);
        $self->_test_set_list_colls_defaults(@args);   
    }
}


#----------------------------------------------------------------------
sub _test_set_list_colls_defaults{

    my $self = shift;
    my @args = @_;
    
    my $test_args_ref = $self->get_list_coll_arg_arrayref();
    for $i (0..$#args)
    {
        is ($test_args_ref->[$i],$args[$i],"arg $i is equal to $test_args_ref->[$i]");
    }
    
}



#----------------------------------------------------------------------
# utility routines
#----------------------------------------------------------------------
sub get_config
{
    my $self=shift;
    return $self->{'config'};
}

sub get_coll_table_name
{
    my $self = shift;
    return $self->{coll_table_name};
}
sub get_dbh
{
    my $self=shift;
    return $self->{'dbh'};
    
}

#----------------------------------------------------------------------

sub get_list_coll_arg_arrayref
{
    my $self = shift;
    return $self->{'list_colls_args'};
}

sub ASSERT_test
{
    my $self = shift;
    my $method_ref = shift;
    my $arg_ref = shift;
    my $caller = (caller(1))[3];

    $caller =~ s/Collection::Test::ASSERT_//;
    

    eval 
    {
        $method_ref->(@{$arg_ref});
     };
    my $err_msg=$@;
    my $output_err_msg = "$err_msg\n" if $VERBOSE_ASSERTS;
     
    like ($err_msg,qr/ASSERT_FAIL/,qq{assertion triggered for $caller\n $output_err_msg});

}


#----------------------------------------------------------------------


1;
