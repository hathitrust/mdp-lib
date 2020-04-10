package Auth::Auth;


=head1 NAME

Auth::Auth (auth)

=head1 DESCRIPTION

This class provides the authentication interface for the App

=head1 SYNOPSIS

This object should NOT be saved on the session.  Its state is valid
only for the current execution context.

my $auth = new Auth::Auth($C);

if ($auth->is_logged_in() {
   ...
}

if ($auth->isa_new_login()) {
   ...
}

With the advent of COSIGN single signon we have to redirect the
request over SSL (https) if the request comes in via a non-SSL route
(http), for example by following a link in a static page, and the
user's session says they did authentication via COSIGN.

So the redirect condition X is $was_logged_in=COSIGN but
$auth->is_logged_in()=FALSE.

There are two paths to consider:

1) The user COSIGN logged out from some other web application and then came
to HathiTrust via SSL (https). In that case the user will be forced to
authenticate so condition X will NOT hold so there's no need to
redirect, i.e. $auth->is_logged_in() will be TRUE.

2) The the user's COSIGN authentication cookie expies before the
user's session.  This can't happen because HathiTrust session expire
after 2 hours of inactivity whereas SSL cookie expires after 8 hours.

With the advent of Shibboleth support while still maintaining COSIGN
support we have to redirect as with COSIGN but also must change the
redirect path from /cgi/ to /shcgi/ if the request comes in via a
non-SSL route (http) and the user's session says they have
authenticated via Shibboleth.

There are two other paths to consider:

1) The user logged from a Shibboleth IdP then came to to HathiTrust
via SSL (https). In that case the user will be forced to authenticate
so condition X will not hold so there's no need to redirect.,
i.e. $auth->is_logged_in() will be TRUE.

2) The the user's Shibboleth authentication cookie expies before the
user's session.  This can't happen because HathiTrust session expire
after 2 hours of inactivity whereas Shibboleth cookies expire when the
browser is closed or else after between 6 months and one year.

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use File::Basename;
use XML::LibXML;

use Utils;
use Debug::DUtils;
use Session;
use Auth::ACL;
use Auth::Exclusive;
use Institutions;

use Context;

use constant COSIGN => 'cosign';
use constant SHIBBOLETH => 'shibboleth';
use constant FRIEND => 'friend';

# University of Michigan entity ID (until we are %100 shibboleth
my $UMICH_ENTITY_ID = 'https://shibboleth.umich.edu/idp/shibboleth';

# eduPersonEntitlement attribute values that qualify as print disabled
my $ENTITLEMENT_PRINT_DISABLED_VALUE = 'http://www.hathitrust.org/access/enhancedText';
my $ENTITLEMENT_PRINT_DISABLED_PROXY_VALUE = 'http://www.hathitrust.org/access/enhancedTextProxy';

my $NON_HT_AFFILIATED_ENTITY_IDS = {};
$$NON_HT_AFFILIATED_ENTITY_IDS{'pumex-idp'} = 1;

# eduPersonScopedAffiliation attribute values that can be considered
# for print disabled status
my $ENTITLEMENT_VALID_AFFILIATIONS_REGEXP =
  qr,^(member|faculty|staff|student)$,ios;

sub new {
    my $class = shift;
    my $C = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize($C);

    return $self;
}

# ---------------------------------------------------------------------

=item _initialize

Initialize Auth::Auth

=cut

# ---------------------------------------------------------------------
sub __debug_auth {
    my $self = shift;
    my ($C, $ses) = @_;

    DEBUG('auth',
          sub {
              return '' if ($self->{__debug_auth_printed});

              my $auth_str =
                q{<h1>AUTH:</h1> userid=} . $self->get_user_name($C) . q{ displayname=} . $self->get_user_display_name($C)
                  . q{ loggedin=} . ($self->is_logged_in() || '') . q{ in-library=} . $self->is_in_library()
                    . q{ authsys=} . (__get_auth_sys($ses) || '')
                      . q{ newlogin=} . $self->isa_new_login()
                        . q{ entityID=} . ($self->get_shibboleth_entityID($C) || '')
                          . q{ parsed-persistent_id=} . $self->get_eduPersonTargetedID()
                            . q{ eppn=} . ($self->get_eduPersonPrincipalName($C) || '')
                              . q{ prioritized-scoped-affiliation=} . $self->get_eduPersonScopedAffiliation($C)
                                . q{ institution code=} . $self->get_institution_code($C) . q{ institution-code (mapped)=} . $self->get_institution_code($C, 1)
                                  . q{ institution name=} . $self->get_institution_name($C) . q{ institution-name (mapped)=} . $self->get_institution_name($C, 1)
                                    . q{ is-umich=} . $self->affiliation_is_umich($C)
                                      . q{ is-hathitrust=} . $self->affiliation_is_hathitrust($C)
                                        . q{ is-hathitrust=} . $self->affiliation_is_hathitrust($C)
                                          . q{ is-emergency-access-affiliate=} . $self->affiliation_has_emergency_access($C)
                                            . q{ computed-entitlement=} . $self->get_eduPersonEntitlement_print_disabled($C)
                                              . q{ print-disabled-proxy=} . $self->user_is_print_disabled_proxy($C)
                                                . q{ print-disabled=} . $self->user_is_print_disabled($C);

              $self->{__debug_auth_printed} = 1;
              return $auth_str;
          });
}

