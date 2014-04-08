package Auth::ACL;

=head1 NAME

Auth::ACL

=head1 DESCRIPTION

This package encapsulates access to the Access Control List. It
determines whether a user has authorization to access in-copyright
materials, use debugging functions, download as a proxy for
print-disabled users, etc.

DATABASE INTERFACE

The database section of the package is an interface to
ht_repository.ht_users.  Certain DEBUG switches are implemented
here and override the ACL.

   CREATE TABLE `ht_users` (
      `userid`      varchar(256)  NOT NULL DEFAULT '',
      `displayname` varchar(128)           DEFAULT NULL,
      `email`       varchar(128)           DEFAULT NULL,
      `supemail`    varchar(128)           DEFAULT NULL,
      `approver`    varchar(128)           DEFAULT NULL,
      `authorizer`  varchar(128)           DEFAULT NULL,
      `usertype`    varchar(32)            DEFAULT NULL,
      `role`        varchar(32)            DEFAULT NULL,
      `access`      varchar(32)            DEFAULT 'normal',
      `expires`     timestamp     NOT NULL DEFAULT '0000-00-00 00:00:00',
      `iprestrict`  varchar(1024)          DEFAULT NULL,
      `vpn`         tinyint(1)    NOT NULL DEFAULT '0',
      PRIMARY       KEY (`userid`));

Subroutines prefixed with '__' are private and should only be called
from within the Auth::ACL package.

'usertype' values are 'staff' (UM), 'student' (UM), 'external' (non-UM)

'role' is a subclass of 'usertype'

 SELECT DISTINCT usertype, role FROM ht_users;

 +----------+--------------+---------+
 | usertype | role         | access  |
 +----------+--------------+---------+
 | staff    | generalhathi | total   | UM staff
 | staff    | cataloging   | total   | UM staff
 | external | crms         | total   | non-UM engaged in CRMS and CRMS World activities
 | staff    | crms         | total   | UM staff engaged in CRMS and CRMS World activities
 | staff    | superuser    | total   | UM staff (developers)
 | staff    | orphan       | total   | UM staff engaged in the Orphan Works project
 | staff    | quality      | total   | UM staff engaged in the Qual project
 | external | quality      | total   | non-UM engaged in the Qual project
 | staff    | digitization | total   | UM staff at DCU
 |----------+--------------+---------+
 | student  | ssd          | normal  | UM student on SSD list *not locked to any IP address*
 | external | ssdproxy     | normal  | non-UM Human Proxy for print-disabled user
 | external | ssdnfb       | normal  | non-UM National Federation of the Blind Proxy for print-disabled user
 +----------+--------------+---------+

'normal' access excludes attr=8 (nobody)

=head1 SYNOPSIS

Coding example

=head1 IP RANGES

Wed Apr  2 13:33:34 2014

All users except 'role'='ssd' are locked to one or more single IP
addresses (no ranges). Users with 'vpn'=1 are also permitted to the
vpn range

 141.211.84.128/25   141.211.84.129  - 141.211.84.254  - Library VPN

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use Context;
use Utils;
use Debug::DUtils;
use Utils::Time;
use Database;
use DbUtils;

my $library_vpn_range = q{^(141\.211\.84\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4])))$};

# blocked
my $iprestrict_all = 'notanipaddress';

# unrestricted (SSD only, after Wed Apr  2 13:42:55 2014)
my $iprestrict_none = '.*';

my $ZERO_TIMESTAMP = '0000-00-00 00:00:00';
my $GLOBAL_EXPIRE_DATE = '2014-12-31 23:59:59';



# ---------------------------------------------------------------------

=item ___get_ACL, ___set_ACL

Needed for persistent clients, e.g. imgsrv.

=cut

# ---------------------------------------------------------------------
sub ___get_ACL {
    my $C = new Context;
    my $Access_Control_List_ref = ( $C->has_object('Auth::ACL') ? $C->get_object('Auth::ACL') : {} );
    return $Access_Control_List_ref;
}
sub ___set_ACL {
    my $acl_ref = shift;

    my $C = new Context;
    bless $acl_ref, 'Auth::ACL';

    $C->set_object('Auth::ACL', $acl_ref);
}

# ---------------------------------------------------------------------

=item a_GetUserAttributes

PUBLIC

This entry point provides access to ACL attributes and centralizes and
debugging switch overrides.

NOTE: Does not do authorization.  That is, does not test whether the
user is coming from the correct IP address, for example, but is
affected by debugging switches.

=cut

# ---------------------------------------------------------------------
sub a_GetUserAttributes {
    my $requested_attribute = shift;
    __load_access_control_list();

    return '' unless(defined $requested_attribute);
    return __get_user_attributes($requested_attribute);
}

# ---------------------------------------------------------------------

=item __a_Autorized_core

PRIVATE

=cut

