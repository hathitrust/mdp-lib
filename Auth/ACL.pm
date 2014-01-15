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

Subroutines prefixed with '__' are private and should only be called
from within the Auth::ACL package.

usertype values are 'staff' (UM), 'student' (UM), 'external' (non-UM)

roles are subclasses of usertype:

 CREATE TABLE `ht_users` (
    `userid`      varchar(256)  DEFAULT NULL,
    `displayname` varchar(128)  DEFAULT NULL,
    `usertype`    varchar(32)   DEFAULT NULL,
    `role`        varchar(32)   DEFAULT NULL,
    `expires`     varchar(32)   DEFAULT NULL,
    `iprestrict`  varchar(1024) DEFAULT NULL,
            PRIMARY KEY (`userid`));

 SELECT DISTINCT usertype, role FROM ht_users;

 +----------+--------------+---------+
 | usertype | role         | access  |
 +----------+--------------+---------+
 | staff    | generalhathi | total   | staff locked to $staff_subnet_ranges
 | staff    | cataloging   | total   | staff locked to $staff_subnet_ranges
 | external | crms         | total   | external engaged in CRMS and CRMS World activities, locked to IP
 | staff    | crms         | total   | staff engaged in CRMS and CRMS World activities, locked to IP or $staff_subnet_ranges
 | staff    | superuser    | total   | staff (developers) locked to $superuser_subnet_ranges
 | staff    | orphan       | total   | staff engaged in the Orphan Works project, locked to IP
 | staff    | quality      | total   | staff engaged in the Qual project, locked to $staff_subnet_ranges
 | external | quality      | total   | external engaged in the Qual project, locked to IP
 | staff    | digitization | total   | staff at DCU, locked to IP
 |----------+--------------+---------+
 | student  | ssd          | normal  | UM SSD student list not locked to by IP range
 | external | ssdproxy     | normal  | external Human Proxy for print-disabled user locked to IP address
 | external | ssdnfb       | normal  | external National Federation of the Blind Proxy for print-disabled user locked to IP address
 +----------+--------------+---------+

'normal' access excludes attr=8 (nobody)

=head1 SYNOPSIS

Coding example

=head1 IP RANGES

 Mon Feb 13 2012 Superusers are restricted to these ranges
 141.211.43.128/25   141.211.43.129  - 141.211.43.254  - LIT offices
 141.211.84.128/25   141.211.84.129  - 141.211.84.254  - Library VPN - disallowed as of Thu Nov 21 12:21:13 2013
 141.211.168.128/25  141.211.168.129 - 141.211.168.254 - Hatcher server room
 141.211.172.0/22    141.211.172.1   - 141.211.175.254 - Hatcher/Shapiro buildings
 141.213.128.128/25  141.213.128.129 - 141.213.128.254 - MACC data center
                     141.211.174.173 - 141.211.174.199 - ULIC Shapiro 4th floor

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

#
# The ACL
#
my %gAccessControlList;

my $lit_offices_range          = q{^(141\.211\.43\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4])))$};
my $library_vpn_range          = q{^(141\.211\.84\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4])))$};
my $hatcher_server_room_range  = q{^(141\.211\.168\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4])))$};
my $hatcher_shapiro_bldg_range = q{^(141\.211\.(1(7[2-5]))\.([1-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-4])))$};
my $macc_data_center_range     = q{^(141\.213\.128\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4])))$};
my $ulic_range                 = q{^(141\.211\.174\.(1(7[3-9]|[8-9][0-9])))$};

# superusers
my @superuser_ranges =
  (
   $lit_offices_range,
   # $library_vpn_range, # per jweise, csnavely Thu Nov 21 12:20:33 2013
   $hatcher_server_room_range,
   $hatcher_shapiro_bldg_range,
   $macc_data_center_range,
   $ulic_range,
  );
my $superuser_subnet_ranges = join('|', @superuser_ranges);

# Staff
my @staff_ranges =
  (
   $hatcher_shapiro_bldg_range,
   $lit_offices_range,
  );
my $staff_subnet_ranges = join('|', @staff_ranges);

my $ULIC_subnet_ranges = $ulic_range;

# blocked
my $null_range = 'notanipaddress';

