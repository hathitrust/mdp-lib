package Auth::ACL;

=head1 NAME

Auth::ACL

=head1 DESCRIPTION

This package encapsulates access to the Access control list in
MdpUsers.pm. It says whether an authenticated user has special
authorization to use the 'debug' and 'attr' URL parameters among
others.

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
    
    my $attr;    
    my $user = lc($ENV{'REMOTE_USER'});

    if ($req_attribute eq 'usertype') {
        $attr = $MdpUsers::gAccessControlList{$user}{'usertype'};
    }
    elsif ($req_attribute eq 'iprestrict') {
        $attr = $MdpUsers::gAccessControlList{$user}{'iprestrict'};
    }
    elsif ($req_attribute eq 'expires') {
        $attr = $MdpUsers::gAccessControlList{$user}{'expires'};
    }
    elsif ($req_attribute eq 'role') {
        $attr = $MdpUsers::gAccessControlList{$user}{'role'};
    }
    elsif ($req_attribute eq 'displayname') {
        $attr = $MdpUsers::gAccessControlList{$user}{'displayname'};
    }
    
    return $attr;
}

# ---------------------------------------------------------------------

=item a_Authorized

Description

=cut

# ---------------------------------------------------------------------
my $__a_debug_printed = 0;
my $__b_debug_printed = 0;

sub a_Authorized {
    my $role_req = shift;
    my $authorized = 0;

    my $remote_user = lc($ENV{'REMOTE_USER'});
    my $ipaddr = $ENV{'REMOTE_ADDR'};

    my $usertype = $MdpUsers::gAccessControlList{$remote_user}{'usertype'};
    my $role = $MdpUsers::gAccessControlList{$remote_user}{'role'};
    my $ip_rangeref = $MdpUsers::gAccessControlList{$remote_user}{'iprestrict'};
    my $expiration_date = $MdpUsers::gAccessControlList{$remote_user}{'expires'};

    # See if user is in ACL
    if (defined($usertype)) {
        # Check expiration
        if (! Utils::Time::expired($expiration_date)) {
            # Not expired. correct IP?
            foreach my $regexp (@$ip_rangeref) {
                if ($ipaddr =~ m/$regexp/) {
                    # Limit to certain roles?
                    if (defined($role_req)) {
                        if ($role =~ m/$role_req/) {
                            $authorized = 1;
                            last;
                        }
                        else {
                            last;
                        }
                    }
                    else {
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
              my $s = qq{<h2 style="text-align:left">AUTH ACL: authorized=$authorized, IP=$ipaddr, user=$remote_user usertype=$usertype role=$role expires=$expiration_date</h2>};
              $__a_debug_printed = 1;
              return $s;
          });
    DEBUG('acl',
          sub {
              return '' if $__b_debug_printed;
              my $s;
              my $ref = \%MdpUsers::gAccessControlList;
              my $time = time;
              my @users = (sort keys %$ref);
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
                  $s .= qq{<h2 style="text-align:left">AUTH ACL: user=$user name=$ref->{$user}{displayname} expire=$ref->{$user}{expires} type=$ref->{$user}{usertype}  role=$ref->{$user}{role} <font color="blue">ip=<br/>}
                    . join('<br/>', @{ $ref->{$user}{iprestrict} }) . qq{</font></h2>};
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
