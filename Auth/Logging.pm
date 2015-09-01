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

use strict;
use warnings;

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

=item log_successful_access

Log accesses to the web log for security reporting and debugging
successful accesses.

=cut

# ---------------------------------------------------------------------
sub log_successful_access  {
    my ($C, $id, $app_name) = @_;
    my $ar = $C->get_object('Access::Rights');

    if ( $ar->check_final_access_status($C, $id) eq 'allow' ) {
        _log_access($C, $id, $app_name, 'access=success');
    }
}

# ---------------------------------------------------------------------

=item log_failed_access

Log accesses to the web log for security reporting and debugging
failed accesses.

=cut

# ---------------------------------------------------------------------
sub log_failed_access  {
    my ($C, $id, $app_name) = @_;
    my $ar = $C->get_object('Access::Rights');

    if ( $ar->check_final_access_status($C, $id) ne 'allow' ) {
        _log_access($C, $id, $app_name, 'access=failure');
    }
}

sub _log_access {
    my ($C, $id, $app_name, $message) = @_;

    my $ar = $C->get_object('Access::Rights');
    my $auth = $C->get_object('Auth');

    my $attr                  = $ar->get_rights_attribute($C, $id) || 0;
    my $ic                    = $ar->in_copyright($C, $id) || 0;
    my $access_type           = $ar->get_access_type($C, 'as_string');
    my $remote_addr           = $ENV{REMOTE_ADDR} || 'notset';
    my $proxied_addr          = Access::Rights::proxied_address() || 'notset';
    my $remote_user_processed = Utils::Get_Remote_User() || 'notset';
    my $remote_user_from_env  = $ENV{REMOTE_USER} || 'notset';
    my $sdrinst               = $ENV{SDRINST} || 'notset';
    my $remote_realm          = $ENV{REMOTE_REALM} || 'notset';
    my $auth_type             = lc ($ENV{AUTH_TYPE} || 'notset');
    my $http_host             = $ENV{HTTP_HOST} || 'notset';
    my $sdrlib                = $ENV{SDRLIB} || 'notset';
    my $http_referer          = $ENV{HTTP_REFERER}  || 'notset'; $http_referer =~ s,\|,//,g;
    my $user_agent            = $ENV{HTTP_USER_AGENT}  || 'notset';
    my $inst_code             = $auth->get_institution_code($C) || 'notset';
    my $inst_code_mapped      = $auth->get_institution_code($C, 1) || 'notset';
    my $inst_name             = $auth->get_institution_name($C) || 'notset';
    my $inst_name_mapped      = $auth->get_institution_name($C, 1) || 'notset';

    require Geo::IP;
    my $geoIp = Geo::IP->new();
    my $country_code = $geoIp->country_code_by_addr($remote_addr) || 'notset'; chomp $country_code;
    my $country_name = $geoIp->country_name_by_addr($remote_addr) || 'notset'; chomp $country_name;
    my $country_code_prox = $geoIp->country_code_by_addr($proxied_addr) || 'notset'; chomp $country_code_prox;
    my $country_name_prox = $geoIp->country_name_by_addr($proxied_addr) || 'notset'; chomp $country_name_prox;

    my ($usertype, $role) = (
                             Auth::ACL::a_GetUserAttributes('usertype') || 'notset',
                             Auth::ACL::a_GetUserAttributes('role') || 'notset',
                            );
    my $datetime = Utils::Time::iso_Time();

    # my $s = qq{$message: app=$app_name id=$id $datetime attr=$attr ic=$ic access_type=$access_type remote_addr=$remote_addr proxied_addr=$proxied_addr http_referer=$http_referer user_agent=$user_agent remote_user(env=$remote_user_from_env processed=$remote_user_processed) auth_type=$auth_type usertype=$usertype role=$role geo_code=$country_code geo_name=$country_name geo_code_proxy=$country_code_prox geo_name_prox=$country_name_prox remote_realm=$remote_realm sdrinst=$sdrinst sdrlib=$sdrlib http_host=$http_host inst_code=$inst_code inst_code_mapped=$inst_code_mapped inst_name=$inst_name inst_name_mapped=$inst_name_mapped };

    my $s .= qq{$message|app=$app_name|id=$id|datetime=$datetime|attr=$attr|ic=$ic|access_type=$access_type|remote_addr=$remote_addr|proxied_addr=$proxied_addr|http_referer=$http_referer|user_agent=$user_agent|remote_user_env=$remote_user_from_env|remote_user_processed=$remote_user_processed|auth_type=$auth_type|usertype=$usertype|role=$role|sdrinst=$sdrinst|sdrlib=$sdrlib|http_host=$http_host|inst_code=$inst_code|inst_code_mapped=$inst_code_mapped|inst_name=$inst_name|inst_name_mapped=$inst_name_mapped|geo_code=$country_code|geo_name=$country_name|geo_code_proxy=$country_code_prox|geo_name_proxy=$country_name_prox};

    if ($auth_type eq 'shibboleth') {
        my $affiliation = $ENV{affiliation} || 'notset';
        my $eppn = $ENV{eppn} || 'notset';
        my $display_name = $ENV{displayName} || 'notset';
        my $entityID = $ENV{Shib_Identity_Provider} || 'notset';
        my $persistent_id = $ENV{persistent_id} || 'notset';

        $s .= qq{|eduPersonScopedAffiliation=$affiliation|eduPersonPrincipalName=$eppn|displayName=$display_name|persistent_id=$persistent_id|Shib_Identity_Provider=$entityID};
    }


    my $proxied_addr_hash = Access::Rights::get_proxied_address_data();
    foreach my $key (keys %$proxied_addr_hash) {
        my $ip = $proxied_addr_hash->{$key};
        if ($ip) {
            $s .= qq{$key=$ip };
        }
    }

    if ($auth_type eq 'shibboleth') {
        my $affiliation = $ENV{affiliation} || 'notset';
        my $eppn = $ENV{eppn} || 'notset';
        my $display_name = $ENV{displayName} || 'notset';
        my $entityID = $ENV{Shib_Identity_Provider} || 'notset';
        my $persistent_id = $ENV{persistent_id} || 'notset';

        $s .= qq{eduPersonScopedAffiliation=$affiliation eduPersonPrincipalName=$eppn displayName=$display_name persistent_id=$persistent_id Shib_Identity_Provider=$entityID};
    }

    # The optional_dir_pattern "slip/run-___RUN___" is used here
    # to replace that portion of the logdir set when the slip
    # config is merged into pt's config to restore the original
    # logdir path SDRROOT/logs/pt ... what a tangled web we weave
    my $pattern = qr(slip/run-___RUN___|___QUERY___);
    Utils::Logger::__Log_string($C, $s, 'pt_access_logfile', $pattern, 'pt');
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
