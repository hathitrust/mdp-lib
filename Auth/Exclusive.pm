package Auth::Exclusive;


=head1 NAME

Auth::Exclusive

=head1 DESCRIPTION

This package provides an API to manage exclusive access for a given
user to an item for some period of time to meet the legal requirement
of one simultaneous user for certain kinds of material.

This is currently just for in-copyright out-of-print brittle (OPB)
volumes.

The caller must ensure that the volume rights and user
authentication/authorization is such that the user is entitled to gain
time-limited exclusive access to the volume. This package only
enforces exclusive access once there determinations haev been made.

ALGORITHM

If the rights attribute for a volume is opb and the user is a Shib
authenticated affiliate of UM (not a friend account!), then full view
access is granted, subject to the "one simultaneous user" requirement.

Definition of "one simultaneous user"

1) User A has exclusive access to the opb book for 24 hours dated from
his/her first access, i.e. repeated accesses within this 24 hour period
do not extend exclusivity beyond 24 hours from A's first access.

2) User A's first access _after_ 24 hours extends exclusivity for
another 24 hours UNLESS user B accessed the book before A accesses the
book after the initial 24 hours to gain another 24 hours of
exclusivity. Now B has 24 hours of exclusivity and A loses access. And
so on.

The idea is to prevent one user gaining perpetual full view access to
the exclusion of all other users.

SCHEMA

CREATE TABLE `n_exclusivity` (
        `item_id`  varchar(32)  NOT NULL default '',
        `owner`    varchar(256) NULL,
        `expires`  timestamp    NOT NULL default '0000-00-00 00::00::00',
  PRIMARY KEY (`item_id`, `owner`));


=head1 VERSION

$Id: Exclusive.pm,v 1.2 2010/04/28 18:13:54 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use Context;
use Database;
use Utils;
use Utils::Time;
use Debug::DUtils;
use DbUtils;

use constant EXCLUSIVITY_LIMIT => 86400; # 24 hours in seconds


# ---------------------------------------------------------------------

=item acquire_exclusive_access

If no one has exclusivity or someone who has exclusivity has exhaused
their 24 hours grant exclusivity.

If the grantee is usurping exclusivity from a former exclusive user,
delete the record for the former user otherwise renew exclusivity for
the former user for another EXCLUSIVITY_LIMIT.

=cut

# ---------------------------------------------------------------------
sub acquire_exclusive_access {
    my ($C, $item_id, $identity, $affiliation) = @_;

    # Get current user's identity and expiration date
    my $dbh = $C->get_object('Database')->get_DBH();
    my ($granted, $owner, $expires) = __grant_access($C, $dbh, $item_id, $identity, $affiliation, 1);

    return ($granted, $owner, $expires);
}


# ---------------------------------------------------------------------

=item check_exclusive_access

Like acquire_exclusive_access() except just tests for the possibility
of exclusive acquisition but does not assert exclusivity.

=cut

# ---------------------------------------------------------------------
sub check_exclusive_access {
    my ($C, $item_id, $identity) = @_;

    # Get current user's identity and expiration date
    my $dbh = $C->get_object('Database')->get_DBH();
    my ($granted, $owner, $expires) = __grant_access($C, $dbh, $item_id, $identity, 0);

    return ($granted, $owner, $expires);
}

# ---------------------------------------------------------------------

=item __grant_access

An item can be owned by more than one user if their affiliations are
different.

=cut

