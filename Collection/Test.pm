#$Id: Test.pm,v 1.28 2008/05/21 20:17:53 pfarber Exp $#
package Collection::Test;

BEGIN
{
    unshift( @INC, $ENV{'SDRROOT'} . '/lib' );
}


use Collection;
use CollectionSet;
use Search::Constants;  # for index status constants

use base qw (Test::Class);
use Test::More;

#Move this to invoking program
my $DEBUG="true";
$DEBUG=undef;

my $VERBOSE=undef;
$VERBOSE="true";

my $VERBOSE_ASSERTS=undef;
#$VERBOSE_ASSERTS="true";

#====================================================================
#   new              x 
#   copy_items        x
#   delete_items    x
#    delete_one_item x
#    delete_several_items x
#   list_items       x
#     sort           x
#     slice          x   
#     limit to fulltext  
#     with id list
#   edit_status      x
#   edit_description x
#   edit_coll_name   x
#   create_or_update_item_metadata x
#   _get_item_id_from_extern_id x
#   coll_owned_by_user
#   item_exists x
#  item_in_collection x
#  item_in_a_collection
#  get_collections_for_item
#  get_coll_name
# CS->delete_all_colls_for_use
#  set_item_indexed
#  get_unindexed_item_ids 
#  get all_item_ids
# get_metadata_for_item_ids
# set_items_index_status
# get_item_index_status
#=====================================================================
# Actual tests
#---------------------------------------------------------------------

sub testNew:Test(2)
{
    my $self=shift;
    my $co=$self->{co};
    
    diag("testing constructor new") if $VERBOSE;
    
    my @methods=qw (new );
    
    isa_ok($co, Collection);
    can_ok($co,@methods);
    
}



#----------------------------------------------------------------------
sub copy_items :Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    my $coll_items_table = $co->get_coll_item_table_name();
    my $coll_table = $co->get_coll_table_name();    

    diag("testing copy_items") if $VERBOSE;
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
    
    $coll_id = 11;
    
    my $item_id_ref = [1,7];
    foreach my $item_id (@{$item_id_ref})
    {
        ok (! $self->item_in_collection($item_id,$coll_id),qq{before copy_items called: item $item_id is not in collection $coll_id});

    }
    
    #verify number of items in collections table entry
   my  $count_from_coll_items_table = $co->count_all_items_for_coll_from_coll_items($coll_id);
    my $count_from_coll_table = $co->count_all_items_for_coll($coll_id);
    is ($count_from_coll_items_table,$count_from_coll_table,qq{Before count from $coll_items_table = count from $coll_table});
    

#EXECUTE
    $co->copy_items($coll_id,$item_id_ref);

#VERIFY
    foreach my $item_id (@{$item_id_ref})
    {
        ok ( $self->item_in_collection($item_id,$coll_id),qq{after copy_items called: item $item_id is  in collection $coll_id});

    }
    # Test that collections table is correctly updated with new number of items
  my $after_count_from_coll_items_table = $co->count_all_items_for_coll_from_coll_items($coll_id);
    my $after_count_from_coll_table = $co->count_all_items_for_coll($coll_id);
        is ($after_count_from_coll_items_table,$after_count_from_coll_table,qq{Before count from $coll_items_table = count from $coll_table});

   

}

#----------------------------------------------------------------------
sub ASSERT_coll_not_owned_by_user_copy_items:Test(no_plan)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing ASSERT_coll_not_owned_by_user_copy_items") if $VERBOSE;
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
    $coll_id = 9; #diabob
    my $item_id_ref = [1,7];
  
    my $method_ref = sub {$co->copy_items(@_)};
    my $arg_ref = [$coll_id, $item_id_ref];
    
    $self->ASSERT_test($method_ref,$arg_ref);

}
#----------------------------------------------------------------------
#----------------------------------------------------------------------
sub ASSERT_one_item_not_in_database_copy_items:Test(1)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing ASSERT  item not in database_copy_items") if $VERBOSE;
    $coll_id = 11; #tburtonw
    my $item_id_ref = [666];
  
    my $method_ref = sub {$co->copy_items(@_)};
    my $arg_ref = [$coll_id, $item_id_ref];
    
    $self->ASSERT_test($method_ref,$arg_ref);

}

#----------------------------------------------------------------------
#----------------------------------------------------------------------
sub ASSERT_one_item_in_and_1_not_in_database_copy_items:Test(1)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing ASSERT  one item in and one item not in database_copy_items") if $VERBOSE;
    $coll_id = 11;# tburtonw
    my $item_id_ref = [1,666];
  
    my $method_ref = sub {$co->copy_items(@_)};
    my $arg_ref = [$coll_id, $item_id_ref];
    
    $self->ASSERT_test($method_ref,$arg_ref);

}

#----------------------------------------------------------------------
#----------------------------------------------------------------------
#  delete items from collection
#----------------------------------------------------------------------
#  mysql> select MColl_ID, item_id from test_coll_item order by MColl_ID,item_id;
#    +----------+---------+
#    | MColl_ID | item_id |
#    +----------+---------+
#    |        9 |       1 |
#    |        9 |       2 |
#    |        9 |       3 |
#    |        9 |       4 |
#    |       11 |       3 |
#    |       11 |       4 |
#    |       11 |       5 |
#    |       11 |       6 |
#    +----------+---------+
#    +----------+---------+
#    | MColl_ID | owner   |
#    +----------+---------+
#    |        9 | diabob  |
#    |       11 | tburtonw |
#    +----------+---------+

sub delete_one_item:Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing delete_items") if $VERBOSE;
    # default setup is with tburtonw userid
    my $user_id = $co->get_user_id;
    ok ($user_id eq 'tburtonw', qq{user_id is tburtonw});
    
    my $coll_id=11;
    my $item_id=4;
    my $item_id_array_ref = [$item_id];

    ok ( $self->item_in_collection($item_id,$coll_id),qq{before delete_items called: item $item_id is in collection $coll_id});    
    $co->delete_items($coll_id,$item_id_array_ref);
    ok (! $self->item_in_collection($item_id,$coll_id),qq{after delete_items called: item $item_id is not in collection $coll_id});
    
}

#----------------------------------------------------------------------------
#    |       11 |       3 |
#    |       11 |       4 |
#    |       11 |       5 |
#    |       11 |       6 |

sub delete_several_items:Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing delete_items with several items") if $VERBOSE;
    # default setup is with tburtonw userid
    my $user_id = $co->get_user_id;
    ok ($user_id eq 'tburtonw', qq{user_id is tburtonw});
    
    my $coll_id=11;
    my $item_id_array_ref = [4,5,6];
    my $item_leave_alone ='3';

    ok ( $self->item_in_collection($item_leave_alone,$coll_id),qq{before delete_items called: item $item_leave_alone is in collection $coll_id});    
    foreach  my $item  (@${item_id_array_ref})
    {
        ok ( $self->item_in_collection($item,$coll_id),qq{before delete_items called: item $item is in collection $coll_id});    
    }
    
    $co->delete_items($coll_id,$item_id_array_ref);

    ok ( $self->item_in_collection($item_leave_alone,$coll_id),qq{after delete_items called: item $item_leave_alone is still in collection $coll_id});    
    foreach my $item  (@${item_id_array_ref})
    {
        ok ( ! $self->item_in_collection($item,$coll_id),qq{after delete_items called: item $item is not in collection $coll_id});    
    }


}

sub ASSERT_coll_not_owned_by_user_delete_items:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    diag("ASSERT coll_not_owned_by_user delete_items") if $VERBOSE;

    my $item_id=4;
    my $item_id_array_ref = [$item_id];
    my $coll_id=9; #owned by diabob

    my $method_ref = sub {$co->delete_items(@_)};
    my $arg_ref = [$coll_id, $item_id_array_ref];
    
    $self->ASSERT_test($method_ref,$arg_ref);

}




#----------------------------------------------------------------------
# list_items tests

sub list_items: Test(2)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing list_items") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id = 11;
    
    $sort_key = 'sort_title';
    $direction = 'a';
    
    my $list_ref=$co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice);
    is ($list_ref->[2]->{'display_title'},'The motor book,',qq{third item is the motor book});
    like ($list_ref->[0]->{'display_title'},qr/Diseases of a gasolene automobile/,qq{first item is Diseases of a gasolene automobile });

}
#----------------------------------------------------------------------
# XXX remove
#  sub list_items_index_status: Test(no_plan)

 # mysql> select test_coll_item.item_id, test_coll_item.isindexed, test_item.display_title from test_coll_item,test_item