sub _initialize {
    my $self = shift;
    my $C = shift;

    if ($C->has_object('Session')) {
        my $ses = $C->get_object('Session');
        my $was_logged_in_via = __get_auth_sys($ses);

        if ($self->is_logged_in($C)) {
            $self->set_auth_sys($ses);
            my $now_logged_in_via = __get_auth_sys($ses);

            $self->set_isa_new_login($was_logged_in_via ne $now_logged_in_via);

            if ($self->isa_new_login()) {
                Auth::Exclusive::update_exclusive_access(
                                                         $C,
                                                         $ses->get_session_id(),
                                                         $self->get_user_name($C),
                                                        );
            }

            $self->__debug_auth($C, $ses);
        }
        else {
            $self->__debug_auth($C, $ses);
            if ( my $redirect_to = $self->handle_possible_auth_renewal($C, $was_logged_in_via) ) {
                $self->do_redirect($C, $redirect_to);
            } else {
                $self->handle_possible_auth_expiration($C, $was_logged_in_via);
            }
        }
    }
}

# ---------------------------------------------------------------------

=item get_umich_entity_id

PUBLIC:  CLASS METHOD

=cut

# ---------------------------------------------------------------------
sub get_umich_IdP_entity_id {
    return $UMICH_ENTITY_ID;
}


# ---------------------------------------------------------------------

=item handle_possible_redirect

Redirect the request over SSL and possible alter path from /cgi/ to
/shcgi/

=cut

# ---------------------------------------------------------------------
sub handle_possible_redirect {
    my $self = shift;
    my ($C, $was_logged_in_via) = @_;

    my $cgi = $C->get_object('CGI');

    if ($was_logged_in_via eq COSIGN && $ENV{SERVER_PORT} ne '443') {
        my $redirect_to = $self->get_COSIGN_login_href($cgi);
        $self->do_redirect($C, $redirect_to);
    }
    elsif ($was_logged_in_via eq SHIBBOLETH) {
        my $redirect_to = $self->get_SHIBBOLETH_login_href($cgi);
        $self->do_redirect($C, $redirect_to);
    }
}

sub handle_possible_auth_expiration {
    my $self = shift;
    my ($C, $was_logged_in_via) = @_;

    # no longer logged in
    if ( $was_logged_in_via && $was_logged_in_via ne 'null' ) {
        my $cgi = $C->get_object('CGI');
        my $ses = $C->get_object('Session');
        $ses->set_persistent('logged_out', 1);
        $ses->set_persistent('authenticated_via', '');
        my $redirect_to = $self->get_SHIBBOLETH_login_href($cgi);
    }
}

sub handle_possible_auth_renewal {
    my $self = shift;
    my ( $C, $was_logged_in_via ) = @_;
    my $redirect_to;
    if ( $was_logged_in_via eq 'shibboleth' ) {
        my $ses = $C->get_object('Session');
        my $entity_id = $ses->get_persistent('entity_id') || '';
        my $could_renew = 
            ( $ENV{REQUEST_URI} =~ m,/cgi/(ssd|mb|ls), )
            ||
            ( $ENV{REQUEST_URI} =~ m,/cgi/pt, && $ENV{QUERY_STRING} !~ m,a=, );

        if ( $entity_id && $could_renew ) {
            my $cgi = $C->get_object('CGI');
            my $target = CGI::self_url($cgi);
            my $inst_code = Institutions::get_institution_entityID_field_val($C, $entity_id, 'inst_id', 1);
            $redirect_to = Institutions::get_institution_entityID_field_val($C, $entity_id, 'template', 1);
            $redirect_to =~ s,___HOST___,$ENV{SERVER_NAME},;
            $redirect_to =~ s,___TARGET___,$target,;
        }
    }
    return $redirect_to;
}

sub handle_possible_auth_2fa {
    my $self = shift;
    my ( $C, $access_type ) = @_;
    if ( $self->is_possible_auth_stepup($C, $access_type) ) {
        my $entityID = $self->get_shibboleth_entityID($C);
        my $authContextClassRef = $self->get_institution_2fa_authcontext_class_ref($C);
        if ( defined $ENV{Shib_AuthnContext_Class} && defined $authContextClassRef && $ENV{Shib_AuthnContext_Class} ne $authContextClassRef ) {
            # need to redirect
            $access_type = $RightsGlobals::ORDINARY_USER;
            $self->handle_auth_2fa_redirect($C, $authContextClassRef);
        } elsif ( defined $ENV{'Shib-AuthnContext-Class'} && defined $authContextClassRef && $ENV{'Shib-AuthnContext-Class'} ne $authContextClassRef ) {
            $access_type = $RightsGlobals::ORDINARY_USER;
            $self->handle_auth_2fa_redirect($C, $authContextClassRef);
        }
    }
    return $access_type;
}

sub handle_auth_2fa_redirect {
    my $self = shift;
    my ( $C, $authnContextClassRef ) = @_;
    my $cgi = $C->get_object('CGI');
    my $target = CGI::self_url($cgi);
    my $inst_id = $self->get_institution_code($C, 1);
    my $redirect_to = $self->get_institution_template($C, 1);
    $redirect_to =~ s,___HOST___,$ENV{SERVER_NAME},;
    $redirect_to =~ s,___TARGET___,$target,;
    $redirect_to .= qq{&authnContextClassRef=$authnContextClassRef};
    $self->do_redirect($C, $redirect_to);
}

