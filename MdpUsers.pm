package MdpUsers;

=head1 NAME

MdpUsers;

=head1 DESCRIPTION

This class is a perl interface to ht_repository.ht_users

usertype values are 'staff' (UM), 'student' (UM), 'external' (non-UM)

roles are subclasses of usertype:

 select distinct usertype, role from ht_users;

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
 +----------+--------------+---------+

'normal' access excludes attr=8 (nobody)

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use Context;
use Database;
use DbUtils;


# Mon Feb 13 2012 Superusers are restricted to these ranges
# 141.211.43.128/25   141.211.43.129  - 141.211.43.254  - LIT offices
# 141.211.84.128/25   141.211.84.129  - 141.211.84.254  - Library VPN - disallowed as of Thu Nov 21 12:21:13 2013
# 141.211.168.128/25  141.211.168.129 - 141.211.168.254 - Hatcher server room
# 141.211.172.0/22    141.211.172.1   - 141.211.175.254 - Hatcher/Shapiro buildings
# 141.213.128.128/25  141.213.128.129 - 141.213.128.254 - MACC data center
#                     141.211.174.173 - 141.211.174.199 - ULIC Shapiro 4th floor
#
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


#
# The ACL
#
my %gAccessControlList;

# ---------------------------------------------------------------------

=item __load_access_control_list

PRIVATE

WARNING: keys to this hash must be lower-case to work vs. ACL.pm

 CREATE TABLE `ht_users` (
       `userid` varchar(256) DEFAULT NULL,
       `displayname` varchar(128) DEFAULT NULL,
       `usertype` varchar(32) DEFAULT NULL,
       `role` varchar(32) DEFAULT NULL,
       `expires` varchar(32) DEFAULT NULL,
       `iprestrict` varchar(1024) DEFAULT NULL,
                 PRIMARY KEY (`userid`));

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


# ---------------------------------------------------------------------

=item get_user_attributes

Description

=cut

# ---------------------------------------------------------------------
sub get_user_attributes {
    my $req_attribute = shift;
    my $user = shift;

    __load_access_control_list();

    my $remote_user = $ENV{REMOTE_USER} || '';
    my $key = defined($user) ? $user : lc($remote_user);
    my $attrval = $gAccessControlList{$key}{$req_attribute};

    return $attrval;
}

# ---------------------------------------------------------------------

=item get_user_id_list

Description

=cut

# ---------------------------------------------------------------------
sub get_user_id_list {
    __load_access_control_list();
    my @list = keys %gAccessControlList;

    return \@list;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012-13 ©, The Regents of The University of Michigan, All Rights Reserved

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