#     where MColl_ID =9 and test_coll_item.item_id = test_item.item_id;
#    +---------+-----------+---------------------------------------------------+
#    | item_id | isindexed | display_title                                     |
#    +---------+-----------+---------------------------------------------------+
#    |       1 |         0 | The automobile hand-book;                         |
#    |       2 |         0 | ChaufÃ¯eur chaff; or, Automobilia,                |
#    |       3 |         1 | Diseases of a gasolene automobile and how to cure |
#    |       4 |         1 | The happy motorist; an introduction to the use    |
#    +---------+-----------+---------------------------------------------------+

sub list_items_index_status:# Test(no_plan)
{

    my $self = shift;
    my $co = $self->{co};
    diag("testing list_items") if $VERBOSE;

    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id = 9;
    
    $sort_key = 'sort_title';
    $direction = 'a';
    
    my $list_ref=$co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice);
    like ($list_ref->[0]->{'display_title'},qr/The automobile hand-book/,qq{first item is the automobile hand-book});
  is ($list_ref->[0]->{'isindexed'},0,qq{first item is not indexed});
# add test for isindexed here
    like ($list_ref->[2]->{'display_title'},qr/Diseases of a gasolene automobile/,qq{third item is Diseases of a gasolene automobile });
  is ($list_ref->[2]->{'isindexed'},1,qq{third item is indexed ($list_ref->[2]->{'display_title'})});
}

#----------------------------------------------------------------------
sub list_items_sort_by_display_title: Test(2)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing list_items sorting ") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id = 11;
    
    $sort_key = 'sort_title';
    $direction = 'd';
    
    my $list_ref = $co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice);
    is ($list_ref->[1]->{'display_title'},'The motor book,',qq{second item is the motor book});
    like ($list_ref->[0]->{'display_title'},qr/The motor-car; an elementary handbook /,qq{first item is The motor-car; an elementary handbook });

}
#     mysql> select author, test_item.item_id,display_title  from test_item, test_coll_item where test_item.item_id =test_coll_item.item_id and test_coll_item.MColl_ID=11 order by author;
#+-------------------+---------+---------------------------------------------------+
#    | author            | item_id | display_title                                     |
#    +-------------------+---------+---------------------------------------------------+
#    | Dyke, Andrew Lee, |       3 | Diseases of a gasolene automobile and how to cure |
#    | Mercredy, R. J.   |       5 | The motor book,                                   |
#    | Thompson, Henry,  |       6 | The motor-car; an elementary handbook on its      |
#    | Young, Filson,    |       4 | The happy motorist; an introduction to the use    |
#    +-------------------+---------+---------------------------------------------------+

sub list_items_sort_by_author_ascending: Test(2)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing list_items sorting by author ") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id = 11;
    $sort_key = 'author';
    $direction = 'a';
    
    my $first_author = qq{Dyke, Andrew Lee,};
    my $fourth_author = qq{Young, Filson,};
    
    
    
    my $list_ref = $co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice);
    is ($list_ref->[0]->{'author'},$first_author,qq{first author $first_author});
    is ($list_ref->[3]->{'author'},$fourth_author, qq{fourth author $fourth_author});
}


#    mysql> select date, test_item.item_id,display_title  from test_item, test_coll_item where test_item.item_id =test_coll_item.item_id and test_coll_item.MColl_ID=11 order by date asc;
#    +------------+---------+---------------------------------------------------+
#    | date       | item_id | display_title                                     |
#    +------------+---------+---------------------------------------------------+
#    | 1902-01-01 |       6 | The motor-car; an elementary handbook on its      |
#    | 1903-01-01 |       3 | Diseases of a gasolene automobile and how to cure |
#    | 1903-01-01 |       5 | The motor book,                                   |
#    | 1906-01-01 |       4 | The happy motorist; an introduction to the use    |
#    +------------+---------+---------------------------------------------------+



sub list_items_sort_by_date_ascending: Test(2)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing list_items sorting by date ascending ") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id = 11;
    $sort_key = 'date';
    $direction = 'a';
    
    my $first_date = qq{1902-00-00};
    my $fourth_date = qq{1906-00-00};
        
    my $list_ref = $co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice);
    is ($list_ref->[0]->{'date'},$first_date,qq{first date $first_date});
    is ($list_ref->[3]->{'date'},$fourth_date, qq{fourth date $fourth_date});
}


sub list_items_slice: Test(3)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing list_items slice ") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id=11;
    $sort_key='sort_title';
    $direction = 'a';
    $slice_start = 2;
    $recs_per_slice = 2;
    
        diag("testing slice of $recs_per_slice starting at $slice_start sorting in direction $direction") if $VERBOSE;
    
    $list_ref=$co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice);
    is (scalar(@{$list_ref}),$recs_per_slice ,qq{slice returned correct number of records});
    
    like ($list_ref->[0]->{'display_title'},qr/The happy motorist/,qq{first item is The happy motororist});
    like ($list_ref->[1]->{'display_title'},qr/The motor book/,qq{second item is The motor book });
        
}

#  mysql> select test_item.item_id, test_item.sort_title, test_item.rights  from test_item, test_coll_item
#  where test_coll_item.MColl_ID = 11 and test_coll_item.item_id = test_item.item_id order by test_item.sort_title;
#  +---------+---------------------------------------------------+--------+
#  | item_id | sort_title                                        | rights |
#  +---------+---------------------------------------------------+--------+
#  |       3 | Diseases of a gasolene automobile and how to cure |      4 |
#  |       4 | happy motorist; an introduction to the use        |      5 |
#  |       5 | motor book,                                       |      6 |
#  |       6 | motor-car; an elementary handbook on its          |      7 |
#  +---------+---------------------------------------------------+--------+
#  4 rows in set (0.00 sec)

sub list_items_limit_to_full_text:Test(no_plan)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing list_items limit to full-text ") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
       
    $coll_id=11;
    $sort_key='sort_title';
    $direction = 'a';
    my $rights_ref=[7,5];
    
   
    $list_ref=$co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice,$rights_ref);
    
    like ($list_ref->[0]->{'display_title'},qr/happy motorist/,qq{first item is  happy motororist});
    like ($list_ref->[1]->{'display_title'},qr/motor-car\; an elementary handbook/,qq{second item is motor-car\; an elementary handbook});

}
#----------------------------------------------------------------------
sub list_items_with_id_list:Test(no_plan)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing list_items_with_id_list ") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice,$id_ref)=undef;
       
    $coll_id=11;
    $sort_key='sort_title';
    $direction = 'a';

#    mysql> select test_item.sort_title, test_item.item_id from test_item,test_coll_item 
#    where test_coll_item.MColl_ID=11 and test_item.item_id=test_coll_item.item_id order by test_item.sort_title;
#    +---------------------------------------------------+---------+
#    | sort_title                                        | item_id |
#    +---------------------------------------------------+---------+
#    | Diseases of a gasolene automobile and how to cure |       3 |
#    | happy motorist; an introduction to the use        |       4 |
#    | motor book,                                       |       5 |
#    | motor-car; an elementary handbook on its          |       6 |
#    +---------------------------------------------------+---------+
    my $id_arr_ref=[3,5,6];
    my $not_expected = 4;
    
    my %expected_idhash;
    my @returned_ids;
    my %returned_ids;
     foreach my $id (@{$id_arr_ref})
    {
        $expected_idhash{$id}=1;
    }
                 
    
    my  $list_ref=$co->list_items($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice,$rights_ref,$id_arr_ref);

    # are all the returned ids in the list of supplied ids
    foreach my $hashref (@{$list_ref})
    {
        my $returned_id =$hashref->{'item_id'};
        
         $returned_ids{$returned_id}=1;
        ok ($expected_idhash{$returned_id} == 1,qq{returned id $returned_id is in list of ids supplied as argument});
    }
    # all the expected ids are in the list of returned ids
    foreach my $expected (@{$id_arr_ref})
    {
        ok ($returned_ids{$expected} ==1,qq{ expected id $expected is in returned ids});
    }
    #
        ok ($returned_ids{$not_expected} != 1,qq{ unexpected id $not_expected is not in returned ids});

    # check sort order
    like ($list_ref->[0]->{'display_title'},qr/Diseases/,qq{first item is Diseases});
    like ($list_ref->[1]->{'display_title'},qr/motor book/,qq{second item is motor book});

    like ($list_ref->[2]->{'display_title'},qr/motor-car\; an elementary handbook/,qq{second item is motor-car\; an elementary handbook});

    
    
}


 #-------------------------------------------------------------------------------------------
 # list_items ASSERT tests