# wide open (SSD)
my $unrestricted_range = '.*';

my $ZERO_TIMESTAMP = '0000-00-00 00:00:00';
my $GLOBAL_EXPIRE_DATE = '2014-12-31 23:59:59';

# staff:{other} access expires on date:
my $staff_expire_date = $GLOBAL_EXPIRE_DATE;

# staff:superuser access expires on date:
my $superuser_expire_date = $GLOBAL_EXPIRE_DATE;

# student:{other} access expires on date:
my $student_expire_date = $GLOBAL_EXPIRE_DATE;

# external:{other} access expires on date:
my $external_expire_date = $GLOBAL_EXPIRE_DATE;

# {all}:ssd* access expires on date:
my $SSD_expire_date = $GLOBAL_EXPIRE_DATE;

# {all}:crms users access expires on date:
my $CRMS_expire_date = $GLOBAL_EXPIRE_DATE;

# ---------------------------------------------------------------------

=item a_GetUserAttributes

PUBLIC

This entry point provides access to ACL attributes and centralizes and
debugging switch overrides.

NOTE: Does not do authorization.  That is, does not test whether
the user is coming from the correct IP address, for example.

=cut

# ---------------------------------------------------------------------
sub a_GetUserAttributes {
    my $requested_attribute = shift;
    __load_access_control_list();

    return '' unless(defined $requested_attribute);
    return __get_user_attributes($requested_attribute);
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

    return 0 unless(ref $access_ref eq 'HASH');
    return 0 unless(scalar keys %$access_ref == 1);

    my $authorized = 0;
    my $ipaddr = $ENV{REMOTE_ADDR};

    my $usertype = __get_user_attributes('usertype');
    my $role = __get_user_attributes('role');
    my $ip_range = __get_user_attributes('iprestrict');
    my $expiration_date = __get_user_attributes('expires');
    my $access = __get_user_attributes('access');

    my ($key) = keys %$access_ref;

    # See if user is in ACL
    if ($usertype) {
        # Check expiration
        if (! Utils::Time::expired($expiration_date)) {
            # Not expired. correct IP?
            if ($ipaddr =~ m/$ip_range/) {
                # Limit to certain roles or access
                my ($key) = keys %$access_ref;
                if ( $access_ref->{$key} eq __get_user_attributes($key) ) {
                    $authorized = 1;
                }
            }
        }
    }

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

    my $superuser = 0;
    my $userid = lc $ENV{REMOTE_USER};

    my $role = $gAccessControlList{$userid}{role} || '';
    if ($role eq 'superuser') {
        if (DEBUG('super')) {
            $superuser = 1;
        }
    }

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

    my $total = 0;
    my $userid = lc $ENV{REMOTE_USER};

    my $access = $gAccessControlList{$userid}{access} || '';
    if ($access eq 'total') {
        if (DEBUG('super')) {
            $total = 1;
        }
    }

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

    my $superuser = 0;
    my $userid = lc $ENV{REMOTE_USER};

    my $role = $gAccessControlList{$userid}{role} || '';
    if ($role eq 'superuser') {
        $superuser = 1;
    }

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

    my $total = 0;
    my $userid = lc $ENV{REMOTE_USER};

    my $access = $gAccessControlList{$userid}{access} || '';
    if ($access eq 'total') {
        $total = 1;
    }

    return $total;
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

    DEBUG('auth,all',
          sub {
              my $ipaddr = $ENV{REMOTE_ADDR} || '';
              my $userid = lc $ENV{REMOTE_USER} || '';
              my $usertype = __get_user_attributes('usertype');
              my $role = __get_user_attributes('role');
              my $access = __get_user_attributes('access');
              my $expires = __get_user_attributes('expires');

              my $superuser = S___superuser_role() ? '(<font color="blue">superuser</font>)' : '';
              $authorized = $authorized ? '<font color="blue">1</font>' : '0';

              #   0         1          2      3            4         5           6          7            8       9         10
              my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(6);
              my $s = qq{<h3 style="text-align:left">ACL AUTH[$subroutine]$superuser: authorized=$authorized $test_case, IP=$ipaddr, userid=$userid usertype=$usertype role=$role access=$access expires=$expires</h3>};
              return $s;
          });

    DEBUG('acl',
          sub {
              return '' if $__b_debug_printed;
              my $s = '';
              my @userids = __get_userid_list();
              foreach my $userid (sort @userids) {
                  my $usertype = __get_user_attributes('usertype', $userid);
                  my $role = __get_user_attributes('role', $userid);
                  my $access = __get_user_attributes('access', $userid);
                  my $iprestrict = __get_user_attributes('iprestrict', $userid);
                  my $expires = __get_user_attributes('expires', $userid);
                  my $name = __get_user_attributes('displayname', $userid);

                  $s .= qq{<h3 style="text-align:left">ACL DUMP: userid=$userid name=$name expires=$expires type=$usertype role=$role acess=$access <font color="blue">ip=$iprestrict </font></h3>};
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

Debugging coordinates with Access::Rights, Auth::Auth.

=cut

# ---------------------------------------------------------------------
sub __get_user_attributes {
    my $requested_attribute = shift;
    my $userid = shift;

    my $_userid = (defined $userid) ? $userid : lc $ENV{REMOTE_USER};
    my $attrval = $gAccessControlList{$_userid}{$requested_attribute} || '';

    # Superuser debugging over-rides
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

    return $attrval;
}

# ---------------------------------------------------------------------

=item __get_userid_list

Description

=cut

# ---------------------------------------------------------------------
sub __get_userid_list {
    return keys %gAccessControlList;
}

# ---------------------------------------------------------------------

=item __load_access_control_list

PRIVATE

WARNING: keys to this hash must be lower-case

=cut

# ---------------------------------------------------------------------
sub __load_access_control_list {

    return if (scalar keys %gAccessControlList);

    my $C = new Context;
    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_users};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    foreach my $hashref (@$ref_to_arr_of_hashref) {
        my $userid = $hashref->{userid};

        $gAccessControlList{$userid}{userid} = $hashref->{userid};
        $gAccessControlList{$userid}{displayname} = $hashref->{displayname};
        $gAccessControlList{$userid}{usertype} = $hashref->{usertype};
        $gAccessControlList{$userid}{role} = $hashref->{role};
        $gAccessControlList{$userid}{access} = $hashref->{access};

        # Stored IP range and expiration date are used, if defined,
        # else we use one of the above hardcoded ranges depending on
        # usertype and role.
        my $iprestrict = $hashref->{iprestrict};
        if (defined $iprestrict) {
            $gAccessControlList{$userid}{iprestrict} = $iprestrict;
        }

        my $expires = $hashref->{expires};
        $expires = ( ($expires eq $ZERO_TIMESTAMP) ? undef : $expires );
        if (defined $expires) {
            $gAccessControlList{$userid}{expires} = $expires;
        }

        if ($gAccessControlList{$userid}{usertype} eq 'staff') {
            if ($gAccessControlList{$userid}{role} eq 'superuser') {
                $gAccessControlList{$userid}{expires} = $superuser_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $superuser_subnet_ranges unless (defined $iprestrict);
            }
            else {
                $gAccessControlList{$userid}{expires} = $staff_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $staff_subnet_ranges unless (defined $iprestrict);
            }
        }
        elsif ($gAccessControlList{$userid}{usertype} eq 'external') {
            if ($gAccessControlList{$userid}{role} eq 'crms') {
                $gAccessControlList{$userid}{expires} = $CRMS_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $null_range unless (defined $iprestrict);
            }
            elsif ($gAccessControlList{$userid}{role} =~ m,^ssd,) {
                $gAccessControlList{$userid}{expires} = $SSD_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $null_range unless (defined $iprestrict);
            }
            else {
                $gAccessControlList{$userid}{expires} = $external_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $null_range unless (defined $iprestrict);
            }
        }
        elsif ($gAccessControlList{$userid}{usertype} eq 'student') {
            if ($gAccessControlList{$userid}{role} eq 'ssd') {
                $gAccessControlList{$userid}{expires} = $SSD_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $unrestricted_range unless (defined $iprestrict);
            }
            else {
                $gAccessControlList{$userid}{expires} = $student_expire_date unless (defined $expires);
                $gAccessControlList{$userid}{iprestrict} = $null_range unless (defined $iprestrict);
            }
        }
    }
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

