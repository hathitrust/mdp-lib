package Access::Holdings;

=head1 NAME

Access::Holdings;

=head1 DESCRIPTION

This package provides an interface to the Holdings Database tables
(mdp-holdings).

During updates to the PHDB, tables can be inaccessible. We return
held=0 if there are assertion failures in this case assuming that
this only affects a diminishingly small number of cases, rather that
affecting every user with an assertion failure.

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use Context;
use Utils;
use DbUtils;
use Debug::DUtils;

# ---------------------------------------------------------------------

=item id_is_held

Description

=cut

# ---------------------------------------------------------------------
sub id_is_held {
    my ($C, $id, $inst) = @_;

    my $held = 0;
    my $lock_id = $id;

    if (DEBUG('held')) {
        $held = 1;
    }
    elsif (DEBUG('notheld')) {
        $held = 0;
    }
    else {
        my $ses = $C->get_object('Session', 1);
        if ( $ses && defined $ses->get_transient("held.$id") ) { 
            ( $lock_id, $held ) = @{ $ses->get_transient("held.$id") }; 
            return ( $lock_id, $held );
        }

        my $dbh = $C->get_object('Database')->get_DBH($C);

        my $sth;

        # The lock ID depends on the item format:
        #   single part monograph (cluster_id present, no n_enum): cluster_id
        #   multi-part monograph (cluster_id and n_enum both present): cluster_id:n_enum
        #   serial (cluster id will not be present): volume_id
        my $SELECT_clause = <<EOT;
          SELECT lock_id,
                 sum(copy_count)
          FROM holdings_htitem_htmember h 
          JOIN ht_institutions t ON h.member_id = t.inst_id
          WHERE h.volume_id = ? AND mapto_inst_id = ?
          GROUP BY h.volume_id, mapto_inst_id;
EOT
        eval {
            $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id, $inst);
        };
        if (my $err = $@) {
            return ($err, 0);
        }

        my @row = $sth->fetchrow_array();
        ( $lock_id, $held ) = @row if ( scalar @row );
        $ses->set_transient("held.$id", [$lock_id, $held]) if ( $ses );
    }
    DEBUG('auth,all,held,notheld', qq{<h4>Holdings for inst=$inst id="$id": held=$held</h4>});

    return ( $lock_id, $held );
}

# ---------------------------------------------------------------------

=item id_is_held_and_BRLM

Description

=cut

# ---------------------------------------------------------------------
sub id_is_held_and_BRLM {
    my ($C, $id, $inst) = @_;

    my $held = 0;
    my $lock_id = $id;

    if (DEBUG('heldb')) {
        $held = 1;
    }
    elsif (DEBUG('notheldb')) {
        $held = 0;
    }
    else {
        my $ses = $C->get_object('Session', 1);
        if ( $ses && defined $ses->get_transient("held.brlm.$id") ) { 
            ( $lock_id, $held ) = @{ $ses->get_transient("held.brlm.$id") }; 
            return ( $lock_id, $held );
        }

        my $dbh = $C->get_object('Database')->get_DBH($C);

        my $sth;
        my $SELECT_clause = qq{SELECT lock_id, access_count FROM holdings_htitem_htmember h WHERE h.volume_id = ? AND member_id = ?};
        eval {
            $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id, $inst);
        };
        if ($@) {
            return 0;
        }

        my @row = $sth->fetchrow_array();
        ( $lock_id, $held ) = @row if ( scalar @row );
        $ses->set_transient("held.brlm.$id", [$lock_id, $held]) if ( $ses );
    }
    DEBUG('auth,all,heldb,notheldb', qq{<h4>BRLM holdings for inst=$inst id="$id": access_count=$held</h4>});

    # @OPB
    return ( $lock_id, $held );
}

# ---------------------------------------------------------------------

=item holding_institutions

Description

=cut

# ---------------------------------------------------------------------
sub holding_institutions {
    my ($C, $id) = @_;

    my $dbh = $C->get_object('Database')->get_DBH($C);

    my $sth;
    my $SELECT_clause = qq{SELECT member_id FROM holdings_htitem_htmember WHERE volume_id=?};
    eval {
        $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id);
    };
    if ($@) {
        return [];
    }

    my $ref_to_arr_of_arr_ref = $sth->fetchall_arrayref([0]);

    my $inst_arr_ref = [];
    if (scalar(@$ref_to_arr_of_arr_ref)) {
        $inst_arr_ref = [ map {$_->[0]} @$ref_to_arr_of_arr_ref ];
    }
    DEBUG('auth,all,held,notheld', qq{<h4>Holding institutions for id="$id": } . join(' ', @$inst_arr_ref) . q{</h4>});

    return $inst_arr_ref;
}

# ---------------------------------------------------------------------

=item holding_BRLM_institutions

Description

=cut

# ---------------------------------------------------------------------
sub holding_BRLM_institutions {
    my ($C, $id) = @_;

    my $dbh = $C->get_object('Database')->get_DBH($C);

    my $sth;
    my $SELECT_clause = qq{SELECT member_id FROM holdings_htitem_htmember WHERE volume_id=? AND access_count > 0};
    eval {
        $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id);
    };
    if ($@) {
        return [];
    }

    my $ref_to_arr_of_arr_ref = $sth->fetchall_arrayref([0]);

    my $inst_arr_ref = [];
    if (scalar(@$ref_to_arr_of_arr_ref)) {
        $inst_arr_ref = [ map {$_->[0]} @$ref_to_arr_of_arr_ref ];
    }
    DEBUG('auth,all,held,notheld', qq{<h4>Holding (BRLM) institutions for id="$id": } . join(' ', @$inst_arr_ref) . q{</h4>});

    return $inst_arr_ref;
}



1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011-12 ©, The Regents of The University of Michigan, All Rights Reserved

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