sub is_possible_auth_stepup {
    my $self = shift;
    my ( $C, $access_type ) = @_;

    my $retval = 0;

    my $config = {};
    $$config{$RightsGlobals::HT_TOTAL_USER} = 1;
    $$config{$RightsGlobals::SSD_PROXY_USER} = 1;

    my $is_mfa = Auth::ACL::a_GetUserAttributes('mfa') || 0;

    if ( $is_mfa && defined $access_type && defined $$config{$access_type} ) {
        $retval = $$config{$access_type};
        if ( ref($retval) ) {
            # my $value = Auth::ACL::a_GetUserAttributes('usertype');
            my $value = Auth::ACL::a_GetUserAttributes('role');
            $retval = defined $value && defined $$config{$access_type}{$value} && $$config{$access_type}{$value};
        }
    }

    return $retval;
}

sub do_redirect {
    my $self = shift;
    my ( $C, $redirect_to ) = @_;
    my $cgi = $C->get_object('CGI');
    print $cgi->redirect($redirect_to);
    exit;
}

# ---------------------------------------------------------------------

=item get_SHIBBOLETH_login_href

Description

=cut

# ---------------------------------------------------------------------
sub get_SHIBBOLETH_login_href {
    my $self = shift;
    my $cgi = shift;

    my $login_href = CGI::self_url($cgi);
    $login_href =~ s,/cgi/,/shcgi/, if ( $self->is_cosign_active );
    $login_href = Utils::url_over_SSL_to($login_href);

    return $login_href;
}

# ---------------------------------------------------------------------

=item get_WAYF_login_href

Description

=cut

# ---------------------------------------------------------------------
sub get_WAYF_login_href {
    my $self = shift;
    my ($C, $return_to_url) = @_;

    $return_to_url = CGI::escape($return_to_url);
    $return_to_url = Utils::url_over_SSL_to($return_to_url);

    my $WAYF_url = $C->get_object('MdpConfig')->get('WAYF_url');

    my $host = $ENV{HTTP_HOST} || 'localhost';
    $WAYF_url =~ s,___HOST___,$host,;
    $WAYF_url .= qq{?target=$return_to_url};

    return $WAYF_url;
}

# ---------------------------------------------------------------------

=item get_COSIGN_login_href

Description

=cut

# ---------------------------------------------------------------------
sub get_COSIGN_login_href {
    my $self = shift;
    my $cgi = shift;

    my $login_href = CGI::self_url($cgi);
    $login_href = Utils::url_over_SSL_to($login_href);

    return $login_href;
}

# ---------------------------------------------------------------------

=item set_auth_sys

Description

=cut

# ---------------------------------------------------------------------
sub set_auth_sys {
    my $self = shift;
    my $ses = shift;
    $ses->set_persistent('authenticated_via', lc($ENV{AUTH_TYPE} || ''));
    $ses->set_persistent('logged_out', 0) if ( $ENV{AUTH_TYPE} );
    $ses->set_persistent('entity_id', $ENV{'Shib-Identity-Provider'} || $ENV{'Shib_Identity_Provider'})
        if ( $ENV{AUTH_TYPE} );
}

# ---------------------------------------------------------------------

=item __get_auth_sys

PRIVATE CLASS METHOD

=cut

# ---------------------------------------------------------------------
sub __get_auth_sys {
    my $ses = shift;
    return $ses->get_persistent('authenticated_via') || 'null';
}

# ---------------------------------------------------------------------

=item auth_sys_is_COSIGN

Description

=cut

# ---------------------------------------------------------------------
sub auth_sys_is_COSIGN {
    my $self = shift;
    my $C = shift;

    # for the "gr" cgi
    my $is = defined $ENV{SCRIPT_NAME} && $ENV{SCRIPT_NAME} eq q{/cgi/gr};

    if ($C->has_object('Session')) {
        my $ses = $C->get_object('Session');
        my $authenticated_via = $ses->get_persistent('authenticated_via') || 'null';
        $is = ($authenticated_via eq COSIGN);
    }

    return $is;
}

# ---------------------------------------------------------------------

=item auth_sys_is_SHIBBOLETH

Description

=cut

# ---------------------------------------------------------------------
sub auth_sys_is_SHIBBOLETH {
    my $self = shift;
    my $C = shift;

    # for gr
    my $is = 0;

    if ($C->has_object('Session')) {
        my $ses = $C->get_object('Session');
        my $authenticated_via = $ses->get_persistent('authenticated_via') || 'null';
        $is = ($authenticated_via eq SHIBBOLETH);
    }

    return $is;

}

# ---------------------------------------------------------------------

=item is_logged_in

true if user has authenticated.  REMOTE_USER will reflect both COSIGN
authentication and the multiple Shibboleth attribute values (via a
priority scheme) that we recognize as asserting authentication

=cut

# ---------------------------------------------------------------------
sub is_logged_in {
    my $self = shift;

    return 0 if (DEBUG('notlogged'));
    return Utils::Get_Remote_User();
}

# ---------------------------------------------------------------------

=item login_realm_is_friend

true if user has authenticated and the cosign realm is "friend"

=cut

# ---------------------------------------------------------------------
sub login_realm_is_friend {
    my $self = shift;
    return ($self->is_logged_in() && (lc($ENV{REMOTE_REALM} || '') eq FRIEND));
}

# ---------------------------------------------------------------------

=item __get_institution_code_by_ip_address

*** PRIVATE CLASS METHOD ***

Note this associates the REMOTE_ADDR via a list of institutions codes
maintained by Core Services for Apache.

