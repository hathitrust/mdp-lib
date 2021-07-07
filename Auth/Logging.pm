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

        {
            if ( Debug::DUtils::DEBUG('super') ) {
                my $usertype = Auth::ACL::a_GetUserAttributes('usertype');
                if ( $usertype ) {
                    my $role = Auth::ACL::a_GetUserAttributes('role');
                    Utils::add_header($C, 'X-HathiTrust-User', "usertype=$usertype;role=$role");
                }
            }
        }

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

sub log_possible_incopyright_access  {
    my ($C, $id) = @_;

    my $Header_Key = 'X-HathiTrust-InCopyright';

    my $ar = $C->get_object('Access::Rights');
    my $in_copyright = $ar->in_copyright($C, $id);

    if ( $in_copyright ) {
        my $attribute             = $ar->get_rights_attribute($C, $id) || 0;
        my $ic                    = $ar->in_copyright($C, $id) || 0;
        my $access_type           = $ar->get_access_type($C, 'as_string');
        my $access_type_by_attr   = $ar->check_initial_access_status_by_attribute($C, $attribute, $id);

        if ( $access_type_by_attr =~ m/holdings|held/ ) {
            # is this item even held by the institution?
            my $inst = $C->get_object('Auth')->get_institution_code($C, 'mapped');
            my ( $lock_id, $held ) = Access::Holdings::id_is_held($C, $id, $inst);

            if ( $held ) {
                # ... that is in-copyright
                my $usertype = Auth::ACL::a_GetUserAttributes('usertype');

                if ($usertype) {
                    my $role = Auth::ACL::a_GetUserAttributes('role');
                    Utils::add_header($C, $Header_Key, "user=$usertype,$role;attr=$attribute;access=$access_type;granted=false");
                }
                else {
                    # Users entitled to view OP @OPB brittle, lost, missing held by their institution
                    Utils::add_header($C, $Header_Key, "user=other,none;attr=$attribute;access=$access_type;granted=false");
                }
            }

        }
    }
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

    require URI::Escape;

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
    my $http_referer          = $ENV{HTTP_REFERER}  || 'notset'; $http_referer = URI::Escape::uri_escape($http_referer);
    my $request_uri           = $ENV{REQUEST_URI}  || 'notset'; $request_uri = URI::Escape::uri_escape($request_uri);
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

    my $s .= qq{$message|app=$app_name|id=$id|datetime=$datetime|attr=$attr|ic=$ic|access_type=$access_type|remote_addr=$remote_addr|proxied_addr=$proxied_addr|request_uri=$request_uri|http_referer=$http_referer|user_agent=$user_agent|remote_user_env=$remote_user_from_env|remote_user_processed=$remote_user_processed|auth_type=$auth_type|usertype=$usertype|role=$role|sdrinst=$sdrinst|sdrlib=$sdrlib|http_host=$http_host|inst_code=$inst_code|inst_code_mapped=$inst_code_mapped|inst_name=$inst_name|inst_name_mapped=$inst_name_mapped|geo_code=$country_code|geo_name=$country_name|geo_code_proxy=$country_code_prox|geo_name_proxy=$country_name_prox};

    if ($auth_type eq 'shibboleth') {
        my $affiliation = $ENV{affiliation} || 'notset';
        my $eppn = $ENV{eppn} || 'notset';
        my $display_name = $ENV{displayName} || 'notset';
        my $entityID = 'notset';
        $entityID = $ENV{Shib_Identity_Provider} if ( defined($ENV{Shib_Identity_Provider}) );
        $entityID = $ENV{'Shib-Identity-Provider'} if ( defined($ENV{'Shib-Identity-Provider'}) );
        my $persistent_id = 'notset';
        $persistent_id = $ENV{persistent_id} if ( defined($ENV{persistent_id}) );
        $persistent_id = $ENV{'persistent-id'} if ( defined($ENV{'persistent-id'}) );

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
        my $entityID = 'notset';
        $entityID = $ENV{Shib_Identity_Provider} if ( defined($ENV{Shib_Identity_Provider}) );
        $entityID = $ENV{'Shib-Identity-Provider'} if ( defined($ENV{'Shib-Identity-Provider'}) );
        my $persistent_id = 'notset';
        $persistent_id = $ENV{persistent_id} if ( defined($ENV{persistent_id}) );
        $persistent_id = $ENV{'persistent-id'} if ( defined($ENV{'persistent-id'}) );

        $s .= qq{eduPersonScopedAffiliation=$affiliation eduPersonPrincipalName=$eppn displayName=$display_name persistent_id=$persistent_id Shib_Identity_Provider=$entityID};
    }

    # The optional_dir_pattern "slip/run-___RUN___" is used here
    # to replace that portion of the logdir set when the slip
    # config is merged into pt's config to restore the original
    # logdir path SDRROOT/logs/pt ... what a tangled web we weave
    my $pattern = qr(slip/run-___RUN___|___QUERY___);
    Utils::Logger::__Log_string($C, $s, 'pt_access_logfile', $pattern, 'pt');
}

