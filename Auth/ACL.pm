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
 +----------+---------------+---------+
 | usertype | role          | access  |
 +----------+---------------+---------+
 | staff    | generalhathi  | total   | UM staff
 | staff    | cataloging    | total   | UM staff
 | external | crms          | total   | non-UM engaged in CRMS and CRMS World activities
 | staff    | crms          | total   | UM staff engaged in CRMS and CRMS World activities
 | staff    | superuser     | total   | UM staff (developers)
 | staff    | orphan        | total   | UM staff engaged in the Orphan Works project
 | staff    | quality       | total   | UM staff engaged in the Qual project
 | external | quality       | total   | non-UM engaged in the Qual project
 | staff    | replacement   | total   | UM staff at DCU
 | staff    | inprintstatus | total   | Copyright determination UM staff
 | staff    | corrections   | total   | Hathitrust support UM staff
 |----------+---------------+---------+
 | student  | ssd           | normal  | UM student on SSD list *not locked to any IP address*
 | external | ssdproxy      | normal  | non-UM Human Proxy for print-disabled user
 | external | ssdnfb        | normal  | non-UM National Federation of the Blind Proxy for print-disabled user
 +----------+---------------+---------+

'normal' access excludes attr=8 (nobody)

Counting user in-copyright access activity

 DESCRIBE ht_counts;
 +----------------+--------------+------+-----+---------------------+-------+
 | Field          | Type         | Null | Key | Default             | Extra |
 +----------------+--------------+------+-----+---------------------+-------+
 | userid         | varchar(256) | NO   |     |                     |       |
 | accesscount    | int(11)      | NO   |     | 0                   |       |
 | last_access    | timestamp    | NO   |     | 0000-00-00 00:00:00 |       |
 | warned         | tinyint(1)   | NO   |     | 0                   |       |
 | auth_requested | tinyint(1)   | NO   |     | 0                   |       |
 +----------------+--------------+------+-----+---------------------+-------+

Activity is update on each in-copyright access. warned=1 is set when the HathiTrust admininstrator is warned that htere are activities where user access is about to expire.  auth_requested=1 is set when HathiTrust admininstrator generated request to Core Services to renew access.  When access is renewed or users are re-added, warn and auth_requested are reset.

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
use Utils::Time;
use Debug::DUtils;
use Database;
use DbUtils;

# 141.213.171.72-141.213.171.87
# 141.213.175.72-141.213.175.87
my $library_vpn_range = q{^141\.213\.17[15]\.(7[2-9]|8[0-7])$};

# blocked
my $iprestrict_all = 'notanipaddress';

# unrestricted (SSD only, after Wed Apr  2 13:42:55 2014)
my $iprestrict_none = '.*';

# 

my $ZERO_TIMESTAMP = '0000-00-00 00:00:00';
my $GLOBAL_EXPIRE_DATE = '2014-12-31 23:59:59';

my $do_restrict_to_identity_provider = 0;


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

=item a_Increment_accesscount

 Increment accesscount for a user present in the table upon the user's
request for access to a restricted item. 'accesscount' is reset to 0
when 'expires' is updated (programmatically, NOT from the command
line) and is not incremented if access expires.

=cut

# ---------------------------------------------------------------------
sub a_Increment_accesscount {
    my $id = shift;
    __load_access_control_list();
    __update_accesscount($id);
}

# ---------------------------------------------------------------------

=item __a_Authorized_core

PRIVATE

=cut

# ---------------------------------------------------------------------
sub __a_Authorized_core {
    my $access_ref = shift;
    my $unmasked = shift;

    return 0 unless(ref $access_ref eq 'HASH');
    return 0 unless(scalar keys %$access_ref == 1);

    my $authorized = 0;
    my $ipaddr = $ENV{REMOTE_ADDR} || '';

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

    my $authorized = __a_Authorized_core($access_ref);
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

    my $superuser = DEBUG('super') && __a_Authorized_core( {role => 'superuser'}, 'unmasked' );
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

    my $total = DEBUG('super') && __a_Authorized_core( {access => 'total'}, 'unmasked' );
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

    my $superuser = __a_Authorized_core( {role => 'superuser'}, 'unmasked' );
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

    my $total = __a_Authorized_core( {access => 'total'}, 'unmasked' );
    return $total;
}

# ---------------------------------------------------------------------

=item __debug_acl

Description

=cut

# ---------------------------------------------------------------------
my $__a_debug_printed = 0;
my $__b_debug_printed = 0;

