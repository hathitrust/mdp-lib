package Auth::Logging;


=head1 NAME

Auth::Logging

=head1 DESCRIPTION

This package handles logging various authentication and authorization
actions like access to in-copyright materials.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use Context;
use Utils;
use Auth::ACL;
use Auth::Auth;
use Access::Rights;

# ---------------------------------------------------------------------

=item log_incopyright_access

Log in-copyright accesses to the web log for security reporting.
Various hueristics determine the app making the request.

=cut

# ---------------------------------------------------------------------
sub log_incopyright_access  {
    my ($C, $id) = @_;

    my $Header_Key = 'X-HathiTrust-InCopyright';
    
    my $ar = $C->get_object('Access::Rights');
    if ( $ar->check_final_access_status($C, $id) eq 'allow' ) {
        # ... serving something
        if (Access::Rights::in_copyright_suppress_debug_switches($C, $id)) {
            # ... that is in-copyright 
            my $usertype = Auth::ACL::a_GetUserAttributes('usertype');
           
            if (defined $usertype) {
                my $role = Auth::ACL::a_GetUserAttributes('role');
                Utils::add_header($C, $Header_Key, "user=$usertype,$role");
            }
            else {
                # Better have SSD credentials
                my $is_ssd = $C->get_object('Auth')->get_eduPersonEntitlement_print_disabled($C);
                ASSERT($is_ssd, qq{Unknown user identity requesting in_copyright material id=$id});

                Utils::add_header($C, $Header_Key, "user=ssd");
            }
        }
    }
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
