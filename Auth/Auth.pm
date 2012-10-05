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

use File::Basename;
use XML::LibXML;

use Utils;
use Debug::DUtils;
use Session;
use Auth::Exclusive;

use constant COSIGN => 'cosign';
use constant SHIBBOLETH => 'shibboleth';
use constant FRIEND => 'friend';

# eduPersonENtitlement attribute values that qualify as print disabled
my $ENTITLEMENT_PRINT_DISABLED_REGEXP =
  qr,^http://www.hathitrust.org/access/(enhancedText|enhancedTextProxy)$,ios;

# Which eduPersonScopedAffiliation attribute values can be considered
# for print disabled status
my $ENTITLEMENT_VALID_AFFILIATIONS_REGEXP =
  qr,^(member|faculty|staff|student)$,ios;

use constant UMICH_SSD_LIST =>
  qw (
      aaehawki
      benmb
      bervilla
      brekac
      ccarpey
      crwils
      damincki
      echols
      forbess
      gsheena
      hkanter
      ijohns
      jrcarmon
      jrmorak
      kimjiy
      kmbally
      kqread
      kshalosk
      mikenuss
      mshoe
      nicolejg
      nlcp
      noahw
      orodrigu
      rgottfri
      rlfabry
      rparten
      rubind
      shanorwo
      sileo
      sydfried
    );

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
              q{AUTH: user=} . $self->get_user_name($C) . q{ disp=} . $self->get_user_display_name($C)
                . q{ loggedin=} . $self->is_logged_in() . q{ in_library=} . $self->is_in_library()
                  . q{ authsys=} . __get_auth_sys($ses)
                    . q{ newlogin=} . $self->isa_new_login()
                      . q{ parsed_persistent_id=} . $self->get_eduPersonTargetedID()
                        . q{ prioritized_scoped_affiliation=} . $self->get_eduPersonScopedAffiliation($C)
                          . q{ institution code=} . $self->get_institution_code($C)
                            . q{ institution name=} . $self->get_institution_name($C)
                              . q{ is_umich=} . $self->affiliation_is_umich($C)
                                . q{ is_hathitrust=} . $self->affiliation_is_hathitrust($C)
                                  . q{ entitlement=} . $ENV{entitlement}
                                    . q{ print-disabled=} . $self->get_eduPersonEntitlement_print_disabled($C);
          });
}

sub _initialize {
    my $self = shift;
    my $C = shift;

    $self->{institution_map} = __load_institutions_xml($C);

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
            # Not authenticated: THIS MAY BE CONDITION X:
            # See pod (above).
            $self->__debug_auth($C, $ses);
            $self->handle_possible_redirect($C, $was_logged_in_via);
            # POSSIBLY NOTREACHED
        }
    }
}

# ---------------------------------------------------------------------

=item __load_institutions_xml

Description

=cut

# ---------------------------------------------------------------------
sub __load_institutions_xml {
    my $C = shift;

    my $app = $C->get_object('App')->get_app_name($C);
    my $institution_file = qq{$ENV{SDRROOT}/$app/web/common-web/institutions.xml};

    my $xml_ref = Utils::read_file($institution_file);
    my $parser = XML::LibXML->new();
    my $tree = $parser->parse_string($$xml_ref);
    my $root = $tree->getDocumentElement();

    my $xpath = q{/Institutions/Inst};
    my $xml_instMap = $root->findnodes($xpath);
    my $inst_map = {};

    foreach my $inst ($xml_instMap->get_nodelist) {
        my $domain = $inst->getAttribute('domain');
        $inst_map->{$domain} = {
            'sdrinst' => $inst->getAttribute('sdrinst'),
            'us'      => $inst->getAttribute('us'),
            'name'    => $inst->textContent
        };
    }

    return $inst_map;
}

# ---------------------------------------------------------------------

=item get_institution_map

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_map {
    my $self = shift;
    return $self->{institution_map}
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

    if ($was_logged_in_via eq COSIGN) {
        my $redirect_to = $self->get_COSIGN_login_href($cgi);
        print $cgi->redirect($redirect_to);
        exit;
    }
    elsif ($was_logged_in_via eq SHIBBOLETH) {
        my $redirect_to = $self->get_SHIBBOLETH_login_href($cgi);
        print $cgi->redirect($redirect_to);
        exit;
    }
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
    $login_href =~ s,/cgi/,/shcgi/,;
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

    $WAYF_url =~ s,___HOST___,$ENV{'HTTP_HOST'},;
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
    $ses->set_persistent('authenticated_via', lc($ENV{AUTH_TYPE}));
}

# ---------------------------------------------------------------------

=item __get_auth_sys

PRIVATE CLASS METHOD

=cut

