package SharedQueue;


=head1 NAME

SharedQueue;

=head1 DESCRIPTION

This package contains code to provide access to slip_shared_queue on
behalf of Collection Builder and SLIP.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use Context;
use Utils;
use Debug::DUtils;

# ---------------------------------------------------------------------

=item get_large_coll_coll_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_large_coll_coll_ids {
    my ($C, $dbh) = @_;

    my $ok = 1;
    my ($sth, $statement);

    my $config = $C->get_object('MdpConfig');
    my $use_test_tables = DEBUG('usetesttbl') || $config->get('use_test_tables');

    my $coll_table_name = $use_test_tables ? $config->get('test_coll_table_name') : $config->get('coll_table_name');
    my $small_collection_max_items = $config->get('filter_query_max_item_ids');

    my $coll_id_arr_ref = [];
    
    eval {
        $statement = qq{SELECT MColl_ID FROM $coll_table_name WHERE num_items > $small_collection_max_items};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        my $ref_to_arr_of_arr_ref = $sth->fetchall_arrayref([0]);
        if (scalar(@$ref_to_arr_of_arr_ref)) {
            $coll_id_arr_ref = [ map {$_->[0]} @$ref_to_arr_of_arr_ref ];
        }
    };
    if ($@) {
        $ok = 0;
    }
    
    return ($ok, $coll_id_arr_ref);
}

# ---------------------------------------------------------------------

=item get_coll_ids_for_id

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_ids_for_id {
    my ($C, $dbh, $id) = @_;

    my $ok = 1;
    my ($sth, $statement);

    my $config = $C->get_object('MdpConfig');
    my $use_test_tables = DEBUG('usetesttbl') || $config->get('use_test_tables');

    my $coll_item_table_name = 
      $use_test_tables 
        ? $config->get('test_coll_item_table_name')
          : $config->get('coll_item_table_name');

    my $coll_id_arr_ref = [];
    
    eval {
        $statement = qq{SELECT MColl_id FROM $coll_item_table_name WHERE extern_item_id=?};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement, $id);

        my $ref_to_arr_of_arr_ref = $sth->fetchall_arrayref([0]);
        if (scalar(@$ref_to_arr_of_arr_ref)) {
            $coll_id_arr_ref = [ map {$_->[0]} @$ref_to_arr_of_arr_ref ];
        }
    };
    if ($@) {
        $ok = 0;
    }
    
    return ($ok, $coll_id_arr_ref);
}

# ---------------------------------------------------------------------

=item count_shared_queue_ids

Description

=cut

# ---------------------------------------------------------------------
sub count_shared_queue_ids {
    my ($C, $dbh) = @_;

    my $statement = qq{SELECT count(*) FROM slip_shared_queue};
    DEBUG('lsdb', qq{DEBUG: $statement});
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    my $num = $sth->fetchrow_array || 0;

    return $num;
}

# ---------------------------------------------------------------------

=item enqueue_item_ids

Description: Item array could be as large as 100 items

=cut

# ---------------------------------------------------------------------
sub enqueue_item_ids {
    my ($C, $dbh, $id_arr_ref) = @_;

    my $ok = 1;
    my ($sth, $statement);

    DbUtils::begin_work($dbh);
    eval {

        my @values;
        foreach my $v (@$id_arr_ref) {
            # push(@values, q{(} . $dbh->quote($v) . q{,NOW()} . q{)});
            push(@values, qq{(?, NOW())});
        }
        my $values_str = join(qq{,}, @values);

        $statement = qq{REPLACE INTO slip_shared_queue (`id`, `time`) VALUES $values_str};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement, @$id_arr_ref);

        DbUtils::commit($dbh);

    };
    if (my $err = $@) {
        eval { $dbh->rollback; };
        soft_ASSERT(0, qq{Problem with enqueue_item_ids: $err});
        $ok = 0;
    }
    
    return $ok;
}

# ---------------------------------------------------------------------

=item enqueue_all_ids

Description

=cut