# ---------------------------------------------------------------------
sub __grant_access {
    my ($C, $dbh, $id, $identity, $affiliation, $assert_ownership) = @_;

    my $granted = 0;
    my $grant_owner;
    my $expires;
    
    # Failsafe
    if ((! $identity) || (! $affiliation)) {
        return ($granted, $grant_owner, $expires);
    }
        
    my ($sth, $statement);

    $statement = qq{LOCK TABLES n_exclusivity WRITE};
    DEBUG('auth', qq{DEBUG: $statement});
    $sth = DbUtils::prep_n_execute($dbh, $statement);

    # Get all rows matching id in affiliation-namespace of identity 
    $statement = qq{SELECT * FROM n_exclusivity WHERE item_id='$id' AND affiliation='$affiliation'};
    DEBUG('auth', qq{DEBUG: $statement});
    $sth = DbUtils::prep_n_execute($dbh, $statement);

    my $id_arr_hashref = $sth->fetchall_arrayref({});
    if (! defined($id_arr_hashref)) {
        # item not owned in this affiliation-namespace. grant
        # ownership to identity
        $granted = 1;
        $grant_owner = $identity;

        if ($assert_ownership) {
            $expires = ___grant($C, $dbh, $id, $grant_owner, $affiliation);
        }
        else {
            $expires = ___get_expiration_date();
        }
    }
    else {
        # item exists in affiliation-namespace of identity, see who
        # owns it and for how much longer. Note only one owner per
        # namespace by design.
        my $curr_owner = $id_arr_hashref->[0]->{'owner'};
        my $expiration_date = $id_arr_hashref->[0]->{'expires'};

        # identity is current owner
        if ($curr_owner eq $identity) {
            $granted = 1;
            $grant_owner = $curr_owner;

            if ($assert_ownership) {
                if (Utils::Time::expired($expiration_date)) {
                    # renew item for this affiliation only after last
                    # grant has expired.
                    $expires = ___renew($C, $dbh, $item_id, $affiliation);
                }
                else {
                    $expires = $expiration_date;
                }
            }
            else {
                $expires = ___get_expiration_date();
            }
        }
        else {
            # identity is someone else. Acquire access if the
            # current owner's grant has expired
            if (Utils::Time::expired($expiration_date)) {
                # acquire
                $granted = 1;
                $grant_owner = $identity;
                
                if ($assert_ownership) {
                    $expires = ___acquire($C, $dbh, $id, $grant_owner, $affiliation);
                }
                else {
                    $expires = ___get_expiration_date();
                }
            }
            else {
                # deny
                $granted = 0;
                $grant_owner = $curr_owner;
                $expires = $expiration_date;
            }
        }
        
    }

    # clean up expired grants for access that were not renewed or acquired by
    # this request
    if ($assert_ownership) {
        ___cleanup_expired_grants($C, $dbh);
    }

    $statement = qq{UNLOCK TABLES};
    DEBUG('auth', qq{DEBUG: $statement});
    $sth = DbUtils::prep_n_execute($dbh, $statement);

    ASSERT(defined($grant_owner), qq{grant owner undefined in __grant_access()});

    return ($granted, $grant_owner, $expires);
}


# ---------------------------------------------------------------------

=item ___get_expiration_date

Description

=cut

# ---------------------------------------------------------------------
sub ___get_expiration_date {
    return Utils::Time::iso_Time('datetime', time() + EXCLUSIVITY_LIMIT);
}
    
# ---------------------------------------------------------------------

=item ___acquire

Description

=cut

# ---------------------------------------------------------------------
sub ___acquire {
    my ($C, $dbh, $id, $new_owner, $affiliation) = @_;

    my $statement = qq{DELETE FROM n_exclusivity WHERE item_id='$id' AND affiliation='$affiliation'};
    DEBUG('auth', qq{DEBUG: $statement});
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    return ___grant($C, $dbh, $id, $new_owner, $affiliation);
}

# ---------------------------------------------------------------------

=item ___grant

Description

=cut

# ---------------------------------------------------------------------
sub ___grant {
    my ($C, $dbh, $id, $identity, $affiliation) = @_;

    my $expiration_date = ___get_expiration_date();

    my $statement =
        qq{INSERT INTO n_exclusivity SET item_id='$id', owner='$identity', affiliation='$affiliation', expires='$expiration_date'};
    DEBUG('auth', qq{DEBUG: $statement});
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    return $expiration_date;
}

# ---------------------------------------------------------------------

=item ___renew

Same item may be exclusively owned by users with different affiliations.

=cut

# ---------------------------------------------------------------------
sub ___renew {
    my ($C, $dbh, $id, $affiliation) = @_;

    my $expiration_date = ___get_expiration_date();

    my $statement =
        qq{UPDATE n_exclusivity SET expires='$expiration_date' WHERE item_id='$id' AND affiliation='$affiliation'};
    DEBUG('auth', qq{DEBUG: $statement});
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    return $expiration_date;
}

# ---------------------------------------------------------------------

=item ___cleanup_expired_grants

Description

=cut

# ---------------------------------------------------------------------
sub ___cleanup_expired_grants {
    my ($C, $dbh) = @_;

    my $now = Utils::Time::iso_Time();

    my $statement = qq{DELETE FROM n_exclusivity WHERE expires < '$now'};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    Utils::map_chars_to_cers(\$statement, [q{"}, q{'}]);
    DEBUG('auth', qq{DEBUG: $statement});
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2010 ©, The Regents of The University of Michigan, All Rights Reserved

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