Clients of this class should use get_institution_code()

=cut

# ---------------------------------------------------------------------
sub __get_institution_code_by_ip_address {
    return $ENV{SDRINST} || '';
}


# ---------------------------------------------------------------------

=item get_institution_code

Note this maps user's IdP entity ID to the (possibly mapped)
institution code.

=cut

# ---------------------------------------------------------------------
sub get_institution_code {
    my $self = shift;
    my $C = shift;
    my $mapped = shift;

    my $inst_code;

    my $entity_id = $self->get_shibboleth_entityID($C);
    if ($entity_id) {
        $inst_code = Institutions::get_institution_entityID_field_val($C, $entity_id, 'inst_id', $mapped);
    }
    else {
        my $inst_id = __get_institution_code_by_ip_address();
        $inst_code = Institutions::get_institution_inst_id_field_val($C, $inst_id, 'inst_id', $mapped);
    }

    return $inst_code;
}

# ---------------------------------------------------------------------

=item get_institution_us_status

Is user's institution in the US?

=cut

# ---------------------------------------------------------------------
sub get_institution_us_status {
    my $self = shift;
    my $C = shift;

    my $status = 'notaff';

    my $entity_id = $self->get_shibboleth_entityID($C);
    if ($entity_id) {
        my $is_us = Institutions::get_institution_entityID_field_val($C, $entity_id, 'us');
        $status = ($is_us ? 'affus' : 'affnonus');
    }

    return $status;
}

# ---------------------------------------------------------------------

=item get_institution_name

Note this maps users SDRINST environment var or
eduPersonScopedAffiliation to the institution name.

=cut

# ---------------------------------------------------------------------
sub get_institution_name {
    my $self = shift;
    my $C = shift;
    my $mapped = shift;
    my $ignore_affiliation = shift;

    my $inst_name;

    my $entity_id = $self->get_shibboleth_entityID($C);
    my $affiliated = ( $ignore_affiliation ? 1 : $self->__get_prioritized_scoped_affiliation($C) );
    if ($entity_id && $affiliated) {
        $inst_name = Institutions::get_institution_entityID_field_val($C, $entity_id, 'name', $mapped);
    }
    else {
        my $inst_id = __get_institution_code_by_ip_address();
        $inst_name = Institutions::get_institution_inst_id_field_val($C, $inst_id, 'name', $mapped);
    }

    if ( $inst_name && $ignore_affiliation && $inst_name eq 'University of Michigan' && Utils::Get_Remote_User() !~ m,^[a-z]+$, ) {
        # make this obvious you're a friend
        $inst_name .= " - Friend";
    }


    return $inst_name;
}

# ---------------------------------------------------------------------

=item get_allowed_affiliations

Get allowed affiliations from ht_institutions.

=cut

# ---------------------------------------------------------------------
sub get_allowed_affiliations {
    my $self = shift;
    my $C = shift;
    my $mapped = shift;

    my $allowed_affiliations;

    my $entity_id = $self->get_shibboleth_entityID($C);
    if ($entity_id) {
        $allowed_affiliations = Institutions::get_institution_entityID_field_val($C, $entity_id, 'allowed_affiliations', $mapped);
    }
    else {
        my $inst_id = __get_institution_code_by_ip_address();
        $allowed_affiliations = Institutions::get_institution_inst_id_field_val($C, $inst_id, 'allowed_affiliations', $mapped);
    }

    return $allowed_affiliations;
}

sub get_institution_2fa_authcontext_class_ref {
    my $self = shift;
    my ( $C, $mapped ) = @_;
    my $entity_id = $self->get_shibboleth_entityID($C);
    if ( $entity_id eq $self->get_umich_IdP_entity_id() ) {
        return undef if ( defined $ENV{umichCosignFactor} && $ENV{umichCosignFactor} eq 'friend' );
    }

    my $authContextClassRef;
    $authContextClassRef = Institutions::get_institution_entityID_field_val($C, $entity_id, 'shib_authncontext_class', $mapped);

    return $authContextClassRef;
}

sub get_institution_template {
    my $self = shift;
    my $C = shift;
    my $mapped = shift;

    my $template;
    my $entity_id = $self->get_shibboleth_entityID($C);
    if ($entity_id) {
        $template = Institutions::get_institution_entityID_field_val($C, $entity_id, 'template', $mapped);
    }
    else {
        my $inst_id = __get_institution_code_by_ip_address();
        $template = Institutions::get_institution_inst_id_field_val($C, $inst_id, 'template', $mapped);
    }

    return $template;
}

# ---------------------------------------------------------------------

=item is_in_library

This plays a role in Section 108 brittle book access authorization and
pd full book PDF download. We do not currently have complete IP
addresses of non-UM Library buildings. If we did, we could consult the
Holdings database for book's condition when condition data becomes
available in that database.

As of Thu Mar 8 15:15:52 2012 We are adding LOC to the in-library IP
ranges.

As of Mon Apr 30 12:41:49 2012 We are adding NYPL to the in-library IP
ranges.

As of Mon Jun 4 13:38:38 2012 We are adding GETTY to the in-library IP
ranges.


=cut

# ---------------------------------------------------------------------
sub is_in_library {
    my $self = shift;

    return 0 if (DEBUG('nonlib'));
    return 1 if (DEBUG('inlib'));

    my $institution = __get_institution_code_by_ip_address();
    return ($institution && $ENV{SDRLIB});
}