# ---------------------------------------------------------------------
sub __a_Autorized_core {
    my $access_ref = shift;
    my $unmasked = shift;

    return 0 unless(ref $access_ref eq 'HASH');
    return 0 unless(scalar keys %$access_ref == 1);

    my $authorized = 0;
    my $ipaddr = $ENV{REMOTE_ADDR};

    my $usertype = __get_user_attributes('usertype', $unmasked);
    my $role = __get_user_attributes('role', $unmasked);
    my $ip_range = __get_user_attributes('iprestrict', $unmasked);
    my $expiration_date = __get_user_attributes('expires', $unmasked);
    my $access = __get_user_attributes('access', $unmasked);

    my ($key) = keys %$access_ref;

    # See if user is in ACL
    if ($usertype) {
        # Check expiration
        if (! Utils::Time::expired($expiration_date)) {
            # Not expired. correct IP?
            if ($ipaddr =~ m/$ip_range/) {
                # Limit to certain roles or access
                my ($key) = keys %$access_ref;
                if ( $access_ref->{$key} eq __get_user_attributes($key, $unmasked) ) {
                    $authorized = 1;
                }
            }
        }
    }

    return $authorized;
}

# ---------------------------------------------------------------------

=item a_Authorized

PUBLIC

This entry point centralizes ACL-based authorization and debugging
switch overrides.

=cut

# ---------------------------------------------------------------------
sub a_Authorized {
    my $access_ref = shift;
    __load_access_control_list();

    my $authorized = __a_Autorized_core($access_ref);
    my ($key) = keys %$access_ref;
    my $test_case = '(test: ' . $key . '=>' . $access_ref->{$key} . ' am: ' . __get_user_attributes($key) . ')';

    __debug_acl($authorized, $test_case);
    return $authorized;
}


# ---------------------------------------------------------------------

=item S___superuser_using_DEBUG_super

This predicate allows a user with role=superuser using DEBUG('super')
to gain access PDF download and EBM for restricted materials while
not altering attribute values returned from __get_user_attributes().

=cut

# ---------------------------------------------------------------------
sub S___superuser_using_DEBUG_super {
    __load_access_control_list();

    my $superuser = DEBUG('super') && __a_Autorized_core( {role => 'superuser'}, 'unmasked' );
    return $superuser;
}

# ---------------------------------------------------------------------

=item S___total_access_using_DEBUG_super

This predicate allows a user with access=total and using
DEBUG('super') to gain access restricted materials while not being
able to alter attribute values returned from
__get_user_attributes(). Typically CRMS users, among others.

=cut

# ---------------------------------------------------------------------
sub S___total_access_using_DEBUG_super {
    __load_access_control_list();

    my $total = DEBUG('super') && __a_Autorized_core( {access => 'total'}, 'unmasked' );
    return $total;
}

# ---------------------------------------------------------------------

=item S___superuser_role

This predicate allows a user with role=superuser to:

1. force changes to attribute values using the DEBUG switches coded in
__get_user_attributes() making the user appear to be, e.g. a
print-disabled user.

2. force changes to rights_current.{attr,source} values using
local.conf

=cut

# ---------------------------------------------------------------------
sub S___superuser_role {
    __load_access_control_list();

    my $superuser = __a_Autorized_core( {role => 'superuser'}, 'unmasked' );
    return $superuser;
}

# ---------------------------------------------------------------------

=item S___total_access

This predicate exists to allow the use of certain DEBUG switches,
specifically DEBUG=super to permit access to restricted materials, for
users that have high authorization in the ACL but who are not
superusers.

That is, by CRMS users whose access must include restricted material,
even attr=nobody, but who are not permitted to download PDF/EBM.

=cut

# ---------------------------------------------------------------------
sub S___total_access {
    __load_access_control_list();

    my $total = __a_Autorized_core( {access => 'total'}, 'unmasked' );
    return $total;
}

# ---------------------------------------------------------------------

=item __get_remote_user

Description

=cut

# ---------------------------------------------------------------------
sub __get_remote_user {
    my $remote_user = '';
    if ( exists($ENV{REMOTE_USER}) ) {
        $remote_user = lc $ENV{REMOTE_USER};
    }
    return $remote_user;
}

# ---------------------------------------------------------------------

=item __debug_acl

Description

=cut

# ---------------------------------------------------------------------
my $__b_debug_printed = 0;