sub log_access {
    my ($C, $app_name, $tuples, $altenv) = @_;

    my $auth = $C->get_object('Auth');
    my $mdpItem = $C->get_object('MdpItem', 1);
    my $session = $C->get_object('Session', 1);
    $altenv = {} unless ( ref($altenv) );

    my $datetime = Utils::Time::iso_Time();

    my $message = [['datetime', $datetime], ['session', $session ? $session->get_session_id() : 'notset' ], ['app', $app_name]];

    if ( ref($mdpItem) ) {
        # my $s .= qq{$message|app=$app_name|id=$id|datetime=$datetime|attr=$attr|ic=$ic|access_type=$access_type|remote_addr=$remote_addr|proxied_addr=$proxied_addr|request_uri=$request_uri|http_referer=$http_referer|user_agent=$user_agent|remote_user_env=$remote_user_from_env|remote_user_processed=$remote_user_processed|auth_type=$auth_type|usertype=$usertype|role=$role|sdrinst=$sdrinst|sdrlib=$sdrlib|http_host=$http_host|inst_code=$inst_code|inst_code_mapped=$inst_code_mapped|inst_name=$inst_name|inst_name_mapped=$inst_name_mapped|geo_code=$country_code|geo_name=$country_name|geo_code_proxy=$country_code_prox|geo_name_proxy=$country_name_prox};

        my $ar = $C->get_object('Access::Rights');
        my $id = $mdpItem->GetId();
        my $attr                  = $ar->get_rights_attribute($C, $id) || 0;
        my $ic                    = $ar->in_copyright($C, $id) || 0;
        my $access_type           = $ar->get_access_type($C, 'as_string');
        my $access_type_by_attr     = $ar->check_initial_access_status_by_attribute($C, $attr, $id);

        push @$message, ['id', $id];
        push @$message, ['attr', $attr];
        push @$message, ['ic', $ic];

        # check for alternative access from $tuples
        my $access;
        if ( ref($tuples) && $$tuples[0][0] eq 'access' ) {
            my $tmp = shift @$tuples;
            $access = $$tmp[1];
        } else {
            $access = $ar->check_final_access_status($C, $id) eq 'allow' ? 'success' : 'failure';
        }

        push @$message, ['access', $access ];
        push @$message, ['access_type', $access_type];
        push @$message, ['access_type_by_attr', $access_type_by_attr];

        if ( $access_type_by_attr =~ m/holdings|held/ ) {
            # is this item even held by the institution?
            my $inst = $C->get_object('Auth')->get_institution_code($C, 'mapped');
            my ( $lock_id, $held ) = Access::Holdings::id_is_held($C, $id, $inst);
            push @$message, ['id_is_held', $held];
        }

        my ( $digitization_source, $collection_source ) = $mdpItem->GetSources();
        push @$message, ['digitization_source', $digitization_source];
        push @$message, ['collection_source', $collection_source];
    }


    my $remote_addr           = $ENV{REMOTE_ADDR} || '0.0.0.0';
    my $proxied_addr          = Access::Rights::proxied_address() || undef;
    my $remote_user_processed = Utils::Get_Remote_User() || undef;
    my $remote_user_from_env  = $ENV{REMOTE_USER} || undef;
    my $affiliation           = $ENV{affiliation} || undef;
    my $eppn                  = $ENV{eppn} || undef;
    my $display_name          = $ENV{displayName} || undef;
    # my $entityID              = $ENV{Shib_Identity_Provider} || undef;
    # my $persistent_id         = $ENV{persistent_id} || undef;

    my $entityID = 'notset';
    $entityID = $ENV{Shib_Identity_Provider} if ( defined($ENV{Shib_Identity_Provider}) );
    $entityID = $ENV{'Shib-Identity-Provider'} if ( defined($ENV{'Shib-Identity-Provider'}) );
    my $persistent_id = 'notset';
    $persistent_id = $ENV{persistent_id} if ( defined($ENV{persistent_id}) );
    $persistent_id = $ENV{'persistent-id'} if ( defined($ENV{'persistent-id'}) );

    my ($usertype, $role) = (
                             Auth::ACL::a_GetUserAttributes('usertype') || undef,
                             Auth::ACL::a_GetUserAttributes('role') || undef,
                            );
    my $sdrinst               = $ENV{SDRINST} || undef;
    my $auth_type             = $ENV{AUTH_TYPE} ? lc $ENV{AUTH_TYPE} : undef;
    my $http_host             = $$altenv{HTTP_HOST} || $ENV{HTTP_HOST} || undef;
    my $server_addr           = ( $http_host eq $ENV{HTTP_HOST} ) ? $ENV{SERVER_ADDR} : undef;
    my $sdrlib                = $ENV{SDRLIB} || undef;
    my $http_referer          = $$altenv{HTTP_REFERER} || $ENV{HTTP_REFERER}  || undef; # $http_referer = URI::Escape::uri_escape($http_referer);
    my $request_uri           = $$altenv{REQUEST_URI} || $ENV{REQUEST_URI}  || undef; # $request_uri = URI::Escape::uri_escape($request_uri);
    my $user_agent            = $ENV{HTTP_USER_AGENT}  || undef;
    my $inst_code             = $auth->get_institution_code($C) || undef;
    my $inst_code_mapped      = $auth->get_institution_code($C, 1) || undef;
    # my $inst_name             = $auth->get_institution_name($C) || undef;
    # my $inst_name_mapped      = $auth->get_institution_name($C, 1) || undef;

    require Geo::IP;
    my $geoIp = Geo::IP->new();
    my $geo_code = $geoIp->country_code_by_addr($remote_addr) || undef; chomp $geo_code if ( $geo_code );
    # my $geo_name = $geoIp->country_name_by_addr($remote_addr) || undef; chomp $geo_name if ( $geo_name );
    my ( $geo_code_proxy, $geo_name_proxy );
    if ( $proxied_addr ) {
        $geo_code_proxy = $geoIp->country_code_by_addr($proxied_addr) || undef; chomp $geo_code_proxy if ( $geo_code_proxy );
        # $geo_name_proxy = $geoIp->country_name_by_addr($proxied_addr) || undef; chomp $geo_name_proxy if ( $geo_name_proxy );
    }


    push @$message, ['remote_addr', $remote_addr];
    push @$message, ['proxied_addr', $proxied_addr];
    push @$message, ['remote_user_processed', $remote_user_processed];
    push @$message, ['remote_user_from_env', $remote_user_from_env];
    push @$message, ['affiliation', $affiliation];
    push @$message, ['eppn', $eppn];
    push @$message, ['display_name', $display_name];
    push @$message, ['entityID', $entityID];
    push @$message, ['persistent_id', $persistent_id];
    push @$message, ['usertype', $usertype];
    push @$message, ['role', $role];
    push @$message, ['sdrinst', $sdrinst];
    push @$message, ['auth_type', $auth_type];
    push @$message, ['http_host', $http_host];
    push @$message, ['server_addr', $server_addr];
    push @$message, ['sdrlib', $sdrlib];
    push @$message, ['http_referer', $http_referer];
    push @$message, ['request_uri', $request_uri];
    push @$message, ['user_agent', $user_agent];
    push @$message, ['inst_code', $inst_code];
    push @$message, ['inst_code_mapped', $inst_code_mapped];
    # push @$message, ['inst_name', $inst_name];
    # push @$message, ['inst_name_mapped', $inst_name_mapped];
    push @$message, ['geo_code', $geo_code];
    # push @$message, ['geo_name', $geo_name];
    push @$message, ['geo_code_proxy', $geo_code_proxy];
    # push @$message, ['geo_name_proxy', $geo_name_proxy];

    # $s .= qq{|eduPersonScopedAffiliation=$affiliation|eduPersonPrincipalName=$eppn|displayName=$display_name|persistent_id=$persistent_id|Shib_Identity_Provider=$entityID};


    my $proxied_addr_hash = Access::Rights::get_proxied_address_data();
    foreach my $key (keys %$proxied_addr_hash) {
        my $ip = $proxied_addr_hash->{$key};
        if ($ip) {
            push @$message, [$key, $ip];
        }
    }

    push @$message, @$tuples if ( ref($tuples) );

    if ( ref($mdpItem) ) {
        push @$message, [ 'd', $$mdpItem{__timestamps} ];
    }

    # my $s = join('|', map { join('=', @$_) } @$message);
    require JSON::XS;
    my $json = JSON::XS->new()->utf8(1)->allow_nonref(1);
    my $s = '{';
    while ( scalar @$message ) {
        my $kv = shift @$message;
        my ( $key, $value ) = @$kv;
        my $suffix = scalar @$message ? "," : "";
        $s .= sprintf(qq{%s:%s%s}, $json->encode($key), $json->encode($value), $suffix)
    }
    $s .= '}';

    # The optional_dir_pattern "slip/run-___RUN___" is used here
    # to replace that portion of the logdir set when the slip
    # config is merged into pt's config to restore the original
    # logdir path SDRROOT/logs/pt ... what a tangled web we weave
    my $pattern = qr(slip/run-___RUN___|___QUERY___);
    my $logfile_pattern = $app_name;
    $logfile_pattern .= "_" . $$altenv{postfix} if ( $$altenv{postfix} );
    Utils::Logger::__Log_string($C, $s, 'access_logfile', $pattern, "access", qr(___APP_NAME___), $logfile_pattern);
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