# ---------------------------------------------------------------------
sub enqueue_all_ids {
    my ($C, $dbh, $coll_id) = @_;

    my $ok = 1;
    my ($sth, $statement);

    my $config = $C->get_object('MdpConfig');
    my $use_test_tables = DEBUG('usetesttbl') || $config->get('use_test_tables');

    my $coll_item_table_name = 
      $use_test_tables 
        ? $config->get('test_coll_item_table_name')
          : $config->get('coll_item_table_name');

    DbUtils::begin_work($dbh);
    eval {
        
        my $SELECT_clause = qq{SELECT extern_item_id AS `id`, NOW() AS `time` FROM $coll_item_table_name WHERE MColl_id=?};
        $statement = qq{REPLACE INTO slip_shared_queue ($SELECT_clause)};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement, $coll_id);

        DbUtils::commit($dbh);
    };
    if (my $err = $@) {
        $dbh->rollback();
        soft_ASSERT(0, qq{Problem with enqueue_all_ids: $err});
        $ok = 0;
    }
    
    return $ok;
}

# ---------------------------------------------------------------------

=item read_queued_item_ids

Description

=cut

# ---------------------------------------------------------------------
sub read_queued_item_ids {
    my ($C, $dbh, $slice_size, $offset) = @_;

    my $ok = 1;
    my ($sth, $statement);

    my $id_arr_ref = [];
    
    eval {
        # $statement = qq{LOCK TABLES slip_shared_queue WRITE};
        # DEBUG('lsdb,dbcoll', qq{DEBUG: $statement});
        # $sth = DbUtils::prep_n_execute($dbh, $statement);

        $statement = qq{SELECT id FROM slip_shared_queue LIMIT $offset, $slice_size};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        my $ref_to_arr_of_arr_ref = $sth->fetchall_arrayref([0]);
        if (scalar(@$ref_to_arr_of_arr_ref)) {
            $id_arr_ref = [ map {$_->[0]} @$ref_to_arr_of_arr_ref ];
        }

        # $statement = qq{UNLOCK TABLES};
        # DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        # $sth = DbUtils::prep_n_execute($dbh, $statement);
    };
    if ($@) {
        $ok = 0;
    }
    
    return ($ok, $id_arr_ref);
}

# ---------------------------------------------------------------------

=item dequeue_item_ids

Description

=cut

# ---------------------------------------------------------------------
sub dequeue_item_ids {
    my ($C, $dbh, $slice_size) = @_;

    my $ok = 1;
    my ($sth, $statement);

    my $id_arr_ref = [];
    
    DbUtils::begin_work($dbh);
    eval {

        $statement = qq{SELECT id FROM slip_shared_queue LIMIT $slice_size};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        my $ref_to_arr_of_arr_ref = $sth->fetchall_arrayref([0]);
        if (scalar(@$ref_to_arr_of_arr_ref)) {
            $id_arr_ref = [ map {$_->[0]} @$ref_to_arr_of_arr_ref ];

            my @values;
            foreach my $v (@$id_arr_ref) {
                push @values, '?';
            }
            my $values_str = join(qq{,}, @values);

            $statement = qq{DELETE FROM slip_shared_queue WHERE id IN ($values_str)};
            DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
            $sth = DbUtils::prep_n_execute($dbh, $statement, @$id_arr_ref);
        }

        DbUtils::commit($dbh);
    };
    if (my $err = $@) {
        soft_ASSERT(0, qq{Problem with dequeue_item_ids: $err});
        $ok = 0;
    }
    
    return ($ok, $id_arr_ref);
}

# ---------------------------------------------------------------------

=item Delete_id_from_j_shared_queue

Description

=cut

# ---------------------------------------------------------------------
sub Delete_id_from_j_shared_queue {
    my ($C, $dbh, $id) = @_;

    my $ok = 1;
    my ($sth, $statement);

    DbUtils::begin_work($dbh);
    eval {

        $statement = qq{DELETE FROM slip_shared_queue WHERE id=?};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement, $id);

        DbUtils::commit($dbh);
    };
    if (my $err = $@) {
        soft_ASSERT(0, qq{Problem with Delete_id_from_j_shared_queue: $err});
        $ok = 0;
    }
    
    return $ok;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011 ©, The Regents of The University of Michigan, All Rights Reserved

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
