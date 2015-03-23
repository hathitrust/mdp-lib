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

    my $logged = 0;

    my $Header_Key = 'X-HathiTrust-InCopyright';

    my $ar = $C->get_object('Access::Rights');
    if ( $ar->check_final_access_status($C, $id) eq 'allow' ) {
        # ... serving something
        my $in_copyright = $ar->in_copyright($C, $id);
        my $attribute = $ar->get_rights_attribute($C, $id) || 0;
        my $access_type = $ar->get_access_type($C, 'as_string');

        if ($in_copyright) {
            # ... that is in-copyright
            my $usertype = Auth::ACL::a_GetUserAttributes('usertype');

            if ($usertype) {
                my $role = Auth::ACL::a_GetUserAttributes('role');
                Utils::add_header($C, $Header_Key, "user=$usertype,$role;attr=$attribute;access=$access_type");
            }
            else {
                # Users entitled to view OP @OPB brittle, lost, missing held by their institution
                Utils::add_header($C, $Header_Key, "user=other,none;attr=$attribute;access=$access_type");
            }
            $logged = 1;
        }
    }

    return $logged;
}

# ---------------------------------------------------------------------

=item log_failed_access

Log accesses to the web log for security reporting and debugging
failed accesses.

=cut

# ---------------------------------------------------------------------
sub log_failed_access  {
    my ($C, $id) = @_;

    my $ar = $C->get_object('Access::Rights');
    if ( $ar->check_final_access_status($C, $id) ne 'allow' ) {
        my $attr = $ar->get_rights_attribute($C, $id) || 0;
        my $ic = $ar->in_copyright($C, $id) || 0;
        my $access_type = $ar->get_access_type($C, 'as_string');

        my $remote_user_processed = Utils::Get_Remote_User() || 'notset';
        my $remote_user_from_env = $ENV{REMOTE_USER} || 'notset';
        my $proxied_addr = Access::Rights::proxied_address() || 'notset';
        my $remote_addr = $ENV{REMOTE_ADDR} || 'notset';

        require Geo::IP;
        my $geoIp = Geo::IP->new();
        my $countryCode = $geoIp->country_code_by_addr($remote_addr);
        my $countryName = $geoIp->country_name_by_addr($remote_addr);

        my ($usertype, $role) = (
                                 Auth::ACL::a_GetUserAttributes('usertype') || 'notset',
                                 Auth::ACL::a_GetUserAttributes('role') || 'notset',
                                );
        my $datetime = Utils::Time::iso_Time();

        my $s = qq{access failure: id=$id $datetime attr=$attr ic=$ic access_type=$access_type remote_addr=$remote_addr proxied_addr=$proxied_addr remote_user[env=$remote_user_from_env processed=$remote_user_processed] usertype=$usertype role=$role geo_code=$countryCode geo_name=$countryName";
};

        # The optional_dir_pattern "slip/run-___RUN___" is used here
        # to replace that portion of the logdir set when the slip
        # config is merged into pt's config to restore the original
        # logdir path SDRROOT/logs/pt ... what a tangled web we weave
        Utils::Logger::__Log_string($C, $s, 'pt_access_logfile', 'slip/run-___RUN___', 'pt');
    }
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011-2015 ©, The Regents of The University of Michigan, All Rights Reserved

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