sub ASSERT_no_sort_key_list_items:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    my $subname = (caller (0))[3];
    $subname =~ s/Collection::Test:://;
    diag("testing $subname") if $VERBOSE;
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
  
    $coll_id = 11;
    $sort_key = undef;
    $direction = 'a';
    
    my $method_ref = sub {$co->list_items(@_)};
    my $arg_ref = [$coll_id, $sort_key, $direction, $slice_start, $recs_per_slice];
    $self->ASSERT_test($method_ref,$arg_ref);


}
sub ASSERT_no_direction_list_items:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    my $subname = (caller (0))[3];
    $subname =~ s/Collection::Test:://;
    diag("testing $subname") if $VERBOSE;
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
  
    $coll_id = 11;
    $sort_key = 'sort_title';
    $direction = undef;
    
    my $method_ref = sub {$co->list_items(@_)};
    my $arg_ref = [$coll_id, $sort_key, $direction, $slice_start, $recs_per_slice];
    $self->ASSERT_test($method_ref,$arg_ref);

}

sub ASSERT_sort_key_not_in_sort_fields_list_items:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    my $subname = (caller (0))[3];
    $subname =~ s/Collection::Test:://;
    diag("testing $subname") if $VERBOSE;
    
    
    my ($coll_id, $sort_key, $direction, $slice_start, $recs_per_slice)=undef;
  
    $coll_id = 11;
    $sort_key = 'foo_bar';
    $direction = 'a';
    
    my $method_ref = sub {$co->list_items(@_)};
    my $arg_ref = [$coll_id, $sort_key, $direction, $slice_start, $recs_per_slice];
    $self->ASSERT_test($method_ref,$arg_ref);

}




#---------------------------------------------------------------------------------
#     mysql> select MColl_ID, collname, description, shared from test_collection where owner = 'tburtonw';
#    +----------+-----------------------+---------------------------------+--------+
#    | MColl_ID | collname              | description                     | shared |
#    +----------+-----------------------+---------------------------------+--------+
#    |        8 | Stuff for English 324 | Assignments for class and notes |      1 |
#    |        7 | Favorites             | Collection of great stuff       |      0 |
#    |       11 | Books & Stuff         |                                 |      0 |
#    +----------+-----------------------+---------------------------------+--------+



sub edit_status:Test(6)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing edit_status") if $VERBOSE; 
    my $MColl_ID=8; # start with public collection
    
    is ($co->get_shared_status($MColl_ID), 'public',qq{before: public to private});
    $co->edit_status($MColl_ID,'private');
    is ($co->get_shared_status($MColl_ID),  'private',qq{after: public to private});

    # private to private shouldn't do anything
    $MColl_ID=7;
    
    is ($co->get_shared_status($MColl_ID), 'private',qq{before: private to private});
    $co->edit_status($MColl_ID,'private');
    is ($co->get_shared_status($MColl_ID),  'private',qq{after: private to private});
    
    # private to public
    $MColl_ID=7;
    is ($co->get_shared_status($MColl_ID), 'private',qq{before: private to public});
    $co->edit_status($MColl_ID,'public');
    is ($co->get_shared_status($MColl_ID),  'public',qq{after: private to public});

}

#---------------------------------------------------------------------------------
sub ASSERT_bad_status_edit_status:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing ASSERT bad status edit_status") if $VERBOSE; 
    my $MColl_ID=8; # start with public collection
    my $status=100;
    
    my $method_ref = sub {$co->edit_status(@_)};
    my $arg_ref = [$MColl_ID,$status];
    $self->ASSERT_test($method_ref,$arg_ref);




    # bad string  
    #WARNING!! Collection::edit_status currently has two asserts because one isn't working properly
   # $MColl_ID=11;
#    is ($co->get_shared_status($MColl_ID), 'private',qq{before: private to public bad string});
 #   $co->edit_status($MColl_ID,"x");
  #  is ($co->get_shared_status($MColl_ID),  'public',qq{after: private to public bad string});



}

#---------------------------------------------------------------------------------



#---------------------------------------------------------------------------------
#     mysql> select MColl_ID, collname, description, shared from test_collection where owner = 'tburtonw';
#    +----------+-----------------------+---------------------------------+--------+
#    | MColl_ID | collname              | description                     | shared |
#    +----------+-----------------------+---------------------------------+--------+
#    |        8 | Stuff for English 324 | Assignments for class and notes |      1 |
#    |        7 | Favorites             | Collection of great stuff       |      0 |
#    |       11 | Books & Stuff         |                                 |      0 |
#    +----------+-----------------------+---------------------------------+--------+
sub edit_description:Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing edit_description") if $VERBOSE; 
    my $MColl_ID=8;
    my $description=qq{Great Collection};
    is ($co->get_description($MColl_ID),qq{Assignments for class and notes}, qq{before: description = Assignments...});
    $co->edit_description($MColl_ID, $description);
    is ($co->get_description($MColl_ID),$description, qq{after: description = $description});

}
#------------------------------------------------------------------------------------------
sub ASSERT_description_over255chars_edit_description:Test(no_plan)
{
my $self = shift;
    my $co = $self->{co};
    diag("testing ASSERT desc over 255 chars edit_description") if $VERBOSE; 
    my $MColl_ID=11;
    my $description="";
    my $TEN_CHARS='1234567890';
    my $big_string="";
    
    for $i (0..25)
    {
        $big_string.=$TEN_CHARS 
    }
    
    $description = $big_string;
    my $l = length($description);
    diag "length of desc = $l\n" if $VERBOSE;

    my $method_ref = sub {$co->edit_description(@_)};
    my $arg_ref = [$MColl_ID, $description];
    
    $self->ASSERT_test($method_ref,$arg_ref);
    
}

#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
#     mysql> select MColl_ID, collname, description, shared from test_collection where owner = 'tburtonw';
#    +----------+-----------------------+---------------------------------+--------+
#    | MColl_ID | collname              | description                     | shared |
#    +----------+-----------------------+---------------------------------+--------+
#    |        8 | Stuff for English 324 | Assignments for class and notes |      1 |
#    |        7 | Favorites             | Collection of great stuff       |      0 |
#    |       11 | Books & Stuff         |                                 |      0 |
#    +----------+-----------------------+---------------------------------+--------+
sub edit_coll_name:Test(2)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing edit_coll_name") if $VERBOSE; 
    my $MColl_ID = 8;
    my $coll_name = qq{These are times that try mens souls};
    
    is ($co->get_coll_name($MColl_ID),"Stuff for English 324",qq{before coll name edit});
    $co->edit_coll_name($MColl_ID,$coll_name);
    is ($co->get_coll_name($MColl_ID),$coll_name,qq{after coll name edit newcoll = $coll_name});
}

#    +----------+-----------------------+---------------------------------+--------+
sub ASSERT_dup_coll_name_edit_coll_name:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing ASSERT duplicate coll_name edit_coll_name") if $VERBOSE; 
    my $MColl_ID = 8;
    my $coll_name = $co->get_coll_name($MColl_ID);
    
    # ASSERT Test
    $coll_name="Stuff for English 324";
    my $method_ref = sub {$co->edit_coll_name(@_)};
    my $arg_ref = [$MColl_ID, $coll_name];
    
    $self->ASSERT_test($method_ref,$arg_ref);

}
#----------------------------------------------------------------------------------------------

#Note we are testing private method directly since that is where the ASSERT lives and we want to 
#test it independently of the other methods that use it
sub ASSERT_bad_Coll_ID_edit_metadata:Test(1)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing ASSERT bad Coll_ID _edit_metatdata") if $VERBOSE; 
    
    $MColl_ID=666; # coll 666 does not exist
    $field="field";
    $value="value";
    
    my $method_ref = sub {$co->_edit_metadata(@_)};
    my $arg_ref = [$MColl_ID, $field,$value];
    
    $self->ASSERT_test($method_ref,$arg_ref);
}



sub ASSERT_user_does_not_own_collection_edit_metadata:Test(1)
{

    my $self = shift;
    my $co = $self->{co};
    diag("testing ASSERT user does not own collection: _edit metatdata") if $VERBOSE; 
    $MColl_ID=9; # coll 9 owned by diabob!
    $field="field";
    $value="value";
    
    my $method_ref = sub {$co->_edit_metadata(@_)};
    my $arg_ref = [$MColl_ID, $field,$value];
    
    $self->ASSERT_test($method_ref,$arg_ref);
}





#----------------------------------------------------------------------------------------------
sub ASSERT_prep_n_exec_bad_statement#   :Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    
    my $table=$co->get_coll_table_name;
    my $statement = qq{selectx * from $table limit 1\;};
    my $sth =DbUtils::prep_n_execute($dbh, $statement);
    my $fields_ar = $sth->{NAME};
    $sth->finish;
    is ($fields_ar[2], "foo");
}



#----------------------------------------------------------------------