sub __debug_acl {
    my $authorized = shift;
    my $test_case = shift;

    my $Access_Control_List_ref = ___get_ACL;
    my $remote_user = Utils::Get_Remote_User();

    # masked data to reflect effect of debugging switches.
    DEBUG('auth,all',
          sub {
              return '' if $__a_debug_printed;
              my $ipaddr = $ENV{REMOTE_ADDR} || '';
              my $userid = $remote_user;
              my $usertype = __get_user_attributes('usertype');
              my $role = __get_user_attributes('role');
              my $access = __get_user_attributes('access');
              my $expires = __get_user_attributes('expires');

              my $superuser = S___superuser_role() ? '(<font color="green">superuser</font>)' : '';
              $authorized = $authorized ? '<font color="blue">1</font>' : '0';

              #   0         1          2      3            4         5           6          7            8       9         10
              my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(6);
              my $s = qq{<h3 style="text-align:left">ACL AUTH[$subroutine]$superuser: authorized=$authorized $test_case, IP=$ipaddr, userid=$userid usertype=$usertype role=$role access=$access expires=$expires</h3>};
              $__a_debug_printed = 1;
              return $s;
          });

    # unmasked data to dump actual state of table
    DEBUG('acl',
          sub {
              return '' if $__b_debug_printed;
              my $s = '';
              my @userids = keys %$Access_Control_List_ref;
              foreach my $userid (sort @userids) {
                  my $usertype    = $Access_Control_List_ref->{$userid}{usertype};
                  my $role        = $Access_Control_List_ref->{$userid}{role};
                  my $access      = $Access_Control_List_ref->{$userid}{access};
                  my $iprestrict  = $Access_Control_List_ref->{$userid}{iprestrict};
                  my $vpn         = $Access_Control_List_ref->{$userid}{vpn};
                  my $expires     = $Access_Control_List_ref->{$userid}{expires};
                  my $name        = $Access_Control_List_ref->{$userid}{displayname};
                  my $accesscount = $Access_Control_List_ref->{$userid}{accesscount};
                  my $last_access = $Access_Control_List_ref->{$userid}{last_access};

                  $s .= qq{<h3 style="text-align:left">ACL DUMP: userid=$userid name=$name accesscount=$accesscount last_access=$last_access expires=$expires type=$usertype role=$role access=$access vpn=<font color="red">$vpn</font> <font color="blue">ip=$iprestrict </font></h3>};
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

    # my $userid = Utils::Get_Remote_User();
    my @userids = Utils::Get_Remote_User_Names();
    my $userid = shift @userids; # the first one
    my $identity_provider = Utils::Get_Identity_Provider();
    $userid .= "|$identity_provider" if ( $do_restrict_to_identity_provider );
    my $attrval = $Access_Control_List_ref->{$userid}{$requested_attribute} || '';
    unless ( $attrval || ! scalar @userids ) {
      $userid = shift @userids;
      $userid .= "|$identity_provider" if ( $do_restrict_to_identity_provider );
      $attrval = $Access_Control_List_ref->{$userid}{$requested_attribute} || '';
    }

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

=item __update_accesscount

PRIVATE

Counts are not deleted from this table.

=cut

# ---------------------------------------------------------------------
sub __update_accesscount {
    my $id = shift;

    my $usertype = __get_user_attributes('usertype', 'unmasked');

    # ... user in ACL?
    if ($usertype) {
        # ... and can still be active?
        my $expiration_date = __get_user_attributes('expires', 'unmasked');
        return if ( Utils::Time::expired($expiration_date) );
    }
    # POSSIBLY NOTREACHED

    my $C = new Context;
    my $dbh = $C->get_object('Database')->get_DBH;
    my $attr = $C->get_object('Access::Rights')->get_rights_attribute($C, $id);

    my $userid = $C->get_object('Auth')->get_user_name($C);
    my $ipaddr = $ENV{REMOTE_ADDR} || '';
    my $role = __get_user_attributes('role');
    my $access = __get_user_attributes('access');
    my $expires = __get_user_attributes('expires');
    my $s = $userid ? "userid=$userid" : "NULL userid";

    my ($sth, $statement);
    eval {
        $statement = qq{INSERT INTO ht_counts SET userid=?, accesscount=1, last_access=NOW() ON DUPLICATE KEY UPDATE accesscount=accesscount+1, last_access=NOW()};
        DEBUG('auth', qq{DEBUG: $statement :: $userid});
        $sth = DbUtils::prep_n_execute($dbh, $statement, $userid);
    };
    if ($@) {
        print STDERR "Auth::ACL::__update_accesscount error: $@";
    }
}

# ---------------------------------------------------------------------

=item ___attribute_mapping

Description

=cut

# ---------------------------------------------------------------------
sub ___attribute_mapping {
    my $hashref = shift;

    # Map these
    my $role = $hashref->{role};
    my $mfa = $hashref->{mfa} || 0;
    my $iprestrict = $hashref->{iprestrict};
    my $usertype = $hashref->{usertype};
    my $expires = $hashref->{expires};

    # Mapping from UI value to internal superuser
    if ( grep(/^$role$/, (qw/staffdeveloper staffsysadmin/)) ) {
        $role = $hashref->{role} = 'superuser';
    }

    unless( defined $expires ) {
        $expires = $hashref->{expires} = $ZERO_TIMESTAMP;
    }

    # Use database IP address(es), if defined, else use the
    # "no access" IP address or some other value in special cases
    # (SSD, Multi-Factored Auth) below.
    #
    if ($usertype eq 'student') {
        if ($role eq 'ssd') {
            $iprestrict = $hashref->{iprestrict} = $iprestrict_none;
        }
    } elsif ($mfa) {
      $iprestrict = $hashref->{iprestrict} = $iprestrict_none;      
    } elsif (!defined $iprestrict) {
      $iprestrict = $hashref->{iprestrict} = $iprestrict_all;
    }
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

    my ($statement, $sth, $ref_to_arr_of_hashref);

    $statement = qq{SELECT ht_users.*, ht_counts.accesscount, ht_counts.last_access, ht_counts.warned, ht_counts.certified, ht_counts.auth_requested FROM ht_users LEFT OUTER JOIN ht_counts ON ht_users.userid = ht_counts.userid};
    $sth = DbUtils::prep_n_execute($dbh, $statement);
    $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    foreach my $hashref (@$ref_to_arr_of_hashref) {


        ___attribute_mapping($hashref);

        my $userid = $hashref->{userid};
        my $identity_provider = $hashref->{identity_provider} || '';
        $userid .= "|$identity_provider" if ( $do_restrict_to_identity_provider );
        map { $Access_Control_List_ref->{$userid}{$_} = $hashref->{$_} } keys %{ $hashref };
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

