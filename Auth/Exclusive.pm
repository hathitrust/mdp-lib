package Auth::Exclusive;


=head1 NAME

Auth::Exclusive

=head1 DESCRIPTION

This package provides an API to manage QUASI-exclusive access to a
digital item if one or more print copies are held by the user's
institution according to the Print Holdings Database (PHDB).

The access is granted for some period of time to meet the requirement
to allow as many simultaneous users of a digital object as there are
print copies held by the institution with which those users are
affiliated.

The caller must ensure that the volume rights and user
authentication/authorization is such that the user is entitled to gain
time-limited exclusive access to the volume. This package only
enforces exclusive access once there determinations have been made.

ALGORITHM

Definition of "M simultaneous users"

If for a given digital object, where institutions i1, i2, ..., iN that
hold number of print copies c1, c2, ..., cN of that object, then the
number M of simultaneous users over institutions is

i1*c1 + i2*c2 + ... + iN*cN

subject to the constraint that for users at a given institution ij
holding cj print copies, no more than cj users from ij are allowed at
once.

1) User A has access to the digital item if there is at least one
unconsumed print-holdings slot for the book for 24 hours dated from
his/her first access, i.e. repeated accesses within this 24 hour
period do not extend exclusivity beyond 24 hours from A's first
access.

2) User A's first access _after_ 24 hours extends access for another
24 hours UNLESS all remaining slots are consumed, e.g. user B accessed
the book before A accesses the book after the initial 24 hours to gain
another 24 hours of access. Now B has 24 hours of access and A loses
access. And so on.

The idea is to prevent one user gaining perpetual full view access to
the exclusion of all other users.

SCHEMA

 CREATE TABLE `pt_exclusivity` (
  `item_id`     varchar(32)  NOT NULL DEFAULT '',
  `owner`       varchar(256) NOT NULL DEFAULT '',
  `affiliation` varchar(128) NOT NULL DEFAULT '',
  `expires`     timestamp    NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`item_id`,`owner`,`affiliation`);

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
use Access::Holdings;

use List::Util;

## --- originally: 86400; # 24 hours in seconds
## 5 minutes in DEV; 1 hour otherwise
use constant EXCLUSIVITY_LIMIT => $ENV{HT_DEV} ? ( 5 / 60 ) * 60 * 60 : 60 * 60;

use Time::HiRes;

# ---------------------------------------------------------------------

=item acquire_exclusive_access

PUBLIC

If no one has exclusivity or someone who has exclusivity has exhaused
their 24 hours grant exclusivity.

If the grantee is usurping exclusivity from a former exclusive user,
delete the record for the former user otherwise renew exclusivity for
the former user for another EXCLUSIVITY_LIMIT.

=cut

# ---------------------------------------------------------------------
sub acquire_exclusive_access {
    my ($C, $item_id, $brlm) = @_;

    my $t0 = Time::HiRes::time();

    # Get current user's identity and expiration date
    my $dbh = $C->get_object('Database')->get_DBH();

    $dbh->{AutoCommit} = 0;

    # Get current user's identity and expiration date
    my ( $identity, $inst_code ) = ___get_user_identity($C);
    my ( $occupied, $owned, $active ) = ___get_affiliated_grants($C, $dbh, $item_id, $identity, $inst_code, 1);

    my $num_held =
      (
       $brlm
         ? Access::Holdings::id_is_held_and_BRLM($C, $item_id, $inst_code)
           : Access::Holdings::id_is_held($C, $item_id, $inst_code)
      );

    if ( ref $owned ) {
        $granted = 1;
        $owner = $identity;
        $expires = $$owned{expires};
        if ( Utils::Time::expired($expires) ) {
            # renew the grant
            $expires = ___renew($C, $dbh, $item_id, $identity, $inst_code);
        }
    } else {
        if ( scalar @$active < $num_held ) {
            $granted = 1;
            $owner = $identity;
            $expires = ___grant($C, $dbh, $item_id, $identity, $inst_code);
        }
    }

    ___cleanup_expired_grants($C, $dbh);

    $dbh->commit();
    $C->get_object('Session')->set_transient("$id.1", [ $granted, $owner, $expires ]) if ( $granted );

    print STDERR "BENCHMARK acquire_exclusive_access :: $granted :: $owner :: " . ( Time::HiRes::time() - $t0 ) . "\n";
    return ($granted, $owner, $expires);
}


# ---------------------------------------------------------------------

=item check_exclusive_access

PUBLIC

Like acquire_exclusive_access() except just tests for the possibility
of exclusive acquisition but does not assert exclusivity.

The $really flag make sure that they really have a grant rather
than just a possibility of a grant.

=cut

# ---------------------------------------------------------------------
sub check_exclusive_access {
    my ($C, $item_id, $brlm, $really) = @_;

    my $t0 = Time::HiRes::time();

    my $session = $C->get_object('Session');
    if ( $session->get_transient("$id.$really") ) {
        return @{ $session->get_transient("$id.$really"); }
    }

    my $dbh = $C->get_object('Database')->get_DBH();

    # Get current user's identity and expiration date
    my ( $identity, $inst_code ) = ___get_user_identity($C);
    my ( $occupied, $owned, $active ) = ___get_affiliated_grants($C, $dbh, $item_id, $identity, $inst_code);

    my ($granted, $owner, $expires);

    $granted = 0;

    if ( ref $owned ) {
        $granted = 1;
        $owner = $identity;
        $expires = $$owned{expired} ? ___get_expiration_date() : $$owned{expires};
    }

    unless ( $granted || $really ) {
        # could the user get the grant?
        my $num_held =
          (
           $brlm
             ? Access::Holdings::id_is_held_and_BRLM($C, $item_id, $inst_code)
               : Access::Holdings::id_is_held($C, $item_id, $inst_code)
          );

        # slots are available
        if ( scalar @$active < $num_held ) {
            $granted = 1;
            $owner = $identity;
            $expires = ___get_expiration_date();
        }
    }

    print STDERR "BENCHMARK check_exclusive_access :: $really :: $granted :: " . ( Time::HiRes::time() - $t0 ) . "\n";
    $session->set_transient("$id.$really", [ $granted, $owner, $expires ]);
    return ($granted, $owner, $expires);
}