#    mysql> select item_id, extern_item_id, display_title from test_item;
#    +---------+----------------+---------------------------------------------------+
#    | item_id | extern_item_id | display_title                                     |
#    +---------+----------------+---------------------------------------------------+
#    |       1 | 39015020230051 | The automobile hand-book;                         |
#    |       2 | 39015021038404 | ChaufÃ¯eur chaff; or, Automobilia,                |
#    |       3 | 39015002057589 | Diseases of a gasolene automobile and how to cure |
#    |       4 | 39015021302552 | The happy motorist; an introduction to the use    |
#    |       5 | 39015021112043 | The motor book,                                   |
#    |       6 | 39015021302602 | The motor-car; an elementary handbook on its      |
#    |       7 | 39015021302586 | Motor vehicles for business purposes; a practical |
#    |       8 | 39015020229939 | Self-propelled vehicles; a practical treatise on  |
#    |       9 | 39015021057735 | Tramways et automobiles,                          |
#    |      10 | 39015021054963 | Tube, train, tram, and car, or, Up-to-date        |
#    |      11 | 39015002056151 | Whys and wherefores of the automobile, A simple   |
#    +---------+----------------+---------------------------------------------------+
sub get_item_id_from_extern_id:Test(2)
{
    my $self = shift;
    my $co = $self->{co};
    diag("get_item_id_from_extern_id") if $VERBOSE; 
    my $extern_id= 39015021038404; #extern_id for item 2 see above
    is ($co->get_item_id_from_extern_id($extern_id),2,qq{extern_id in db});
    $extern_id=666;# non-existant extern_id
    is ($co->get_item_id_from_extern_id($extern_id),undef,qq{extern_id $extern_id not in db});
    
}
#----------------------------------------------------------------------
sub update_item_metadata:Test(7)
{
    my $self = shift;
    my $co = $self->{co};
    diag("update function of create_or_update_item_metadata") if $VERBOSE; 

    my $dbh = $self->{'dbh'};
    


#  mysql> select * from test_item where item_id=5;
#  +---------+----------------+-----------------+-------------+-----------------+------------+---------------------+--------+
#  | item_id | extern_item_id | display_title   | sort_title  | author          | date       | modified            | rights |
#  +---------+----------------+-----------------+-------------+-----------------+------------+---------------------+--------+
#  |       5 | 39015021112043 | The motor book, | motor book, | Mercredy, R. J. | 1903-00-00 | 2007-06-21 17:07:56 |      3 |
#  +---------+----------------+-----------------+-------------+-----------------+------------+---------------------+--------+
#  1 row in set (0.00 sec)

    my $statement = qq{SELECT * from test_item where item_id = 5};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $hash_ref = $sth->fetchrow_hashref;
    $sth->finish;

     if ($DEBUG)
    {
        diag("confirming test data for item 5 ");
        
        $self->num_method_tests('update_item_metadata','14');
        is ($hash_ref->{item_id}, 5, qq{checking item id });
        is ($hash_ref->{extern_item_id}, 39015021112043, qq{checking barcode/external_item_id});
        is ($hash_ref->{display_title}, qq{The motor book,}, qq{ title is The motor book});
        is ($hash_ref->{sort_title}, qq{motor book,}, qq{sort title is motor book});
        is ($hash_ref->{author},  'Mercredy, R. J.', qq{ author is Mercredy});
        is ($hash_ref->{date}, '1903-00-00', qq{checking date});
        is ($hash_ref->{rights}, 6, qq{checking rights = 6});
    }
    
    is ($hash_ref->{display_title}, qq{The motor book,}, qq{before: title is The motor book});
    is ($hash_ref->{author},  'Mercredy, R. J.', qq{before: author is Mercredy});
    is ($hash_ref->{rights}, 6, qq{before: rights = 3});

    #setup
    #change three  fields

    $hash_ref->{display_title} = qq{This is a new title};
    $hash_ref->{author} = qq{foo,von author};
    $hash_ref->{rights} = 1;
    
    my $extern_id = $hash_ref->{extern_item_id};
    my $metadata_ref = $hash_ref;
    
    #execute 
    my $item_id = $co->create_or_update_item_metadata($metadata_ref);

    # verify
    is ($item_id,5,qq{extern_id $extern_id is item $item_id});
    
    $statement = qq{SELECT * from test_item where item_id = 5};
    $sth = DbUtils::prep_n_execute($dbh, $statement);
    $new_hash_ref = $sth->fetchrow_hashref;
    $sth->finish;
    
    is ($new_hash_ref->{display_title}, qq{This is a new title}, qq{after: title is 'This is a new title'});
    is ($new_hash_ref->{author},  'foo,von author', qq{after: author is 'foo'});
    is ($new_hash_ref->{rights}, 1, qq{after: rights = 1});
    
}
#-----------------------------------------------------

# this tests the create function of sub create_or_update_item_metadata
sub create_item_metadata:Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    diag("create function of create_or_update_item_metadata") if $VERBOSE; 
    my $dbh = $self->{'dbh'};

    #get number of items in test db
    $statement = qq{SELECT count(*) as numrecs from test_item };
    $sth = DbUtils::prep_n_execute($dbh, $statement);
    $hash_ref = $sth->fetchrow_hashref;
    $sth->finish;
    my $numrecs = $hash_ref->{numrecs};
    my $expected_new_id = $numrecs +1;
    
    
    my $extern_id ='12345';
#  | item_id | extern_item_id | display_title   | sort_title  | author          | date       | modified            | rights |
 
    my $metadata_ref = {
                       'extern_item_id'=> $extern_id,
                       'display_title' =>qq{The rain in spain},
                       'sort_title' =>qq{rain in spain},
                       'author' => qq{Higgins, Henry H.},
                       'date' => qq{1937-04-04},
                        'rights' => '7',
                       };
    
    my $item_id = $co->create_or_update_item_metadata($metadata_ref);
    $statement = qq{SELECT * from test_item where item_id = $item_id};
    $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $new_hash_ref = $sth->fetchrow_hashref;
    $sth->finish;
#    is ($item_id, $expected_new_id, qq{returned id is $expected_new_id });  
# new id generation makes new id unpredictable!
    is ($new_hash_ref->{display_title},$metadata_ref->{'display_title'}, "title is $metadata_ref->{'display_title'}");
    is ($new_hash_ref->{author}, $metadata_ref->{'author'}, "author is $metadata_ref->{'author'}");
    is ($new_hash_ref->{rights}, $metadata_ref->{'rights'}, "rights = $metadata_ref->{'rights'}");

}
#======================================================================
#  Test Collection utility routines
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#    +----------+---------+
#    | MColl_ID | owner   |
#    +----------+---------+
#    |        9 | diabob  |
#    |       11 | tburtonw |
#    +----------+---------+
sub coll_owned_by_user:Test(3)
           
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing coll_owned_by_user") if $VERBOSE;
    my $user_id = 'tburtonw';
    my $coll_id = 11;
    
    ok ($co->coll_owned_by_user($coll_id, $user_id),"collection $coll_id owned by $user_id");

    my $coll_id = 9; #not owned by $user_id tburtonw
    ok (!$co->coll_owned_by_user($coll_id, $user_id),"collection $coll_id not owned by $user_id");

    #non-existant user_id
    my $user_id = 999;
   ok (! $co->coll_owned_by_user($coll_id, $user_id),"collection $coll_id not owned by non-existent user:$user_id");


}
           

#----------------------------------------------------------------------
sub item_exists :Test(2)
{
    my $self=shift;
    my $co=$self->{co};
    diag("item_exists") if $VERBOSE;
    my $item_id = 5;  #5 exists
    ok ($co->item_exists($item_id),"item $item_id exists");
        
    $item_id = 666;  # item 666 does not exist
    ok (! $co->item_exists($item_id)," item $item_id does not exist");
    
}

#----------------------------------------------------------------------
sub test_item_in_collection :Test(2)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing $co->item_in_collection") if $VERBOSE;
    my $coll_id = 11;
    my $item_id = 6;
    ok ($co->item_in_collection($item_id,$coll_id), "item $item_id is in collection $coll_id");
    $item_id=666;
    ok (!$co->item_in_collection($item_id,$coll_id), "item $item_id is not  in collection $coll_id");
}



#----------------------------------------------------------------------
sub item_in_a_collection:Test(4)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing $co->item_in_a_collection") if $VERBOSE;
    my $item_id=6;
    
    ok ($co->item_in_a_collection($item_id),qq{item $item_id is in a collection});    

    $item_id=666;
    ok (! $co->item_in_a_collection($item_id),qq{non-existant item $item_id is not in a collection});    

    $item_id=2;
    ok ($co->item_in_a_collection($item_id),qq{item $item_id is in a collection});    

    $item_id=123456789;
    ok (! $co->item_in_a_collection($item_id),qq{non-existant item $item_id is not in a collection});    

}

