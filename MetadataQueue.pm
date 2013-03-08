package MetadataQueue;


=head1 NAME

SharedQueue;

=head1 DESCRIPTION

This package contains code to provide access to
slip_metadata_update_queue on behalf of Collection Builder and SLIP.

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

=item enqueue_metadata_item_id

Description

=cut

# ---------------------------------------------------------------------
sub enqueue_metadata_item_id {
    my ($C, $dbh, $id) = @_;

    my $ok = 1;
    my ($sth, $statement);

    eval {
        $statement = qq{LOCK TABLES slip_metadata_update_queue WRITE};
        DEBUG('lsdb,dbcoll', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        $statement = qq{INSERT INTO slip_metadata_update_queue SET id=?, time=NOW()};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement, $id);

        $statement = qq{UNLOCK TABLES};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);
    };
    if ($@) {
        $ok = 0;
    }

    return $ok;
}

# ---------------------------------------------------------------------

=item enqueue_metadata_item_id

Description

=cut

# ---------------------------------------------------------------------
sub enqueue_metadata_item_id_array {
    my ($C, $dbh, $id_arr_ref) = @_;

    my $ok = 1;
    my ($sth, $statement);

    eval {
        $statement = qq{LOCK TABLES slip_metadata_update_queue WRITE};
        DEBUG('lsdb,dbcoll', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        while (1) {
            my $id = shift @$id_arr_ref;
            last unless(defined $id);

            $statement = qq{INSERT INTO slip_metadata_update_queue SET id=?, time=NOW()};
            DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
            $sth = DbUtils::prep_n_execute($dbh, $statement, $id);
        }

        $statement = qq{UNLOCK TABLES};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);
    };
    if ($@) {
        $ok = 0;
    }

    return $ok;
}

# ---------------------------------------------------------------------

=item get_next_metadata_item_id

Description

=cut

# ---------------------------------------------------------------------
sub get_next_metadata_item_id {
    my ($C, $dbh) = @_;

    my $ok = 1;

    my $id;
    my ($sth, $statement);

    eval {
        $statement = qq{LOCK TABLES slip_metadata_update_queue WRITE};
        DEBUG('lsdb,dbcoll', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        $statement = qq{SELECT id FROM slip_metadata_update_queue LIMIT 1};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        $id = $sth->fetchrow_array();

        $statement = qq{UNLOCK TABLES};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);
    };
    if ($@) {
        $ok = 0;
    }

    return ($ok, $id);
}


# ---------------------------------------------------------------------

=item dequeue_id_from_metadata_queue

Description

=cut

# ---------------------------------------------------------------------
sub dequeue_id_from_metadata_queue {
    my ($C, $dbh, $id) = @_;

    my $ok = 1;
    my ($sth, $statement);

    eval {
        $statement = qq{LOCK TABLES slip_metadata_update_queue WRITE};
        DEBUG('lsdb,dbcoll', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);

        $statement = qq{DELETE FROM slip_metadata_update_queue WHERE id=?};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement, $id);

        $statement = qq{UNLOCK TABLES};
        DEBUG('dbcoll,lsdb', qq{DEBUG: $statement});
        $sth = DbUtils::prep_n_execute($dbh, $statement);
    };
    if ($@) {
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