sub __debug_acl {
    my $authorized = shift;
    my $test_case = shift;

    my $Access_Control_List_ref = ___get_ACL;

    # masked data to reflect effect of debugging switches.
    DEBUG('auth,all',
          sub {
              my $ipaddr = $ENV{REMOTE_ADDR} || '';
              my $userid = __get_remote_user();
              my $usertype = __get_user_attributes('usertype');
              my $role = __get_user_attributes('role');
              my $access = __get_user_attributes('access');
              my $expires = __get_user_attributes('expires');

              my $superuser = S___superuser_role() ? '(<font color="green">superuser</font>)' : '';
              $authorized = $authorized ? '<font color="blue">1</font>' : '0';

              #   0         1          2      3            4         5           6          7            8       9         10
              my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(6);
              my $s = qq{<h3 style="text-align:left">ACL AUTH[$subroutine]$superuser: authorized=$authorized $test_case, IP=$ipaddr, userid=$userid usertype=$usertype role=$role access=$access expires=$expires</h3>};
              return $s;
          });

    # unmasked data to dump actual state of table
    DEBUG('acl',
          sub {
              return '' if $__b_debug_printed;
              my $s = '';
              my @userids = keys %$Access_Control_List_ref;
              foreach my $userid (sort @userids) {
                  my $usertype   = $Access_Control_List_ref->{$userid}{usertype};
                  my $role       = $Access_Control_List_ref->{$userid}{role};
                  my $access     = $Access_Control_List_ref->{$userid}{access};
                  my $iprestrict = $Access_Control_List_ref->{$userid}{iprestrict};
                  my $vpn        = $Access_Control_List_ref->{$userid}{vpn};
                  my $expires    = $Access_Control_List_ref->{$userid}{expires};
                  my $name       = $Access_Control_List_ref->{$userid}{displayname};

                  $s .= qq{<h3 style="text-align:left">ACL DUMP: userid=$userid name=$name expires=$expires type=$usertype role=$role access=$access vpn=<font color="red">$vpn</font> <font color="blue">ip=$iprestrict </font></h3>};
              }
              $__b_debug_printed = 1;
              return $s;
          });
}

# ---------------------------------------------------------------------
#
#                D a t a b a s e     I n t e r f a c e
#
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------

=item __get_user_attributes

PRIVATE: Debugging coordinates with Access::Rights, Auth::Auth.

=cut

# ---------------------------------------------------------------------
sub __get_user_attributes {
    my $requested_attribute = shift;
    my $unmasked = shift;

    my $Access_Control_List_ref = ___get_ACL;

    my $userid = __get_remote_user();
    my $attrval = $Access_Control_List_ref->{$userid}{$requested_attribute} || '';

    # Superuser debugging over-rides
    unless ($unmasked) {
        if ( S___superuser_role ) {
            if (DEBUG('ord')) {
                $attrval = '';
            }
            elsif (DEBUG('hathi')) {
                $attrval = '';
            }
            elsif (DEBUG('ssd')) {
                $attrval = 'ssd'     if ($requested_attribute eq 'role');
                $attrval = 'normal'  if ($requested_attribute eq 'access');
                $attrval = 'student' if ($requested_attribute eq 'usertype');
            }
            elsif (DEBUG('ssdproxy')) {
                $attrval = 'ssdproxy' if ($requested_attribute eq 'role');
                $attrval = 'normal'   if ($requested_attribute eq 'access');
                $attrval = 'external' if ($requested_attribute eq 'usertype');
            }
        }
    }

    return $attrval;
}

# ---------------------------------------------------------------------

=item __load_access_control_list

PRIVATE

WARNING: keys to this hash must be lower-case

=cut

# ---------------------------------------------------------------------
sub __load_access_control_list {

    my $Access_Control_List_ref = ___get_ACL;
    return if ( scalar keys %$Access_Control_List_ref );

    my $C = new Context;
    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_users};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    foreach my $hashref (@$ref_to_arr_of_hashref) {

        my $userid = $hashref->{userid};

        $Access_Control_List_ref->{$userid}{userid} = $hashref->{userid};
        $Access_Control_List_ref->{$userid}{displayname} = $hashref->{displayname};
        $Access_Control_List_ref->{$userid}{usertype} = $hashref->{usertype};
        $Access_Control_List_ref->{$userid}{role} = $hashref->{role};
        $Access_Control_List_ref->{$userid}{access} = $hashref->{access};

        $Access_Control_List_ref->{$userid}{iprestrict} = $hashref->{iprestrict};
        $Access_Control_List_ref->{$userid}{vpn} = $hashref->{vpn};

        # Use database IP address(es), if defined. If not defined, use
        # the "no access" IP address or some other value in special
        # cases (SSD) below. Add the VPN range if vpn=1
        #
        my $vpn = $hashref->{vpn};
        my $iprestrict = $hashref->{iprestrict};

        if (defined $iprestrict) {
            $Access_Control_List_ref->{$userid}{iprestrict} = ($vpn ? join( '|', ($iprestrict, $library_vpn_range) ) : $iprestrict);
        }
        else {
            $Access_Control_List_ref->{$userid}{iprestrict} = ($vpn ? $library_vpn_range : $iprestrict_all);
        }

        my $expires = $hashref->{expires};
        $expires = ( ($expires eq $ZERO_TIMESTAMP) ? undef : $expires );
        if (defined $expires) {
            $Access_Control_List_ref->{$userid}{expires} = $expires;
        }
        else {
            $Access_Control_List_ref->{$userid}{expires} = $GLOBAL_EXPIRE_DATE;
        }

        # Special cases
        #
        if ($Access_Control_List_ref->{$userid}{usertype} eq 'student') {
            if ($Access_Control_List_ref->{$userid}{role} eq 'ssd') {
                $Access_Control_List_ref->{$userid}{iprestrict} = $iprestrict_none;
            }
        }
    }

    ___set_ACL($Access_Control_List_ref);
}


1;

__END__

=back

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012-14 ©, The Regents of The University of Michigan, All Rights Reserved

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

