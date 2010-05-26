package Auth::ACL;

=head1 NAME

Auth::ACL

=head1 DESCRIPTION

This package encapsulates access to the Access control list in
MdpUsers.pm. It says whether an authenticated user has special
authorization to use the 'debug' and 'attr' URL parameters among
others.

=head1 VERSION

$Id: ACL.pm,v 1.3 2010/05/19 13:58:03 pfarber Exp $

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

=item a_Authorized

Description

=cut

# ---------------------------------------------------------------------
sub a_Authorized {
    my $authorized = 0;

    my $user = $ENV{'REMOTE_USER'};
    my $ipaddr = $ENV{'REMOTE_ADDR'};

    my $usertype = $MdpUsers::gAccessControlList{$user}{'usertype'};
    my $ip_rangeref = $MdpUsers::gAccessControlList{$user}{'iprestrict'};
    my $expiration_date = $MdpUsers::gAccessControlList{$user}{'expires'};

    # See if user is in ACL
    if (defined($usertype)) {
        # Check expiration
        if (! Utils::Time::expired($expiration_date)) {
            # Not expired. correct IP? 
            foreach my $regexp (@$ip_rangeref) {
                if ($ipaddr =~ m/$regexp/) {
                    $authorized = 1;
                    last;
                }
            }
        }
    }
        
    DEBUG('auth,all', qq{<h2>AUTH ACL: authorized="$authorized", IP="$ipaddr", user="$user" usertype="$usertype expires=$expiration_date"</h2>});

    return $authorized;
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