# ---------------------------------------------------------------------

=item __get_prioritized_scoped_affiliation

Parse $ENV{affiliation} into its components.

Currently we support, at most, just
"member@foo.edu;staff@foo.edu;affiliate@foo.edu".  Return one of
these, in this priority order.

Return empty string if one of these affiliations is not present.

Some affiliates may have multiple affiliations. Use the FIRST one that
appears in the environment constrained to the hard-coded priority
list.

=cut

# ---------------------------------------------------------------------
sub __get_prioritized_scoped_affiliation {
    my $self = shift;
    my $C = shift;

    return $$self{__eduPerson_scoped_affiliation} if ( defined $$self{__eduPerson_scoped_affiliation} );

    my $eduPerson_scoped_affiliation = '';

    # prefer affiliations in this order. Not all of these may be
    # passed through to us via the Shib layer.
    my @affiliation_priorities = qw(member faculty staff student alum affiliate);

    my $environment = $ENV{affiliation} || '';

    my $allowed_affiliations = $self->get_allowed_affiliations($C);

    if ( $environment && $allowed_affiliations ) {
        my @scoped_affiliations = split(/\s*;\s*/, lc $environment);
        @scoped_affiliations = map {lc($_)} @scoped_affiliations;

        if (scalar @scoped_affiliations) {
            my $aff_data = $self->__get_scoped_affiliations($C, $allowed_affiliations);
            my $aff_hash = $$aff_data{data};
            my $aff_array = $$aff_data{index};

            foreach my $affiliation (@affiliation_priorities) {
                my $scoped_affiliations_ref = $$aff_hash{$affiliation} || [];
                if (scalar @$scoped_affiliations_ref) {
                    $eduPerson_scoped_affiliation = shift @$scoped_affiliations_ref;
                    last;
                }
            }

            if ( ! $eduPerson_scoped_affiliation && scalar @$aff_array ) {
                # did not find a prioritized affiliation, but we've recorded
                # an allowed affiliation in ht_institutions
                $eduPerson_scoped_affiliation = shift @{ $$aff_hash{$$aff_array[0]}  };
            }
        }
    }

    return ( $$self{__eduPerson_scoped_affiliation} = $eduPerson_scoped_affiliation );
}

sub __get_scoped_affiliations {
    my $self = shift;
    my $C = shift;
    my $allowed_affiliations = shift;

    my $environment = $ENV{affiliation} || '';

    my @scoped_affiliations = split(/\s*;\s*/, lc $environment);
    @scoped_affiliations = map {lc($_)} @scoped_affiliations;

    my %aff_hash = (); my $aff_array = [];
    if (scalar @scoped_affiliations) {
        foreach my $scoped_affiliation (@scoped_affiliations) {
            next unless ( $scoped_affiliation =~ m,$allowed_affiliations,i );
            my ($affiliation, $security_domain) = split(/@/, $scoped_affiliation);

            if ($affiliation && $security_domain) {
                # $aff_hash{$affiliation} = [] unless (exists $aff_hash{$affiliation});
                unless (exists $aff_hash{$affiliation}) {
                    $aff_hash{$affiliation} = [];
                    push @$aff_array, $affiliation;
                }

                my $scoped_affiliations_ref = $aff_hash{$affiliation};
                push( @$scoped_affiliations_ref, $scoped_affiliation );
                $aff_hash{$affiliation} = $scoped_affiliations_ref;
            }
        }
    }

    return { data => \%aff_hash, index => $aff_array };
}

# ---------------------------------------------------------------------

=item get_eduPersonScopedAffiliation

This is the full eduPersonScopedAffiliation, e.g. member@umich.edu

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#eduPersonScopedAffiliation

=cut

# ---------------------------------------------------------------------
sub get_eduPersonScopedAffiliation {
    my $self = shift;
    my $C = shift;

    my $eduPersonScopedAffiliation = '';

    if ($self->auth_sys_is_COSIGN($C)) {
        if (! $self->login_realm_is_friend) {
            $eduPersonScopedAffiliation = 'member@umich.edu';
        }
    }
    elsif ($self->auth_sys_is_SHIBBOLETH($C)) {
        $eduPersonScopedAffiliation = $self->__get_prioritized_scoped_affiliation($C);
    }

    return $eduPersonScopedAffiliation;
}

# ---------------------------------------------------------------------

=item get_eduPersonUnScopedAffiliation

This is the affiliation part of eduPersonScopedAffiliation,
e.g. member, stripped of the security_domain, e.g. umich.edu

=cut

# ---------------------------------------------------------------------
sub get_eduPersonUnScopedAffiliation {
    my $self = shift;
    my $C = shift;

    my $eduPersonScopedAffiliation = $self->get_eduPersonScopedAffiliation($C);

    my ($eduPersonUnScopedAffiliation) = ( $eduPersonScopedAffiliation =~ m,^(.*?)@.*$, );

    $eduPersonUnScopedAffiliation = '' unless ($eduPersonUnScopedAffiliation);

    return $eduPersonUnScopedAffiliation;
}

# ---------------------------------------------------------------------

=item get_eduPersonPrincipalName

This is the eduPersonPrincipalName, e.g. janedoe@umich.edu

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#eduPersonPrincipalName

=cut