# ---------------------------------------------------------------------
sub __get_auth_sys {
    my $ses = shift;
    return $ses->get_persistent('authenticated_via');
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
    my $is = 1;

    if ($C->has_object('Session')) {
        my $ses = $C->get_object('Session');
        $is = ($ses->get_persistent('authenticated_via') eq COSIGN);
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
        $is = ($ses->get_persistent('authenticated_via') eq SHIBBOLETH);
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
    return exists($ENV{'REMOTE_USER'});
}

# ---------------------------------------------------------------------

=item login_realm_is_friend

true if user has authenticated and the cosign realm is "friend"

=cut

# ---------------------------------------------------------------------
sub login_realm_is_friend {
    my $self = shift;
    return ($self->is_logged_in() && (lc($ENV{'REMOTE_REALM'}) eq FRIEND));
}

# ---------------------------------------------------------------------

=item __get_institution_by_ip_address

*** PRIVATE CLASS METHOD ***

Note this associates the REMOTE_ADDR via a list of institutions codes
maintained by Core Services for Apache.

Clients of this class should use get_institution_code()

=cut

# ---------------------------------------------------------------------
sub __get_institution_by_ip_address {
    return $ENV{'SDRINST'};
}

# ---------------------------------------------------------------------

=item get_institution_code

Note this maps users eduPersonScopedAffiliation to the institution code.

=cut

# ---------------------------------------------------------------------
sub get_institution_code {
    my $self = shift;
    my $C = shift;

    my $aff = $self->get_eduPersonScopedAffiliation($C);
    my $map_ref = $self->get_institution_map();

    my $inst_code;

    if ($aff) {
        my ($domain) = ($aff =~ m,^.*?@(.*?)$,);
        $inst_code = $map_ref->{$domain}->{sdrinst};
    }
    else {
        my $inst = __get_institution_by_ip_address();
        # Try a lookup by SDRINST
        foreach my $domain (keys %$map_ref) {
            if ($map_ref->{$domain}->{sdrinst} eq $inst) {
                $inst_code = $map_ref->{$domain}->{sdrinst};
                last;
            }
        }
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

    my $aff = $self->get_eduPersonScopedAffiliation($C);
    if ($aff) {
        my $map_ref = $self->get_institution_map();
        my ($domain) = ($aff =~ m,^.*?@(.*?)$,);
        $status = $map_ref->{$domain}->{us} ? 'affus' : 'affnonus';
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

    my $aff = $self->get_eduPersonScopedAffiliation($C);
    my $map_ref = $self->get_institution_map();

    my $inst_name;

    if ($aff) {
        my ($domain) = ($aff =~ m,^.*?@(.*?)$,);
        $inst_name = $map_ref->{$domain}->{name};
    }
    else {
        my $inst = __get_institution_by_ip_address();
        # Try a lookup by SDRINST
        foreach my $domain (keys %$map_ref) {
            if ($map_ref->{$domain}->{sdrinst} eq $inst) {
                $inst_name = $map_ref->{$domain}->{name};
                last;
            }
        }
    }

    return $inst_name;
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

    my $institution = __get_institution_by_ip_address();
    return ($institution && $ENV{SDRLIB});
}


# ---------------------------------------------------------------------

=item is_in_uom_library

See is_in_library

=cut

# ---------------------------------------------------------------------
sub is_in_uom_library {
    my $self = shift;
    my $institution = __get_institution_by_ip_address();

    return ($institution && ($institution eq 'uom') && $ENV{'SDRLIB'});
}


# ---------------------------------------------------------------------

=item __get_prioritized_scoped_affiliation

Parse $ENV{affiliation} into its components.

Currently we support, at most, just
"member@foo.edu;staff@foo.edu;affiliate@foo.edu".  Return one of
these, in this priority order.

Return undef if one of these affiliations is not present.

=cut

# ---------------------------------------------------------------------
sub __get_prioritized_scoped_affiliation {
    my $self = shift;

    my @aff_prios = qw(member faculty staff student alum affiliate);
    my @affs = split(/\s*;\s*/, $ENV{'affiliation'});
    @affs = map {lc($_)} @affs;

    my %aff_hash = map { ($_) =~ (m,(.*?)@.*$,) => $_ } @affs;

    foreach my $aff (@aff_prios) {
        return $aff_hash{$aff} if ($aff_hash{$aff});
    }

    return undef;
}

# ---------------------------------------------------------------------

=item __get_prioritized_unscoped_affiliation

Parse $ENV{affiliation} into its components and strips the @foo.edu part.

=cut

# ---------------------------------------------------------------------
sub __get_prioritized_unscoped_affiliation {
    my $self = shift;

    my $scoped_aff = $self->__get_prioritized_scoped_affiliation();
    my ($unscoped_aff) = ($scoped_aff =~ m,^(.*?)@.*$,);

    return $unscoped_aff;
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

    my $eduPersonScopedAffiliation;

    if ($self->auth_sys_is_COSIGN($C)) {
        if (! $self->login_realm_is_friend()) {
            $eduPersonScopedAffiliation = 'member@umich.edu';
        }
    }
    elsif ($self->auth_sys_is_SHIBBOLETH($C)) {
        $eduPersonScopedAffiliation = $self->__get_prioritized_scoped_affiliation();
    }

    return $eduPersonScopedAffiliation;
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
        $eduPersonPrincipalName = $ENV{'eppn'};
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        if ($self->login_realm_is_friend()) {
            $eduPersonPrincipalName = $ENV{'REMOTE_USER'};
        }
        else {
            $eduPersonPrincipalName = $ENV{'REMOTE_USER'} . '@umich.edu';
        }
    }

    return $eduPersonPrincipalName;
}

# ---------------------------------------------------------------------

=item get_eduPersonEntitlement_print_disabled

This is the eduPersonEntitlement attribute value that equates to print disabled status.

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#eduPersonEntitlement

The values follow the URL-type scheme:

http://www.hathitrust.org/access/standard
http://www.hathitrust.org/access/enhancedText
http://www.hathitrust.org/access/enhancedTextProxy
where N can be:

standard - no special privs
enhancedText - print disabled
enhancedTextProxy - assist print disabled

=cut

# ---------------------------------------------------------------------
sub get_eduPersonEntitlement_print_disabled {
    my $self = shift;
    my $C = shift;

    my $is_print_disabled = 0;

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        my $unscoped_aff = $self->__get_prioritized_unscoped_affiliation();
        if ($unscoped_aff =~ m/$ENTITLEMENT_VALID_AFFILIATIONS_REGEXP/) {
            my @eduPersonEntitlement_vals = split(/;/, $ENV{entitlement});
            $is_print_disabled = grep(/$ENTITLEMENT_PRINT_DISABLED_REGEXP/, @eduPersonEntitlement_vals);
        }
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        $is_print_disabled = grep(/^$ENV{REMOTE_USER}$/, UMICH_SSD_LIST) || DEBUG('ssd');
    }

    return $is_print_disabled;
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
    return ( split(/;/, $ENV{'persistent_id'}) )[0];
}

# ---------------------------------------------------------------------

=item __get_parsed_displayName

Parse eduperson displayName returning first element in case multiple
values are released.

=cut

# ---------------------------------------------------------------------
sub __get_parsed_displayName {
    my $self = shift;

    my @elems = split(/\s*;\s*/, $ENV{displayName});

    return $elems[0];
}

# ---------------------------------------------------------------------

=item get_displayName

This is the displayName attribute, e.g. Franklin Lumpkin, Esq.

http://middleware.internet2.edu/eduperson/docs/internet2-mace-dir-eduperson-200806.html#displayName

=cut

# ---------------------------------------------------------------------
sub get_displayName {
    my $self = shift;
    my $C = shift;

    my $displayName = 'anonymous';

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        $displayName = $self->__get_parsed_displayName();
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        $displayName = $ENV{'REMOTE_USER'};
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

    my $is_hathitrust = 0;

    if ($self->auth_sys_is_SHIBBOLETH($C)) {
        my $aff = lc($self->get_eduPersonScopedAffiliation($C));
        # If there's a scoped affiliation then they're hathitrust
        $is_hathitrust = $aff;
    }
    elsif ($self->auth_sys_is_COSIGN($C)) {
        if (! $self->login_realm_is_friend()) {
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

=item get_user_display_name

This is either the user's COSIGN uniquename or, using a fallback scheme
Shibboleth displayName, eppn, etc.

=cut

# ---------------------------------------------------------------------
sub get_user_display_name {
    my $self = shift;
    my $C = shift;

    my $user_display_name = 'anonymous';

    if ($C->has_object('Session')) {
        if ($self->is_logged_in()) {
            if ($self->auth_sys_is_COSIGN($C)) {
                $user_display_name = $ENV{'REMOTE_USER'};
            }
            elsif ($self->auth_sys_is_SHIBBOLETH($C)) {
                $user_display_name =
                    $self->get_displayName($C)
                            || $self->get_eduPersonScopedAffiliation($C);
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

=item get_user_name

return either the users COSIGN uniquename or Shibboleth
persistent-id or eppn (these are mapped to REMOTE_USER in
shibboleth2.xml) if logged in or the session id if not

=cut

# ---------------------------------------------------------------------
sub get_user_name {
    my $self = shift;
    my $C = shift;

    my $user_id;

    if ($self->is_logged_in()) {
        $user_id = $ENV{'REMOTE_USER'};
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


# ---------------------------------------------------------------------

=item isa_new_login

True if the user's session was not logged in until now.

=cut

# ---------------------------------------------------------------------
sub isa_new_login {
    my $self = shift;
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


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-2010 ©, The Regents of The University of Michigan, All Rights Reserved

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