#----------------------------------------------------------------------
sub get_collnames_for_item :Test(4)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing get_collnames_for_item") if $VERBOSE;
    my $item_id = 3;
    my $coll_ary_ref=$co->get_collnames_for_item($item_id);
  
    like ($coll_ary_ref->[0],qr/Automotive Engineering/,qq{first collection named Automotive Engineering});
    like ($coll_ary_ref->[1],qr/Books/,qq{second collection named Books });
    like ($coll_ary_ref->[2],qr/Favorites/,qq{third collection named Favorites});
    like ($coll_ary_ref->[3],qr/Stuff for English/,qq{fourth collection named Stuff for English});    
   
}
#----------------------------------------------------------------------

#----------------------------------------------------------------------
sub get_collnames_for_item_and_user :Test(no_plan)
{
    my $self=shift;
    my $co=$self->{co};
    diag("testing get_collnames_for_item_and_user") if $VERBOSE;
    my $item_id = 3;
    my $user_id = 'tburtonw';
    my $coll_ary_ref=$co->get_collnames_for_item_and_user($item_id,$user_id);
    my $num_colls = $#{$coll_ary_ref}+1;
    is ($num_colls, 3,qq{number of collections for item $item_id and user $user_id is 3});
    
    like ($coll_ary_ref->[0],qr/Books/,qq{second collection named Books });
    like ($coll_ary_ref->[1],qr/Favorites/,qq{third collection named Favorites});
    like ($coll_ary_ref->[2],qr/Stuff for English/,qq{fourth collection named Stuff for English});    
   
}
#----------------------------------------------------------------------
#---------------------------------------------------------------------------------
#     mysql> select MColl_ID, collname, description, shared from test_collection where owner = 'tburtonw';
#    +----------+-----------------------+---------------------------------+--------+
#    | MColl_ID | collname              | description                     | shared |
#    +----------+-----------------------+---------------------------------+--------+
#    |        8 | Stuff for English 324 | Assignments for class and notes |      1 |
#    |        7 | Favorites             | Collection of great stuff       |      0 |
#    |       11 | Books and Stuff         |                                 |      0 |
#    +----------+-----------------------+---------------------------------+--------+
sub get_coll_name:Test(3)
{
    my $self = shift;
    my $co = $self->{co};
    diag("testing get_coll_name") if $VERBOSE; 
    my %id2coll=(8=>"Stuff for English 324",7=>"Favorites",11=>"Books and Stuff");
    
    foreach my $id (sort (keys %id2coll))
    {
        is ($co->get_coll_name($id),"$id2coll{$id}","name for $id is $id2coll{$id}");
    }
    # bad id test

    $id =666; #bad id
        is ($co->get_coll_name($id),undef,"name for $id is undef because 666 not a real id");
     
}

#    +----------+-----------------------+---------------------------------+--------+

# These are items in collection 11
# mysql> select item_id, display_title, rights from test_item where item_id in (3,4,5,6) order by item_id;
# +---------+---------------------------------------------------+--------+
# | item_id | display_title                                     | rights |
# +---------+---------------------------------------------------+--------+
# |       3 | Diseases of a gasolene automobile and how to cure |      4 |
# |       4 | The happy motorist; an introduction to the use    |      5 |
# |       5 | The motor book,                                   |      6 |
# |       6 | The motor-car; an elementary handbook on its      |      7 |
# +---------+---------------------------------------------------+--------+

sub count_full_text:Test(no_plan)
{
        diag("testing count full text") if $VERBOSE; 
    my $self = shift;
    my $coll_id =11;
    
    my $co = $self->{co};
    my $rights_ref=[0,1,4,5,6]; # only matches are 4, 5, and 6
    my $full_text_count = $co->count_full_text($coll_id,$rights_ref);
    is ($full_text_count, 3,qq{full_text_count should be 3});

    $rights_ref=[6,7];

    $full_text_count = $co->count_full_text($coll_id, $rights_ref);
    is ($full_text_count, 2,qq{full_text_count should be 2});
    
}

#  mysql> select count(item_id) from test_coll_item where MColl_ID=7;
#    +----------------+
#    | count(item_id) |
#    +----------------+
#    |              1 |
#    +----------------+
#    mysql> select count(item_id) from test_coll_item where MColl_ID=8;
#    +----------------+
#    | count(item_id) |
#    +----------------+
#    |              1 |
#    +----------------+
#    mysql> select count(item_id) from test_coll_item where MColl_ID=11;
#    +----------------+
#    | count(item_id) |
#    +----------------+
#    |              4 |
#    +----------------+

sub count_all_items_for_coll:Test(no_plan)

{
   diag("testing count all items for coll") if $VERBOSE; 
    my $self = shift;
    my $co = $self->{co};
    my %coll_ids_count =(7=>1,8=>1,11=>4,9=>4);
    my $count=0;

    foreach my $coll_id (keys %coll_ids_count)
    {
        $count = $co->count_all_items_for_coll($coll_id);
        is ($count, $coll_ids_count{$coll_id},"count for coll id $coll_id is $count it  should be $coll_ids_count{$coll_id}");
    }
    
}
sub count_all_items_for_coll_from_coll_items:Test(no_plan)
{
   diag("testing count all items for coll from coll_items table") if $VERBOSE; 
    my $self = shift;
    my $co = $self->{co};
    my %coll_ids_count =(7=>1,8=>1,11=>4,9=>4);
   my $count=0;
   
    foreach my $coll_id (keys %coll_ids_count)
    {
         $count = $co->count_all_items_for_coll_from_coll_items($coll_id);
        is ($count, $coll_ids_count{$coll_id},"count for coll id $coll_id is $count it  should be $coll_ids_count{$coll_id}");
    }

}
#---------------------------------------------------------
# updates the collection table to match the actual counts of items in the coll_items table
#  mysql> select MColl_ID, item_id from test_coll_item order by MColl_ID,item_id;
#    +----------+---------+
#    | MColl_ID | item_id |
#    +----------+---------+
#    |        9 |       1 |
#    |        9 |       2 |
#    |        9 |       3 |
#    |        9 |       4 |
#    |       11 |       3 |
#    |       11 |       4 |
#    |       11 |       5 |
#    |       11 |       6 |
#    +----------+---------+


sub copy_items_coll_table_count:Test(4)
{
    diag("testing copy_item coll_table_count") if $VERBOSE; 
    my $self = shift;
    my $co = $self->{co};
    #coll 11 should have 4 items
    my $coll_id=11;
    my $item_id_ref=[1,2];
    
    # get count before adding item
    my $coll_items_count = $co->count_all_items_for_coll_from_coll_items($coll_id);
    my $collection_count = $co->count_all_items_for_coll($coll_id);
    
    is($collection_count, 4,qq{before adding items,  item count collection table for  $coll_id should have 4 items});
    is($collection_count, $coll_items_count ,qq{before adding  items,  item counts from collection table should match counts from coll_item table});

    # add item
    $co->copy_items($coll_id,$item_id_ref);
    # get count after adding items before updating count
      
    #VERIFY
    $after_coll_items_count = $co->count_all_items_for_coll_from_coll_items($coll_id);
     $after_collection_count =  $co->count_all_items_for_coll($coll_id);

    is($after_collection_count, 6,qq{after adding two  item count collection table for  $coll_id should have 6 items});
    
    is($after_collection_count, $after_coll_items_count ,qq{after updating item counts from collection table should match counts from coll_item table});

}
sub delete_items_coll_table_count:Test(4)
{
    diag("testing delete_items coll_table_count") if $VERBOSE; 
    my $self = shift;
    my $co = $self->{co};
    #coll 11 should have 4 items
    my $coll_id=11;
    my $item_id_ref=[5,6];
    
    # get count before deleting item
    my $coll_items_count = $co->count_all_items_for_coll_from_coll_items($coll_id);
    my $collection_count = $co->count_all_items_for_coll($coll_id);
    
    is($collection_count, 4,qq{before deleting items,  item count collection table for  $coll_id should have 4 items});
    is($collection_count, $coll_items_count ,qq{before deleting items,  item counts from collection table should match counts from coll_item table});

    #  item
    $co->delete_items($coll_id,$item_id_ref);
    # get count after deleting items
      
    #VERIFY
    $after_coll_items_count = $co->count_all_items_for_coll_from_coll_items($coll_id);
     $after_collection_count =  $co->count_all_items_for_coll($coll_id);

    is($after_collection_count, 2,qq{after deleting two  items  count of collection table (num_items) for  $coll_id should have 2 items});
    
    is($after_collection_count, $after_coll_items_count ,qq{after deleting item counts from collection table should match counts from coll_item table});

}