# ---------------------------------------------------------------------
sub get_eduPersonPrincipalName {
    my $self = shift;
    my $C = shift;

    my $eduPersonPrincipalName;

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        $eduPersonPrincipalName = $ENV{eppn} || '';
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        if ($self->login_realm_is_friend) {
            $eduPersonPrincipalName = Utils::Get_Remote_User();
        }
        else {
            my $remote_user = Utils::Get_Remote_User();
            $eduPersonPrincipalName = ($remote_user ? $remote_user . '@umich.edu' : '');
        }
    }

    return $eduPersonPrincipalName;
}

# ---------------------------------------------------------------------

=item get_unscoped_eduPersonPrincipalName

This is the eduPersonPrincipalName stripped of security_domain,
e.g. janedoe from janedoe@umich.edu

http://www.incommon.org/federation/attributesummary.html#eduPersonPrincipal

=cut

# ---------------------------------------------------------------------
sub get_unscoped_eduPersonPrincipalName {
    my $self = shift;
    my $C = shift;

    my $eduPersonPrincipalName = $self->get_eduPersonPrincipalName($C);

    my ($eduPersonUnScopedPrincipalName) = ( $eduPersonPrincipalName =~ m,^(.*?)@.*$, );

    $eduPersonUnScopedPrincipalName = '' unless ($eduPersonUnScopedPrincipalName);


    return $eduPersonUnScopedPrincipalName;
}

# ---------------------------------------------------------------------

=item __get_shibboleth_print_disability_entitlement

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#eduPersonEntitlement

The Shibboleth entitlement values follow the URL-type scheme:

http://www.hathitrust.org/access/standard
http://www.hathitrust.org/access/enhancedText
http://www.hathitrust.org/access/enhancedTextProxy

standard - no special privs
enhancedText - print disabled
enhancedTextProxy - assist print disabled

=cut

# ---------------------------------------------------------------------
sub __get_shibboleth_print_disability_entitlement {
    my $self = shift;
    my $C = shift;

    my $entitlement = '';

    if (Auth::ACL::S___superuser_role) {
        $entitlement = 'ssd' if (DEBUG('ssd'));
        $entitlement = 'ssdproxy' if (DEBUG('ssdproxy'));
    }

    unless ($entitlement) {
        if ($self->auth_sys_is_SHIBBOLETH($C)) {
            my $unscoped_aff = $self->get_eduPersonUnScopedAffiliation($C);
            if ($unscoped_aff =~ m/$ENTITLEMENT_VALID_AFFILIATIONS_REGEXP/) {
                my $env_entitlement = $ENV{entitlement} || '';
                my @eduPersonEntitlement_vals = split(/;/, $env_entitlement);

                if ( grep(/$ENTITLEMENT_PRINT_DISABLED_VALUE/, @eduPersonEntitlement_vals) ) {
                    $entitlement = 'ssd';
                }
                elsif ( grep(/$ENTITLEMENT_PRINT_DISABLED_PROXY_VALUE/, @eduPersonEntitlement_vals) ) {
                    $entitlement = 'ssdproxy';
                }
                else {
                }
            }
        }
    }

    return $entitlement;
}

# ---------------------------------------------------------------------

=item get_PrintDisabledProxyUserSignature

Description

=cut

# ---------------------------------------------------------------------
sub get_PrintDisabledProxyUserSignature {
    my $self = shift;
    my $C = shift;

    my $signature = '';

    if ( $self->user_is_print_disabled_proxy($C) ) {
        $signature = Auth::ACL::a_GetUserAttributes('userid');
    }

    return $signature;
}

# ---------------------------------------------------------------------

=item user_is_print_disabled_proxy

Description

=cut

# ---------------------------------------------------------------------
sub user_is_print_disabled_proxy {
    my $self = shift;
    my $C = shift;

    # ACL test
    my $is_proxy = Auth::ACL::a_Authorized( {role => 'ssdproxy'} );
    # Authentication test
    unless ($is_proxy) {
        my $entitlement = $self->__get_shibboleth_print_disability_entitlement($C);
        $is_proxy = ($entitlement eq 'ssdproxy');
    }

    return $is_proxy;
}

# ---------------------------------------------------------------------

=item user_is_print_disabled

Description

=cut

# ---------------------------------------------------------------------
sub user_is_print_disabled {
    my $self = shift;
    my $C = shift;

    # ACL test
    my $is_disabled = (
                       Auth::ACL::a_Authorized( {role => 'ssd'})
                       ||
                       Auth::ACL::a_Authorized( {role => 'ssdnfb'})
                      );
    # Authentication test
    unless ($is_disabled) {
        my $entitlement = $self->__get_shibboleth_print_disability_entitlement($C);
        $is_disabled = ($entitlement eq 'ssd') || ($entitlement eq 'ssdnfb')
    }

    return $is_disabled;
}

# ---------------------------------------------------------------------

=item get_eduPersonEntitlement_print_disabled

This is the eduPersonEntitlement attribute value that equates to print
disabled status. It covers all the cases of print-disability access:

1) ssd/ssdnfb (a disabled user)
2) ssdproxy (a user entitled to act on behalf of a disabled user)

If it is necessary to differentiate between (1) and (2) call
user_is_print_disabled[_proxy]

=cut

# ---------------------------------------------------------------------
sub get_eduPersonEntitlement_print_disabled {
    my $self = shift;
    my $C = shift;

    return $self->user_is_print_disabled($C) || $self->user_is_print_disabled_proxy($C);
}

# ---------------------------------------------------------------------

=item get_shibboleth_entityID

