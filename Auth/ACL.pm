package Auth::ACL;

=head1 NAME

Auth::ACL

=head1 DESCRIPTION

This package encapsulates access to the Access control list in
MdpUsers.pm. It says whether a user has special authorization to
access in-copyright materials, use debugging functions, download as a
proxy for print-disabled users, etc.

=head1 VERSION

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use MdpUsers;
use Utils;
use Debug::DUtils;
use Utils::Time;

# ---------------------------------------------------------------------

=item a_GetUserAttributes

Description

=cut

# ---------------------------------------------------------------------
sub a_GetUserAttributes {
    my $req_attribute = shift;
    return MdpUsers::get_user_attributes($req_attribute);
}

# ---------------------------------------------------------------------

=item a_Authorized

Description

=cut

# ---------------------------------------------------------------------
my $__a_debug_printed = 0;
my $__b_debug_printed = 0;

sub a_Authorized {
    my $access_ref = shift;

    return 0 unless((ref $access_ref eq 'HASH') && scalar keys %$access_ref );
    
    my $authorized = 0;
    my $ipaddr = $ENV{'REMOTE_ADDR'};

    my $usertype = MdpUsers::get_user_attributes('usertype');
    my $role = MdpUsers::get_user_attributes('role');
    my $ip_range = MdpUsers::get_user_attributes('iprestrict');
    my $expiration_date = MdpUsers::get_user_attributes('expires');
    my $access = MdpUsers::get_user_attributes('access');

    # See if user is in ACL
    if (defined($usertype)) {
        # Check expiration
        if (! Utils::Time::expired($expiration_date)) {
            # Not expired. correct IP?
            if ($ipaddr =~ m/$ip_range/) {
                # Limit to certain roles or access
                foreach my $key (keys %$access_ref) {
                    if ( $access_ref->{$key} eq MdpUsers::get_user_attributes($key) ) {
                        $authorized = 1;
                        last;
                    }
                }
            }
        }
    }

    DEBUG('auth,all', 
          sub {
              return '' if $__a_debug_printed;
              my $remote_user = lc($ENV{'REMOTE_USER'});
              my $s = qq{<h2 style="text-align:left">AUTH ACL: authorized=$authorized, IP=$ipaddr, user=$remote_user usertype=$usertype role=$role access=$access expires=$expiration_date</h2>};
              $__a_debug_printed = 1;
              return $s;
          });
    DEBUG('acl',
          sub {
              return '' if $__b_debug_printed;
              my $s;
              my $userid_ref = MdpUsers::get_user_id_list();
              my $time = time;
              my @users = (sort @$userid_ref);
              my @debug_users = ();
              foreach my $user (@users) {
                  if (DEBUG($user)) {
                      push(@debug_users, $user);
                  }
              }
              if (scalar @debug_users) {
                  @users = @debug_users;
              }              
              foreach my $user (@users) {
                  my $usertype = MdpUsers::get_user_attributes('usertype', $user);
                  my $role = MdpUsers::get_user_attributes('role', $user);
                  my $access = MdpUsers::get_user_attributes('access', $user);
                  my $iprestrict = MdpUsers::get_user_attributes('iprestrict', $user);
                  my $expires = MdpUsers::get_user_attributes('expires', $user);
                  my $name = MdpUsers::get_user_attributes('displayname', $user);

                  $s .= qq{<h2 style="text-align:left">ACL: user=$user name=$name expires=$expires type=$usertype role=$role acess=$access <font color="blue">ip=$iprestrict </font></h2>};
              }
              $__b_debug_printed = 1;
              return $s;
          });
    
    return $authorized;
}



1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2010-13 ©, The Regents of The University of Michigan, All Rights Reserved

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
