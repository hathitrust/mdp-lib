package Access::Holdings;

=head1 NAME

Access::Holdings;

=head1 DESCRIPTION

This package provides an interface to the Holdings Database tables (mdp-holdings.)

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

    if (DEBUG('held')) {
        $held = 1;
    }
    elsif (DEBUG('notheld')) {
        $held = 0;
    }
    else {
        my $dbh = $C->get_object('Database')->get_DBH($C);

        my $sth;
        my $SELECT_clause = qq{SELECT copy_count FROM holdings_htitem_htmember WHERE volume_id=? AND member_id=?};
        eval {
            $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id, $inst);
        };
        if ($@) {
            return 0;
        }
        
        $held = $sth->fetchrow_array() || 0;
    }
    DEBUG('auth,all,held,notheld', qq{<h4>Holdings for inst=$inst id="$id": held=$held</h4>});

    return $held;
}

# ---------------------------------------------------------------------

=item id_is_held_and_BRLM

Description

=cut

# ---------------------------------------------------------------------
sub id_is_held_and_BRLM {
    my ($C, $id, $inst) = @_;

    my $held = 0;

    if (DEBUG('heldb')) {
        $held = 1;
    }
    elsif (DEBUG('notheldb')) {
        $held = 0;
    }
    else {
        my $dbh = $C->get_object('Database')->get_DBH($C);

        my $sth;
        my $SELECT_clause = qq{SELECT access_count FROM holdings_htitem_htmember WHERE volume_id=? AND member_id=?};
        eval { 
            $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id, $inst);
        };
        if ($@) {
            return 0;
        }
        
        $held = $sth->fetchrow_array() || 0;
    }
    DEBUG('auth,all,heldb,notheldb', qq{<h4>BRLM holdings for inst=$inst id="$id": access_count=$held</h4>});

    # @OPB
    return $held;
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