The entityID allows us to determine, independent of multiple
eduPersonScopedAffiliation values, with which institution the
authenticated user is affiliated.

=cut

# ---------------------------------------------------------------------
sub get_shibboleth_entityID {
    my $self = shift;
    my $C = shift;

    my $entity_id = '';

    if ($self->auth_sys_is_COSIGN($C)) {
        if (! $self->login_realm_is_friend) {
            $entity_id = $UMICH_ENTITY_ID;
        }
    }
    elsif ($self->auth_sys_is_SHIBBOLETH($C)) {
        $entity_id = $ENV{Shib_Identity_Provider} || $ENV{'Shib-Identity-Provider'}
    }

    return $entity_id;
}

# ---------------------------------------------------------------------

=item get_eduPersonTargetedID

This is the eduPersonTargetedID, a persistent, non-reassigned,
privacy-preserving identifier for a principal shared between a pair of
coordinating entities, denoted by the SAML 2 architectural overview
[1] as identity provider and service provider (or a group of service
providers).

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#eduPersonTargetedID

We have seen the umich IdP assign the semi-colon separated
concatenation of the old:

urn:mace:dir:attribute-def:eduPersonTargetedID

and the new:

OID: 1.3.6.1.4.1.5923.1.1.1.10 values to persistent_id. We parse just one out.

=cut

# ---------------------------------------------------------------------
sub get_eduPersonTargetedID {
    my $self = shift;

    my $targeted_id = '';
    $targeted_id = $ENV{persistent_id} if ( defined $ENV{persistent_id} );
    $targeted_id = $ENV{'persistent-id'} if ( defined $ENV{'persistent-id'} );
    return ( split(/;/, $targeted_id) )[0] || '';
}

# ---------------------------------------------------------------------

=item __get_parsed_displayName

Parse eduPerson displayName. We've seen the environment return exactly
both: '&amp;eacute\;' and '&eacute\;' de-shibify the escaped
semi-colons and unescape the &amp; contextually for both character
entity references and for numeric character references.

=cut

# ---------------------------------------------------------------------
sub __get_parsed_displayName {
    my $self = shift;

    my $name = $ENV{displayName} || '';
    # unescape XML and un-shibify semicolons
    $name =~ s,(&)(amp;)?(#?x?[a-zA-Z0-9]+)\\(;),$1$3$4,gi;
    # map to parseable NCRs
    $name =~ s,(&[a-zA-Z0-9]+;),&Utils::minimal_CER_to_NCR_map($1),eg;

    return $name;
}

# ---------------------------------------------------------------------

=item __get_displayName

This is the displayName attribute, e.g. Franklin Lumpkin, Esq.

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#displayName

users of Auth::Auth should call:

$self->get_user_display_name($C, [scoped(0)|unscoped(1)])

=cut

# ---------------------------------------------------------------------
sub __get_displayName {
    my $self = shift;
    my $C = shift;

    my $displayName = 'anonymous';

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        $displayName = $self->__get_parsed_displayName();
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        $displayName = Utils::Get_Remote_User();
    }

    return $displayName;
}

# ---------------------------------------------------------------------

=item affiliation_is_umich

This currently is for in-copyright out-of-print-brittle extended
access not limited to being "in a library"

=cut

# ---------------------------------------------------------------------
sub affiliation_is_umich {
    my $self = shift;
    my $C = shift;

    my $is_umich = 0;

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        my $aff = $self->get_eduPersonScopedAffiliation($C);
        $is_umich = (lc($aff) =~ m,umich.edu$,);
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        if (! $self->login_realm_is_friend()) {
            $is_umich = 1;
        }
        else {
            $is_umich = 0;
        }
    }
    else {
        $is_umich = 0;
    }

    return $is_umich;
}


# ---------------------------------------------------------------------

=item affiliation_is_hathitrust

This affiliation may provide for expanded services such as full book
pdf download for certain classes of materials.

=cut

# ---------------------------------------------------------------------
sub affiliation_is_hathitrust {
    my $self = shift;
    my $C = shift;

    return 1 if (DEBUG('hathi'));

    my $is_hathitrust = 0;

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        my $aff = lc($self->get_eduPersonScopedAffiliation($C));
        my $entity_id = lc($self->get_shibboleth_entityID($C));
        # If there's a scoped affiliation then they're hathitrust
        $is_hathitrust = ( $aff ne '' ) && ( ! defined $$NON_HT_AFFILIATED_ENTITY_IDS{$entity_id} );
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        if (! $self->login_realm_is_friend) {
            $is_hathitrust = 1;
        }
        else {
            $is_hathitrust = 0;
        }
    }
    else {
        $is_hathitrust = 0;
    }

    return $is_hathitrust;
}

# ---------------------------------------------------------------------

=item affiliation_is_enhanced_text_user

This affiliation allows for greater access in reading,
but more limited download options.

=cut

# ---------------------------------------------------------------------
sub affiliation_is_enhanced_text_user {
    my $self = shift;
    my $C = shift;

    return 1 if (DEBUG('nfb'));
    return 1 if (DEBUG('marrakesh'));

    my $is_enhanced_text_user = 0;

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        my $aff = lc($self->get_eduPersonScopedAffiliation($C));
        $is_enhanced_text_user = ( $aff eq 'member@nfb.org' );
    }
    else {
        $is_enhanced_text_user = 0;
    }

    return $is_enhanced_text_user;
}