#----------------------------------------------------------------------
sub CS_delete_all_colls_for_user:Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $coll_table=$co->get_coll_table_name;

    my $CS= CollectionSet->new($dbh,$self->{config},$user_id) ;
    isa_ok($CS, CollectionSet,"CollectionSet is set up");
    diag("delete_all_colls_for_user") if $VERBOSE;
    
    
    my $coll_table = $CS->{'coll_table_name'};
    my $coll_item = $CS->get_coll_item_table_name;
    my $user_id = 'tburtonw';

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

    
    my $coll_id=11;
    
    my $item_id=3;
    
    
      ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});
    $item_id=4;
    
   ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});
    $item_id=5;
    
       ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});
$item_id=6;    
   ok ( $co->item_in_collection($item_id,$coll_id),qq{Item $item_id  in collection $coll_id});

    $coll_id=8;
    $item_id=3;
    
 ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id    in collection $coll_id});
    $coll_id=7;
    $item_id=3;
    
       ok ($co->item_in_collection($item_id,$coll_id),qq{Item $item_id    in collection $coll_id});

    foreach my $coll (@Before_coll_ids)
    {
        ok($CS->exists_coll_id($coll),qq{Collection $coll  exists});
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
#----------------------------------------------------------------------------------------------


#----------------------------------------------------------------------------------------------
sub   get_metadata_from_item_ids:Test(no_plan)
{
    diag ("testing get_metadata_for_item_ids") if $VERBOSE;
    
    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $item_table=$co->get_item_table_name;
    
#    mysql> select item_id, author, date, display_title from test_item where item_id <5;
#    +---------+---------------------------+------------+---------------------------------------------------+
#    | item_id | author                    | date       | display_title                                     |
#    +---------+---------------------------+------------+---------------------------------------------------+
#    |       1 | Brookes, Leonard Elliott, | 1905-00-00 | The automobile hand-book;                         |
#    |       2 | Welsh, Charles,           | 1905-00-00 | ChaufÃ¯eur chaff; or, Automobilia,                |
#    |       3 | Dyke, Andrew Lee,         | 1903-00-00 | Diseases of a gasolene automobile and how to cure |
#    |       4 | Young, Filson,            | 1906-00-00 | The happy motorist; an introduction to the use    |
#    +---------+---------------------------+------------+---------------------------------------------------+
#    mysql> select item_id, sort_title, extern_item_id,rights from test_item where item_id <5;
#    +---------+---------------------------------------------------+----------------+--------+
#    | item_id | sort_title                                        | extern_item_id | rights |
#    +---------+---------------------------------------------------+----------------+--------+
#    |       1 | automobile hand-book;                             | 39015020230051 |      2 |
#    |       2 | ChaufÃ¯eur chaff; or, Automobilia,                | 39015021038404 |      3 |
#    |       3 | Diseases of a gasolene automobile and how to cure | 39015002057589 |      4 |
#    |       4 | happy motorist; an introduction to the use        | 39015021302552 |      5 |
#   +---------+---------------------------------------------------+----------------+--------+

    my $idref=[1,2,3,4];
    my $ary_hashrefs = $co->get_metadata_for_item_ids($idref);
    my %id2hash;
    
    foreach my $hashref (@{$ary_hashrefs})
    {
        my $id = $hashref->{'item_id'};
        $id2hash{$id}=$hashref;
    }
    
    my $refhash = $id2hash{1};
    
    is ($refhash->{'item_id'} , 1,qq{id 1 is 1});
    is ($refhash->{'display_title'} , "The automobile hand-book\;",qq{id 1 display title is The automobile hand-book});
    is ($refhash->{'sort_title'} , "automobile hand-book\;",qq{id 1 display title is  automobile hand-book});
    is ($refhash->{'extern_item_id'} , 39015020230051,qq{extern_item_id for id 1 is 39015020230051});
    is ($refhash->{'date'} , '1905-00-00' ,qq{date for id 1 is 1905-00-00});
    is ($refhash->{'author'} , 'Brookes, Leonard Elliott,',qq{author for id 1 is Brookes, Leonard Elliott,});
    is ($refhash->{'rights'} , 2,qq{rights for id 1 is 2});
    
    $refhash=$id2hash{2};
    is ($refhash->{'item_id'} , 2,qq{id 1 is 2});
    like ($refhash->{'display_title'} ,qr/Automobilia/,qq{id 1 display title contains Automobilia});
    is ($refhash->{'extern_item_id'} , 39015021038404,qq{extern_item_id for id 2 is 39015021038404});
}
#----------------------------------------------------------------------
#  mysql> select MColl_ID, item_id from test_coll_item order by MColl_ID,item_id;
#    +----------+---------+
#    | MColl_ID | item_id |
#    +----------+---------+
#    |        9 |       1 |
#    |        9 |       2 |
#    |        9 |       3 |
#    |        9 |       4 |
#    |       11 |       3 |
#    |       11 |       4 |
#    |       11 |       5 |
#    |       11 |       6 |
#    +----------+---------+


sub one_or_more_items_in_coll:Test(5)
{
    diag("one_or_more_items_in_coll") if $VERBOSE; 
    my $self = shift;
    my $co = $self->{co};
    my $coll_id=9;
    my $item_id_ref =[1,2,3,4];
    
    ok ($co->one_or_more_items_in_coll($coll_id,$item_id_ref),qq{one or more of items 1-4 are in coll $coll_id});
    $item_id_ref =[8,9,10];
    ok (!$co->one_or_more_items_in_coll($coll_id,$item_id_ref),qq{items 8-10 are not in coll $coll_id});
    $item_id_ref =[1,8,9,10];
    ok ($co->one_or_more_items_in_coll($coll_id,$item_id_ref),qq{one or more of items 1,8,9,10 are  in coll $coll_id});
    $item_id_ref =[6,8,9,10];
    ok (!$co->one_or_more_items_in_coll($coll_id,$item_id_ref),qq{one or more of items 6,8,9,10 are not in coll $coll_id});
    $coll_id=11;
    ok ($co->one_or_more_items_in_coll($coll_id,$item_id_ref),qq{one or more of items 6,8,9,10 are in coll $coll_id});

}
#----------------------------------------------------------------------


#----------------------------------------------------------------------
#XXX remove
# mysql> select item_id, display_title, isindexed from test_item;
# +---------+---------------------------------------------------+-----------+
# | item_id | display_title                                     | isindexed |
# +---------+---------------------------------------------------+-----------+
# |       1 | The automobile hand-book;                         |         0 |
# |       2 | ChaufÃ¯eur chaff; or, Automobilia,                |         0 |
# |       3 | Diseases of a gasolene automobile and how to cure |         1 |
# |       4 | The happy motorist; an introduction to the use    |         1 |
# |       5 | The motor book,                                   |         0 |
# |       6 | The motor-car; an elementary handbook on its      |         0 |
# |       7 | Motor vehicles for business purposes; a practical |         0 |
# |       8 | Self-propelled vehicles; a practical treatise on  |         0 |
# |       9 | Tramways et automobiles,                          |         0 |
# |      10 | Tube, train, tram, and car, or, Up-to-date        |         0 |
# |      11 | Whys and wherefores of the automobile, A simple   |         0 |
#+---------+---------------------------------------------------+-----------+


# +---------+---------------------------------------------------+-----------+
# | item_id | display_title                                     | isindexed |
# +---------+---------------------------------------------------+-----------+
# |       1 | The automobile hand-book;                         |         0 |
# |       2 | ChaufÃ¯eur chaff; or, Automobilia,                |         0 |
# |       3 | Diseases of a gasolene automobile and how to cure |         1 |
# |       4 | The happy motorist; an introduction to the use    |         1 |

#----------------------------------------------------------------------



# mysql> select MColl_Id, test_item.item_id , test_item.isindexed from test_coll_item, test_item where test_coll_item.item_id=test_item.item_id  order by MColl_Id;
#+----------+---------+-----------+
#    | MColl_Id | item_id | isindexed |
#    +----------+---------+-----------+
#    |        7 |       3 |         1 |
#    |        8 |       3 |         1 |
#    |        9 |       4 |         1 |
#    |        9 |       1 |         0 |
#    |        9 |       3 |         1 |
#    |        9 |       2 |         0 |
#    |       11 |       3 |         1 |
#    |       11 |       4 |         1 |
#    |       11 |       5 |         0 |
#    |       11 |       6 |         0 |
#    +----------+---------+-----------+
#XXX remove
sub isindexed:#Test(no_plan)
{
    my $self = shift;
    my $co = $self->{co};
    diag ("isindexed:Test") if $VERBOSE;
    # index constants from Search::State
    #    IX_NOT_INDEXED|IX_INDEXED
    my $coll_id =7;
    my $item_id =3;
    
    ok ($co->isindexed($coll_id,$item_id),qq{collid: $coll_id item: $item_id is indexed});
    $coll_id=9;
    
    my @indexed_items=(3,4);
    my @unindexed_items=(1,2);
    
    foreach $item_id (@indexed_items)
    {
        ok ($co->isindexed($coll_id,$item_id),qq{collid: $coll_id item: $item_id is indexed});
    }
    foreach $item_id (@unindexed_items)
    {
        ok (!$co->isindexed($coll_id,$item_id),qq{collid: $coll_id item: $item_id is NOT indexed});
    }
}



#XXX remove after testing phils methods
sub collection_all_indexed:#Test(no_plan)
{
    my $self = shift;

    diag ("collection_all_indexed:Test") if $VERBOSE;
    # index constants from Search::State
    #    IX_NOT_INDEXED|IX_INDEXED
  

    my $co = $self->{co};
    
# collections 7 and 8 have only one item and it is indexed, colls 9 and 11 have unindexed items
    
    ok ($co->collection_all_indexed(7),qq{collection 7 all indexed});
    ok ($co->collection_all_indexed(8),qq{collection 8 all indexed});
    ok (!$co->collection_all_indexed(9),qq{collection 9 not all indexed});
    ok (!$co->collection_all_indexed(11),qq{collection 11 not all indexed});

    #XXX TODO  implement below using updated set_indexed function
# make collection 9 have all indexed items
    # get list of item ids in collection 9
#    my $item_ary_ref =$co->get_item_ids_for_coll(9);
 #   $co->set_items_index_status($item_ary_ref,IX_INDEXED);
  #  ok ($co->collection_all_indexed(9),qq{after indexing, collection 9   all indexed});
    
}







#    mysql> select * from test_index_queue order by priority,time_added;
#+---------------------+----------+----------+---------+
#    | time_added          | priority | coll_ids | item_id |
#    +---------------------+----------+----------+---------+
#    | 2008-04-15 13:20:26 |        1 | 9|10|11  |       1 |
#    | 2008-04-15 13:20:27 |        1 | 9|33     |       2 |
#    | 2008-04-15 13:20:31 |        2 | 11       |       6 |
#    | 2008-04-15 13:20:28 |      100 | 7|88|99  |       3 |
#    | 2008-04-15 13:20:29 |      100 | 9|88     |       4 |
#    | 2008-04-15 13:20:30 |      100 | 11|88    |       5 |
#    +---------------------+----------+----------+---------+

  #  mysql> select * from test_coll_item  order by item_id,MColl_ID;
#+---------+----------+
#    | item_id | MColl_ID |
#    +---------+----------+
#    |       1 |        9 |
#    |       2 |        9 |
#    |       3 |        7 |
#    |       3 |        8 |
#    |       3 |        9 |
#    |       3 |       11 |
#    |       4 |        9 |
#    |       4 |       11 |
#    |       5 |       11 |
#    |       6 |       11 |
#    +---------+----------+

sub   add_to_queue_single:Test(no_plan)
{
    diag ("add_to_queue:Test") if $VERBOSE;


    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $queue_table=$co->get_index_queue_table_name;
    my @items =(1,2,3,4,5,6,7,8,);
    my %prior=(1=>7,2=>8,3=>8,4=>1,5=>100,6=>1,7=>100,8=>100);
    my %expected_prior=(1=>1,2=>1,3=>8,4=>1,5=>100,6=>1,7=>100,8=>100);
    my %item_coll=(1=>'9',2=>'9',3=>'7|8|9|11',4=>'9|11',5=>'11',6=>'11',7=>'0',8=>'0');

# should have separate tests for insert vs replace and for 
#    1 timestamp should get current time on insert/not change on update
#    2  priority should get changed if new priority better than old one   
#    3 there should be no dup items?

    my $priority=1;
    my $coll_ids;
    
    # One at a time    
    foreach my $item_id (@items)
    {
        $priority = $prior{$item_id};
        $expected_priority =  $expected_prior{$item_id};
        $coll_ids = $item_coll{$item_id};
        my $item_id_ref=[$item_id];
        $co->add_to_queue($item_id_ref, $priority);
        sleep(1);
        my $rowref = $self->get_item_from_queue($item_id);
        is ($rowref->[0]->{item_id},$item_id,qq{item id is $item_id});
        is ($rowref->[0]->{priority},$expected_priority,qq{priority  is set to  $expected_priority});
        is ($rowref->[0]->{coll_ids},$coll_ids,qq{collections  are set to  $coll_ids});
    }
    # test that timestamp changes on new row but not on existing row
    diag("timestamp test");
    
    #XXX Should test asserts for bad args here 
   # diag("add_to_queue bad data type test");
   ### my $item_id = undef;
   # $co->add_to_queue($item_id, $coll_id, $action);

}


sub   add_to_queue_priority:Test(no_plan)
{
    diag ("add_to_queue_priority:Test") if $VERBOSE;
#    mysql> select item_id, priority from test_index_queue order by item_id;
#    +---------+----------+
#    | item_id | priority |
#    +---------+----------+
#    |       1 |        1 |
#    |       2 |        1 |
#    |       3 |      100 |
#    |       4 |      100 |
#    |       5 |      100 |
#    |       6 |        2 |
#    +---------+----------+

    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $queue_table=$co->get_index_queue_table_name;
    my @items =(1,2,3,4,5,6);

    diag("priority should stay the same if new priority lower (i.e. higher number)") if $VERBOSE;
    
    my $item_id = 3; # priority = 100
    my $priority = 101;
    my $expected_priority = 100;
    my $item_id_ref =[$item_id];
    
    $co->add_to_queue($item_id_ref, $priority);
    my $rowref = $self->get_item_from_queue($item_id);
    is ($rowref->[0]->{item_id},$item_id,qq{item id is $item_id});
    is ($rowref->[0]->{priority},$expected_priority,qq{priority  is set to  $expected_priority});
        
    
    diag("priority should get set to highest priority if new priority higher (i.e. lower number)") if $VERBOSE;
    
    my $item_id = 4; # priority = 100
    my $priority = 99;
    my $expected_priority = 99;
    my $item_id_ref =[$item_id];

    $co->add_to_queue($item_id_ref, $priority);
    my $rowref = $self->get_item_from_queue($item_id);
    is ($rowref->[0]->{item_id},$item_id,qq{item id is $item_id});
    is ($rowref->[0]->{priority},$expected_priority,qq{priority  is set to  $expected_priority});
    
    diag("priority should stay the same if new priority = old priority" ) if $VERBOSE;
    
    my $item_id = 5; # priority = 100
    my $priority = 100;
    my $expected_priority = 100;
    my $item_id_ref =[$item_id];

    $co->add_to_queue($item_id_ref, $priority);
    my $rowref = $self->get_item_from_queue($item_id);
    is ($rowref->[0]->{item_id},$item_id,qq{item id is $item_id});
    is ($rowref->[0]->{priority},$expected_priority,qq{priority  is set to  $expected_priority});
}


sub   add_to_queue_timestamp:Test(no_plan)
{
    diag ("add_to_queue_timestamp") if $VERBOSE;

#    mysql> select  item_id,time_added from test_index_queue order by item_id;
#    +---------+---------------------+
#    | item_id | time_added          |
#    +---------+---------------------+
#    |       1 | 2008-04-15 13:20:26 |
#    |       2 | 2008-04-15 13:20:27 |
#    |       3 | 2008-04-15 13:20:28 |
#    |       4 | 2008-04-15 13:20:29 |
#    |       5 | 2008-04-15 13:20:30 |
#    |       6 | 2008-04-15 13:20:31 |
#    +---------+---------------------+


    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $queue_table=$co->get_index_queue_table_name;

    my $item_id = 1; # priority = 100
    my $priority = 100;
    my $item_id_ref =[$item_id];

    
    my $before_rowref = $self->get_item_from_queue($item_id);
    my $before_timestamp = $before_rowref->[0]->{time_added};
    
    $co->add_to_queue($item_id_ref, $priority);
    my $rowref = $self->get_item_from_queue($item_id);
    is ($rowref->[0]->{item_id},$item_id,qq{item id is $item_id});
    is ($rowref->[0]->{time_added}, $before_timestamp,qq{timestamp unchanged});
    
}


sub   add_to_queue_all_at_once:Test(no_plan)
{
    diag ("add_to_queue_all_at_once:Test") if $VERBOSE;


    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $queue_table=$co->get_index_queue_table_name;
    my @items =(1,2,3,4,5,6,7,8);
    my $priority=scalar(@items);    
    
    my %expected_prior=(1=>1,2=>1,3=>$priority,4=>$priority,5=>$priority,6=>2,7=>$priority,8=>$priority);
    my %item_coll=(1=>'9',2=>'9',3=>'7|8|9|11',4=>'9|11',5=>'11',6=>'11',7=>'0',8=>'0');
    my $coll_ids;
    my $item_id_ref =\@items;

    $co->add_to_queue($item_id_ref, $priority);

    foreach my $item_id (@items)
    {    
        $expected_priority =  $expected_prior{$item_id};
        $coll_ids = $item_coll{$item_id};
        my $rowref = $self->get_item_from_queue($item_id);
        is ($rowref->[0]->{item_id},$item_id,qq{item id is $item_id});
        is ($rowref->[0]->{priority},$expected_priority,qq{priority  is set to  $expected_priority});
        is ($rowref->[0]->{coll_ids},$coll_ids,qq{collections  are set to  $coll_ids});
    }

}
#----------------------------------------------------------------------
sub get_most_recent_add_to_queue
{
    my $self = shift;
    my $slice = shift;
    
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $queue_table = $co->get_index_queue_table_name;
    my $LIMIT = qq{ LIMIT };
    
    if (!defined($slice))
    {
        $slice =1;
    }
 
    $LIMIT .= qq{0,$slice};    
    my $statement = qq{SELECT * from $queue_table order by time_added desc, item_id $LIMIT;};
#    diag(" $statement");
    
    my $sth = DbUtils::prep_n_execute($dbh, $statement);    
    my $ref_ary_of_hashrefs =$sth->fetchall_arrayref({});
    return $ref_ary_of_hashrefs;
}
sub get_item_from_queue
{
    my $self = shift;
    my $item_id = shift;
    
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $queue_table = $co->get_index_queue_table_name;
 

    my $statement = qq{SELECT * from $queue_table where item_id =$item_id;};
#    diag(" $statement");
    
    my $sth = DbUtils::prep_n_execute($dbh, $statement);    
    my $ref_ary_of_hashrefs =$sth->fetchall_arrayref({});
    return $ref_ary_of_hashrefs;
}


#    mysql> select * from test_coll_item;
#    +---------+----------+-----------+
#    | item_id | MColl_ID | isindexed |
#    +---------+----------+-----------+
#    |       1 |        9 |         0 |
#    |       2 |        9 |         0 |
#    |       3 |        9 |         1 |
#    |       3 |       11 |         3 |
#    |       3 |        7 |         1 |
#    |       3 |        8 |         1 |
#    |       4 |        9 |         1 |
#    |       4 |       11 |         0 |
#    |       5 |       11 |         0 |
#    |       6 |       11 |         0 |
#    +---------+----------+-----------+

#----------------------------------------------------------------------
# XXX remove
sub set_index_status_for_item:#Test(no_plan)
{
    diag ("set_index_status_for_item") if $VERBOSE;
    # 
    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $coll_item = $co->get_coll_item_table_name;
    my $item_id = 3;
    my @coll_ids =(7,8,9,11);
    my $coll_status={};
    my $status = IX_NOT_INDEXED;
    
    diag("\tset index status to not indexed") if $VERBOSE;
    $co->set_index_status_for_item($status,$item_id, \@coll_ids);
    foreach my $coll_id (@coll_ids)
    {
        ok (! $co->isindexed($coll_id,$item_id),qq{coll $coll_id for item $item_id not indexed});
    }
    diag("\tset index status to indexed") if $VERBOSE;
    $status = IX_INDEXED;
    $co->set_index_status_for_item($status,$item_id, \@coll_ids);
    foreach my $coll_id (@coll_ids)
    {
        ok ($co->isindexed($coll_id,$item_id),qq{coll $coll_id for item $item_id is  indexed});
    }
}

#----------------------------------------------------------------------
#XXX remove
sub set_index_status_for_coll:#Test(no_plan)
{
    diag ("set_index_status_for_coll") if $VERBOSE;
    #$co->set_index_status_for_coll($status,$coll_id \@item_ids)
    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my $coll_item = $co->get_coll_item_table_name;
    my $coll_id = 11;
    my @item_ids =(3,4,5,6);

    my $status = IX_NOT_INDEXED;
    
    diag("\tset index status to not indexed") if $VERBOSE;
    $co->set_index_status_for_coll($status,$coll_id, \@item_ids);
    foreach my $item_id (@item_ids)
    {
        ok (! $co->isindexed($coll_id,$item_id),qq{coll $coll_id for item $item_id not indexed});
    }
    diag("\tset index status to indexed") if $VERBOSE;
    $status = IX_INDEXED;
    $co->set_index_status_for_coll($status,$coll_id, \@item_ids);
    foreach my $item_id (@item_ids)
    {
        ok ($co->isindexed($coll_id,$item_id),qq{coll $coll_id for item $item_id is  indexed});
    }
}
#----------------------------------------------------------------------

#XXX remove
#mysql> select * from test_index_failures;
#+---------+
#    | item_id |
#    +---------+
#    |       1 |
#    |       4 |
#    |       6 |
#    +---------+

sub is_item_index_failure:#Test(no_plan)
{
    diag ("is_item_index_failure") if $VERBOSE;
    my $self = shift;
    my $co = $self->{co};
    my $dbh = $co->get_dbh;
    my @failures = (1,4,6);
    my @non_failures=(2,3,5);
    foreach my $item_id (@failures)
    {
        ok ($co->is_item_index_failure($item_id),qq{item:$item_id is failure});
    }
    
    foreach my $item_id (@non_failures)
    {
        ok (!$co->is_item_index_failure($item_id),qq{item:$item_id is NOT an index failure});
    }

}


#=====================================================================
# Setup and teardown
#
# these are run before and after every test
#----------------------------------------------------------------------

sub A_create_test_tables:Test(setup=>no_plan)
{
    my $self = shift;
    $self->do_create_test_tables();
}

sub do_create_test_tables{
    my $self = shift;
    my $config = $self->{'config'};
    my $TEST_db_server   = $config->get('TEST_db_server' );
    my $db_name   = $config->get('db_name');
    my $db_user   = $config->get('db_user');
    my $db_passwd   = $config->get('db_passwd');
    
    my $create_SQL = 'make_test_tables.sql';
    
    $command = qq{mysql -h $TEST_db_server -u $db_user  $db_name -p$db_passwd} . ' < ' .  $create_SQL;

   # print "load command is $command\n";

    system $command;
}


sub B_get_co:Test(setup=>no_plan)
{
    diag("setting up co Collection ") if $DEBUG;
    my $self = shift;
    my $dbh = $self->_get_dbh();
    my $user_id = 'tburtonw';
    
    my $co= Collection->new($dbh,$self->{config},$user_id) ;

    $self->{co}=$co;
  if ($DEBUG)
    {
        $self->num_method_tests('B_get_co','2');
        $self->test_get_co($self->{co},$dbh);
     }

    
}

sub test_get_co
{
    my $self=shift;
    my $co=shift;
    my $dbh=shift;
        
    isa_ok($co, Collection,"Collection is set up");
    is ($co->get_dbh,$dbh,qq{dbh is ok});
}





#========================================================================
# STARTUP and TEARDOWN/SHUTDOWN 
# these are run once per test suite
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


sub C_get_dbh:Test(startup=>no_plan)
{
    my $self=shift;
    my $dbh = $self->_get_dbh();
    $self->{'dbh'}=$dbh;
    
}

sub A_finish:Test(shutdown=>no_plan)
{
    my $self = shift;
    #restore test tables to original state so we can us mysql to look at them outside of the test programs
    $self->do_create_test_tables();
    #close dbh here!!!
}

#======================================================================
#  utility routines
#======================================================================

# getters

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
sub get_item_table_name
{
    my $self = shift;
    return $self->{item_table_name};
}
#----------------------------------------------------------------------
sub get_config 
{
    my $self = shift;
    return $self->{'config'};
}

#----------------------------------------------------------------------
sub get_dbh
{
    my $self=shift;
    return $self->{'dbh'};
    
}

#----------------------------------------------------------------------------------------------

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

#----------------------------------------------------------------------------------------------

# private routine used by startup only
sub _get_dbh
{
    my $self = shift;
    
    my $config = $self->get_config();
    
    my $db_host = $config->get('TEST_db_server'); #'dev.mysql';
    my $db_name = $config->get('db_name');    #'dlxs';

    my $dbSourceName = join(':', 'DBI:mysql', $db_name,  $db_host);
    my $dbUser = $config->get('db_user');
    my $dbPassword = $config->get('db_passwd');

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
#----------------------------------------------------------------------------------------------

sub item_in_collection
{
    my $self = shift;
    my $item_id = shift;
    my $coll_id = shift;
    my $coll_item_table = $self->get_coll_item_table_name;
    my $dbh =  $self->get_dbh;
    
    

        my $statement = "SELECT count(*) FROM   $coll_item_table  WHERE MColl_ID = $coll_id and item_id = $item_id\;";
   
    
   my $sth = DbUtils::prep_n_execute($dbh, $statement);
   my $result = scalar($sth->fetchrow_array);
   $sth->finish;
    
   return  ($result > 0);
}
#----------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------


#----------------------------------------------------------------------------------------------



1;