# ---------------------------------------------------------------------

=item update_exclusive_access

PUBLIC

An unauthenticated user in a library can acquire exclusive access. If
that user then authenticates, update the exclusivity record with the
users new persistent ID so xe can continue to have access.

There is no need to update the institution code (affiliation field)
because if the user was in a library, SDRINST (institution code) will
have been set.

The current rules will not allow the implementation of support for
unauthenticated users outside a library to acquire exclusive
access. Their institution will be undef so here is no way to determine
number of copies held.

=cut

# ---------------------------------------------------------------------
sub update_exclusive_access {
    my ($C, $temporary_user_id, $persistent_user_id) = @_;

    # Get current user's identity and expiration date
    my $dbh = $C->get_object('Database')->get_DBH();
    my ($sth, $statement);

    $dbh->{AutoCommit} = 0;
    # Update owner field for all IDs
    $statement = qq{UPDATE pt_exclusivity SET owner=? WHERE owner=?};
    DEBUG('auth', qq{DEBUG: $statement : $persistent_user_id $temporary_user_id});
    $sth = DbUtils::prep_n_execute($dbh, $statement, $persistent_user_id, $temporary_user_id);

    $dbh->commit();
}

sub release_exclusive_access {
    my ($C, $item_id) = @_;
    my $dbh = $C->get_object('Database')->get_DBH();
    my ($sth, $statement);

    my $auth = $C->get_object('Auth');
    my $inst_code = $auth->get_institution_code($C, 'mapped');
    my $identity = $auth->get_user_name($C);

    $dbh->{AutoCommit} = 0;

    # Remove this grant
    $statement = qq{DELETE FROM pt_exclusivity WHERE owner=? AND affiliation=? AND item_id=?};
    DEBUG('auth', qq{DEBUG: $statement : $identity $isnt_code $item_id});
    $sth = DbUtils::prep_n_execute($dbh, $statement, $identity, $inst_code, $item_id);

    $dbh->commit();
}

# ---------------------------------------------------------------------

=item ___get_expiration_date

PRIVATE

=cut

# ---------------------------------------------------------------------
sub ___get_expiration_date {
    return Utils::Time::iso_Time('datetime', time() + EXCLUSIVITY_LIMIT);
}


sub ___get_user_identity {
    my ( $C ) = @_;
    my $auth = $C->get_object('Auth');
    my $inst_code = $auth->get_institution_code($C, 'mapped');
    my $identity = $auth->get_user_name($C);
    return ( $identity, $inst_code );
}

sub ___get_affiliated_grants {
    my ( $C, $dbh, $item_id, $identity, $inst_code, $updating ) = @_;
    my $sql = qq{SELECT *, ( expires < NOW() ) AS expired FROM pt_exclusivity WHERE item_id = ? AND affiliation = ?};
    if ( $updating ) { $sql .= qq{ FOR UPDATE}; }

    my $occupied = $dbh->selectall_arrayref(
        $sql,
        {Slice=>{}},
        $item_id, $inst_code);

    my $owned = List::Util::first { $$_{owner} eq $identity } @$occupied;
    my $active = [ grep { ! $$a{expired} } @$occupied ];

    return ( $occupied, $owned, $active );

}

# ---------------------------------------------------------------------

=item ___grant

PRIVATE

=cut

# ---------------------------------------------------------------------
sub ___grant {
    my ($C, $dbh, $id, $identity, $inst_code) = @_;

    my $expiration_date = ___get_expiration_date();

    my $statement =
        qq{INSERT INTO pt_exclusivity SET item_id=?, owner=?, affiliation=?, expires=?};
    DEBUG('auth', qq{DEBUG: $statement : $id : $identity : $inst_code : $expiration_date});
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $id, $identity, $inst_code, $expiration_date);

    return $expiration_date;
}

# ---------------------------------------------------------------------

=item ___renew

PRIVATE

Same item may be exclusively owned by users with different affiliations.

=cut

# ---------------------------------------------------------------------
sub ___renew {
    my ($C, $dbh, $id, $identity, $inst_code) = @_;

    my $expiration_date = ___get_expiration_date();

    my $statement =
        qq{UPDATE pt_exclusivity SET expires=? WHERE item_id=? AND owner=? AND affiliation=?};
    DEBUG('auth', qq{DEBUG: $statement : $expiration_date : $id : $identity : $inst_code});
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $expiration_date, $id, $identity, $inst_code);

    return $expiration_date;
}

# ---------------------------------------------------------------------

=item ___cleanup_expired_grants

PRIVATE

=cut

# ---------------------------------------------------------------------
sub ___cleanup_expired_grants {
    my ($C, $dbh) = @_;

    my $now = Utils::Time::iso_Time();

    my $statement = qq{DELETE FROM pt_exclusivity WHERE expires < ?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $now);

    Utils::map_chars_to_cers(\$statement, [q{"}, q{'}]);
    DEBUG('auth', qq{DEBUG: $statement : $now});
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2010-12 ©, The Regents of The University of Michigan, All Rights Reserved

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