sub affiliation_has_emergency_access {
    my $self = shift;
    my $C = shift;

    return 1 if (DEBUG('emergency'));

    my $is_emergency_access_user = 0;
    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        my $entity_id = $self->get_shibboleth_entityID($C);
        if ($entity_id) {
            my $emergency_status = Institutions::get_institution_entityID_field_val($C, $entity_id, 'emergency_status') || "";
            if ( $emergency_status eq "1" ) {
                $is_emergency_access_user = 1;
            } elsif ( $emergency_status =~ m,\@, ) {
                # checking affiliations
                my $check = $self->__get_scoped_affiliations($C, $emergency_status);
                $is_emergency_access_user = ( scalar @{$$check{index}} > 0 );
            }
        }
    }

    return $is_emergency_access_user;

}

# ---------------------------------------------------------------------

=item get_user_display_name

This is either the user's COSIGN uniquename or, using a fallback scheme
Shibboleth displayName, eppn, etc.

=cut

# ---------------------------------------------------------------------
sub get_user_display_name {
    my $self = shift;
    my $C = shift;
    my $unscoped = shift;

    my $user_display_name = 'anonymous';

    if ($C->has_object('Session')) {
        if ($self->is_logged_in()) {
            if ( $self->user_is_print_disabled_proxy($C) ) {
                # We want value recorded in ht.ht_users not environment
                # displayName or affiliation values
                $user_display_name = Auth::ACL::a_GetUserAttributes('displayname');
            }
            elsif ($self->auth_sys_is_COSIGN($C)) {
                $user_display_name = Utils::Get_Remote_User();
            }
            elsif ($self->auth_sys_is_SHIBBOLETH($C)) {
                $user_display_name = $self->__get_displayName($C);
                unless ($user_display_name) {
                    $user_display_name =
                      ( $unscoped
                        ? $self->get_unscoped_eduPersonPrincipalName($C)
                        : $self->get_eduPersonPrincipalName($C) );
                }
                unless ($user_display_name) {
                    $user_display_name =
                      ( $unscoped
                        ? $self->get_eduPersonUnScopedAffiliation($C)
                        : $self->get_eduPersonScopedAffiliation($C) );
                }
            }
            unless ( $user_display_name ) {
                $user_display_name = $self->__guess_displayName();
            }
        }
        else {
            # not authenticated
            $user_display_name = 'guest';
        }
    }

    return $user_display_name;
}

# ---------------------------------------------------------------------

=item __guess_displayName

determines a user display name from the raw $ENV{affiliation}
(vs. the allowed affiliations from ht_institutions)

=cut

# ---------------------------------------------------------------------
sub __guess_displayName {
    my $self = shift;
    my $user_display_name = q{visitor};
    my $affiliation = defined $ENV{affiliation} ? lc $ENV{affiliation} : '';
    if ( $affiliation =~ m,student, ) {
        $user_display_name = q{student};
    } elsif ( $affiliation =~ m,faculty, ) {
        $user_display_name = q{faculty};
    } elsif ( $affiliation =~ m,staff, ) {
        $user_display_name = q{staff};
    }
    return $user_display_name;
}


# ---------------------------------------------------------------------

=item get_user_name

return either the users COSIGN uniquename or Shibboleth
persistent-id or eppn (these are mapped to REMOTE_USER in
shibboleth2.xml) if logged in or the session id if not

=cut

# ---------------------------------------------------------------------
sub get_user_name {
    my $self = shift;
    my $C = shift || new Context;

    my $user_id;

    if ($self->is_logged_in()) {
        $user_id = Utils::Get_Remote_User();
    }
    else {
        if ($C->has_object('Session')) {
            my $ses = $C->get_object('Session');
            $user_id = $ses->get_session_id();
        }
        else {
            $user_id = '0';
        }
    }

    return $user_id;
}

sub get_legacy_user_name {
    my $self = shift;
    my $C = shift;
    my $user_id;
    if ( $self->is_logged_in() && $self->get_institution_code($C, 1) eq 'umich' ) {
        return Utils::Get_Legacy_Remote_User();
    }
    return $user_id;
}

sub get_user_names {
    my $self = shift;
    my $C = shift || new Context();

    my @user_ids = ();
    if ($self->is_logged_in()) {
        push @user_ids, Utils::Get_Remote_User_Names();
    }
    else {
        if ($C->has_object('Session')) {
            my $ses = $C->get_object('Session');
            push @user_ids, $ses->get_session_id();
        }
        else {
             #$user_id = '0';
        }
    }
    return @user_ids;
}


# ---------------------------------------------------------------------

=item isa_new_login

True if the user's session was not logged in until now.

=cut

# ---------------------------------------------------------------------
sub isa_new_login {
    my $self = shift;
    my $C = shift;
    if ( defined $C && $C->get_object('Session')->get_persistent('_isa_new_login_via_pong') ) {
        $C->get_object('Session')->set_persistent('_isa_new_login_via_pong', 0);
        return 1;
    }
    return $self->{'isa_new_login'} ? 1 : 0;
}

# ---------------------------------------------------------------------

=item set_isa_new_login

Set whether the user's session was not logged in until now.

=cut

# ---------------------------------------------------------------------
sub set_isa_new_login {
    my $self = shift;
    my $isa = shift;
    $self->{'isa_new_login'} = $isa;
}

sub is_cosign_active {
    my $self = shift;
    return Utils::is_cosign_active();
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007, 2010, 2012 ©, The Regents of The University of Michigan, All Rights Reserved

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
