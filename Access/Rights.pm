package Access::Rights;

=head1 NAME

Access::Rights (ar);

=head1 DESCRIPTION

This class encapsulates the logic determining for a _given_id_ whether
the user has access to it.

It can also be instantiated without an id and used to determine for
this user which rights attribute values equate to 'fulltext'.

=head1 VERSION

=head1 SYNOPSIS

Do NOT call any of the PRIVATE: methods directly.

$ar = new Access::Rights($C, [$id]);

The $id can be undef if the no method requiring an id parameter is
called.

$rights_attribute = $ar->get_rights_attribute($C, $id);

where $rights_attribute is a number from (1..9) with 0 being bad
symbolically represented by RightsGlobals::NOOP_ATTRIBUTE;

$source_attribute = $ar->get_source_attribute($C, $id);

where $source_attribute is a number from (1...) with 0 being bad
symbolically represented by RightsGlobals::NOOP_ATTRIBUTE;

$final_accessstatus = $ar->assert_final_access_status($C, $id);

where $final_accessstatus is a string from ('allow', 'deny',
'unknown') the last value only being possible if an invalid id is
passed in or the id is not in the database.

NOTE: THIS METHOD HAS THE SIDE-EFFECT OF CAPTURING THE ID EXCLUSIVELY
FOR A GIVEN USER FOR OPB ITEMS. To just CHECK the final_access_status
that includes the possibility of exclusive capture use the following
method.

$final_accessstatus = $ar->check_final_access_status($C, $id);

For the preceeding two calls, the Context object must contain at least
a CGI and an Database object.  Session is optional to
maintain state for 'ssd' users, e.g. SSD students.

For the next class method, the Context object may be empty.

$attr_list_ref = Access::Rights::get_fulltext_attr_list($C)

Returns those rights attributes for this user in this location that
equate to fulltext access.

=head1 METHODS

=over 8

=cut

use CGI;
use Context;
use Utils;
use Debug::DUtils;
use Session;
use Database;
use Identifier;
use DbUtils;
use Auth::Auth;
use Auth::Exclusive;
use RightsGlobals;
use MirlynGlobals;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Description

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my ($C, $id) = @_;
    $self->{'id'} = $id;
}


# ---------------------------------------------------------------------

=item PUBLIC: get_rights_attribute

 ATTRIBUTES
 id name   type      dscr
 1  pd     copyright public domain
 2  ic     copyright in-copyright
 3  opb    copyright out-of-print and brittle (implies in-copyright)
 4  orph   copyright copyright-orphaned (implies in-copyright)
 5  und    copyright undetermined copyright status
 6  umall  access    available to UM affiliates and walk-in patrons (all campuses)
 7  world  access    available to everyone in the world
 8  nobody access    available to nobody; blocked for all users
 9  pdus   copyright public domain only when viewed in the US

 Creative Commons

 id name       type      dscr
 10 ccby       copyright attribute work in manner specified by author
 11 ccby-nd    copyright ccby + no derivatives upon distribution
 12 ccby-nc-nd copyright ccby-nd + only non-commercial use only     
 13 ccby-nc    copyright ccby +  only non-commercial use only     
 15 ccby-nc-sa copyright ccby-nc + ccby-sa     
 15 ccby-sa    copyright ccby + same license upon redistribution

 Creative Commons Links

 10 ccby       http://www.hathitrust.org/documents/notice_cc_by.txt
 11 ccby-nd    http://www.hathitrust.org/documents/notice_cc-by-nd.txt
 12 ccby-nc-nd http://www.hathitrust.org/documents/notice_cc_by-nc-nd.txt
 13 ccby-nc    http://www.hathitrust.org/documents/notice_cc_by-nc.txt
 15 ccby-nc-sa http://www.hathitrust.org/documents/notice_cc_by-nc-sa.txt
 15 ccby-sa    http://www.hathitrust.org/documents/notice_cc-by-sa.txt

=cut

# ---------------------------------------------------------------------
sub get_rights_attribute {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);

    return $self->{'rights_attribute'}
        if (defined($self->{'rights_attribute'}));

    # Access rights database
    my ($rights_attribute, $rc) = _determine_rights_attribute($C, $id);

    $rights_attribute = RightsGlobals::NOOP_ATTRIBUTE
        if ($rc != RightsGlobals::OK_ID);

    $self->{'rights_attribute'} = $rights_attribute;

    return $rights_attribute;
}


# ---------------------------------------------------------------------

=item PUBLIC: get_source_attribute

SOURCES
id 	name 	    dscr
1 	google 	    Google
2 	lit-dlps-dc LIT, DLPS, Digital Conversion
3       um press
4       ia          Internet Archive

=cut

# ---------------------------------------------------------------------
sub get_source_attribute {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);

    return $self->{'source_attribute'}
        if (defined($self->{'source_attribute'}));

    # Access rights database
    my ($source_attribute, $rc) = _determine_source_attribute($C, $id);

    $source_attribute = RightsGlobals::NOOP_ATTRIBUTE
        if ($rc != RightsGlobals::OK_ID);

    $self->{'source_attribute'} = $source_attribute;

    return $source_attribute;
}


# ---------------------------------------------------------------------

=item CLASS PUBLIC: get_fulltext_attr_list

For this user, which rights attributes equate to 'fulltext'

=cut

# ---------------------------------------------------------------------
sub get_fulltext_attr_list {
    my $C = shift;
    return _get_final_access_status_attr_list($C, 'allow');
}

# ---------------------------------------------------------------------

=item PUBLIC: assert_final_access_status

Determine access rights for this id and assert exclusive ownership for
id attribute values like opb.

=cut

# ---------------------------------------------------------------------
sub assert_final_access_status {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);

    if (defined($self->{'finalaccessstatus'})) {
        return $self->{'finalaccessstatus'};
    }

    my $rights_attribute = $self->get_rights_attribute($C, $id);
    my $access_type = _determine_access_type($C, $id);

    my $initial_access_status =
        _determine_initial_access_status($rights_attribute, $access_type);

    my ($final_access_status, $granted, $owner, $expires) =
        _Assert_final_access_status($C, $initial_access_status, $id);

    $self->{'finalaccessstatus'} = $final_access_status;
    $self->{'exclusivity'}{'granted'} = $granted;
    $self->{'exclusivity'}{'owner'} = $owner;
    $self->{'exclusivity'}{'expires'} = $expires;

    return $final_access_status;
}

# ---------------------------------------------------------------------

=item get_exclusivity

Description

=cut

# ---------------------------------------------------------------------
sub get_exclusivity {
    my $self = shift;
    my $C = shift;

    return (
            $self->{'exclusivity'}{'granted'},
            $self->{'exclusivity'}{'owner'},
            $self->{'exclusivity'}{'expires'}
           );
}

# ---------------------------------------------------------------------

=item PUBLIC: check_final_access_status

Description

=cut

# ---------------------------------------------------------------------
sub check_final_access_status {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);

    if (defined($self->{'finalaccessstatus'})) {
        return $self->{'finalaccessstatus'};
    }

    my $rights_attribute = $self->get_rights_attribute($C, $id);
    my $access_type = _determine_access_type($C, $id);

    my $initial_access_status =
        _determine_initial_access_status($rights_attribute, $access_type);

    my $final_access_status =
        _Check_final_access_status($C, $initial_access_status, $id);

    $self->{'finalaccessstatus'} = $final_access_status;

    return $final_access_status;
}

# ---------------------------------------------------------------------

=item PUBLIC: check_final_access_status_by_attribute

Description

=cut

# ---------------------------------------------------------------------
sub check_final_access_status_by_attribute {
    my $self = shift;
    my ($C, $rights_attribute, $id) = @_;

    $self->_validate_id($id);

    my $access_type = _determine_access_type($C);
    my $initial_access_status =
        _determine_initial_access_status($rights_attribute, $access_type);
    my $final_access_status =
        _Check_final_access_status($C, $initial_access_status, $id);

    return $final_access_status;
}
# ---------------------------------------------------------------------

=item PUBLIC: get_full_PDF_access_status

Under certain conditions the full book PDF download function is
authorized.

As of  Wed Jun  9 16:11:22 2010:

0) DLPS-pd + IA volumes authorized for unaffiliated users

1) Google-pd are authorized for authenticated HathiTrust
affiliates. This includes UM but excludes UM friend accounts.

Notes: UM Press (source=3) and OPB (attr=3) volumes are never
authorized. SSD users of in-copyright works are never
authorized. These follow from the above.

=cut

# ---------------------------------------------------------------------
sub get_full_PDF_access_status {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);

    my $status = 'deny';
    my $pdpdus = $self->public_domain_world($C, $id);

    # Unaffiliated users can get non-Google pd/pdus and IA volumes
    if ($pdpdus) {
        my $source = $self->get_source_attribute($C, $id);

        # Open source?
        if (grep(/^$source$/, @RightsGlobals::g_full_PDF_download_open_source_values)) {
            $status = 'allow';
        }
        else {
            #  More restrictive cases require affiliation
            if ($C->get_object('Auth')->affiliation_is_hathitrust($C)) {
                if (grep(/^$source$/, @RightsGlobals::g_full_PDF_download_closed_source_values)) {
                    $status = 'allow';
                }
            }
        }
    }

    return $status;
}

# ---------------------------------------------------------------------

=item PUBLIC: public_domain_world

Description: is this id PD/PDUS/World?

=cut

# ---------------------------------------------------------------------
sub public_domain_world {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);
    my $attribute = $self->get_rights_attribute($C, $id);

    if (grep(/^$attribute$/, @RightsGlobals::g_public_domain_world_attribute_values)) {
        if ($attribute == $RightsGlobals::g_public_domain_US_attribute_value) {
            return (_resolve_access_by_GeoIP() eq 'allow');
        }
        else {
            return 1;
        }
    }
    else {
        return 0;
    }
}

# ----------------------------------------------------------------------
#
#                        Private Instance Methods
#
# ----------------------------------------------------------------------


# ---------------------------------------------------------------------

=item PRIVATE: _validate_id

Description: is id parameter valid for this object instance?

=cut

# ---------------------------------------------------------------------
sub _validate_id {
    my $self = shift;
    my $id = shift;
    ASSERT((defined($id) && ($id eq $self->{'id'})),
           qq{Id="$id: not valid for this instance of Access::Rights object});
}

# ----------------------------------------------------------------------
#
#                        Private Class Methods
#
# ----------------------------------------------------------------------


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _get_final_access_status_attr_list

For this user, which rights attributes equate to 'allow' or 'deny'

=cut

# ---------------------------------------------------------------------
sub _get_final_access_status_attr_list {
    my $C = shift;
    my $final_access_status_req = shift;

    my @attr_list;
    my $access_type = _determine_access_type($C);

    foreach my $attr (keys %RightsGlobals::g_rights_matrix) {
        my $initial_access_status =
            _determine_initial_access_status($attr, $access_type);
        my $final_access_status =
            _Check_final_access_status($C, $initial_access_status);

        push(@attr_list, $attr)
            if ($final_access_status eq $final_access_status_req);
    }

    DEBUG('pt,auth,all',
          sub {
              my $attr_list = join(',', @attr_list);
              qq{<h5>_get_final_access_status_attr_list: reqd="$final_access_status_req" list=$attr_list</h5>}
          });

    return \@attr_list;
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _determine_initial_access_status

Description

=cut

# ---------------------------------------------------------------------
sub _determine_initial_access_status {
    my ($rights_attribute, $access_type) = @_;

    return 'unknown'
        if ($rights_attribute == RightsGlobals::NOOP_ATTRIBUTE);

    if (! grep(/$rights_attribute/, @RightsGlobals::g_rights_attribute_values) ||
       (! grep(/$access_type/, @RightsGlobals::g_access_types))) {
        return 'deny';
    }
    my $initial_access_status =
        $RightsGlobals::g_rights_matrix{$rights_attribute}{$access_type};

    DEBUG('pt,auth,all', qq{<h4>InitialAccessStatus="$initial_access_status"</h4>});

    return $initial_access_status;
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: ___final_access_status_check

Description

=cut

# ---------------------------------------------------------------------
sub ___final_access_status_check {
    my $final_access_status = shift;

    ASSERT(($final_access_status eq 'allow')
           ||
           ($final_access_status eq 'deny')
           ||
           ($final_access_status eq 'unknown'),
           qq{Invalid final access status value="$final_access_status"});

    DEBUG('pt,auth,all', qq{<h4>FinalAccessStatus="$final_access_status" REMOTE_USER="$ENV{'REMOTE_USER'}"</h4>});
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _Assert_final_access_status

Description

=cut

# ---------------------------------------------------------------------
sub _Assert_final_access_status {
    my ($C, $initial_access_status, $id) = @_;

    my ($final_access_status, $granted, $owner, $expires) =
        ($initial_access_status, undef, undef, undef);

    if ($initial_access_status eq 'allow_by_geo_ipaddr') {
        $final_access_status = _resolve_access_by_GeoIP();
    }
    elsif ($initial_access_status eq 'allow_by_exclusivity') {
        ($final_access_status, $granted, $owner, $expires) =
            _assert_access_exclusivity($C, $id);
    }
    elsif ($initial_access_status eq 'allow_by_lib_ipaddr') {
        $final_access_status = 'allow';
    }

    ___final_access_status_check($final_access_status);

    return ($final_access_status, $granted, $owner, $expires);
}

# ---------------------------------------------------------------------

=item  CLASS PRIVATE: _Check_final_access_status

In cases where the id is not available (such as determining which
attributes equate to 'allow' for a query for full text items) punt if
the initial_access_status is 'allow_by_exclusivity' and set
final_access_status to 'deny'.

As of Tue Apr 27 12:27:40 2010 we decided to have the UI express the
denial of access that depends on being able to gain exclusive access
when another user *with the identical affiliation* already has
exclusive access.  Links will always say 'deny' for OPB even when
"in_a_library".  This is configurable below in case we want to make
the CB and LS labels dynamic.  Note however, that when it comes to
actually accessing the book, UM OPB access is allowed.

=cut

# ---------------------------------------------------------------------
my $DYNAMIC_LABELS = 0;

sub _Check_final_access_status {
    my ($C, $initial_access_status, $id) = @_;

    my $final_access_status = $initial_access_status;

    if ($initial_access_status eq 'allow_by_geo_ipaddr') {
        $final_access_status = _resolve_access_by_GeoIP();
    }
    elsif ($initial_access_status eq 'allow_by_lib_ipaddr') {
        if ($DYNAMIC_LABELS) {
            $final_access_status = 'allow';
        }
        else {
            $final_access_status = 'deny';
        }
    }
    elsif ($initial_access_status eq 'allow_by_exclusivity') {
        if ($DYNAMIC_LABELS) {
            $final_access_status = _check_access_exclusivity($C, $id);
        }
        else {
            $final_access_status = 'deny';
        }
    }

    ___final_access_status_check($final_access_status);

    return $final_access_status;

}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _determine_rights_attribute

Description

=cut

# ---------------------------------------------------------------------
sub _determine_rights_attribute {
    my ($C, $id) = @_;

    my ($attr, $rc) = (undef, RightsGlobals::OK_ID);
    my $cgi = $C->get_object('CGI');

    # ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
    if (defined($cgi->param('attr')) && Debug::DUtils::debugging_enabled()) {
        $attr = $cgi->param('attr');
        ASSERT(grep(/^$attr$/, @RightsGlobals::g_rights_attribute_values ),
                qq{Invalid attribute value for 'attr' parameter: } . $attr);
    }
    else {
        ($attr, $rc) = _get_rights_attribute($C, $id);
    }

    DEBUG('db,auth,all',
          qq{<h4>id="$id", attr="$attr" desc="$RightsGlobals::g_attribute_names{$attr}"</h4>});

    return ($attr, $rc);
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _determine_source_attribute

Description

=cut

# ---------------------------------------------------------------------
sub _determine_source_attribute {
    my ($C, $id) = @_;

    my ($source, $rc) = (undef, RightsGlobals::OK_ID);
    my $cgi = $C->get_object('CGI');

    # ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
    # Allow use of 'src' only for superuser as it opens the door to
    # full book download of certain volumes. Too dangerous to be
    # widely enabled.
    if (defined($cgi->param('src')) && Debug::DUtils::debugging_enabled('superuser')) {
        $source = $cgi->param('src');
        ASSERT(grep(/^$source$/, @RightsGlobals::g_source_values ),
               qq{Invalid source value for 'src' parameter: } . $source);
    }
    else {
        ($source, $rc) = _get_source_attribute($C, $id);
    }

    DEBUG('db,auth,all',
          qq{<h4>id="$id", source="$source" desc="$RightsGlobals::g_source_names{$source}"</h4>});

    return ($source, $rc);
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _get_rights_attribute

Description

=cut

# ---------------------------------------------------------------------
sub _get_rights_attribute {
    my ($C, $id) = @_;

    my $db = $C->get_object('Database');
    my $dbh = $db->get_DBH($C);

    my $stripped_id = Identifier::get_id_wo_namespace($id);
    my $namespace = Identifier::the_namespace($id);

    my $row_hashref;
    my $statement =
        qq{SELECT id, attr FROM rights_current WHERE id='$stripped_id' AND namespace='$namespace'};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    $row_hashref = $sth->fetchrow_hashref();
    $sth->finish;

    my $attr = $$row_hashref{'attr'};
    my $db_id = $$row_hashref{'id'};

    my $rc = RightsGlobals::OK_ID;

    $rc |= RightsGlobals::BAD_ID         if (! $db_id);
    $rc |= RightsGlobals::NO_ATTRIBUTE   if (! $attr);

    return ($attr, $rc);
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _get_source_attribute

Description

=cut

# ---------------------------------------------------------------------
sub _get_source_attribute {
    my ($C, $id) = @_;

    my $db = $C->get_object('Database');
    my $dbh = $db->get_DBH($C);

    # NAMESPACE: Rights database lacks namespaces.
    my $stripped_id = Identifier::get_id_wo_namespace($id);
    my $namespace = Identifier::the_namespace($id);

    my $row_hashref;
    my $statement = qq{SELECT id, source FROM rights_current WHERE id='$stripped_id' AND namespace='$namespace'};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);

    $row_hashref = $sth->fetchrow_hashref();
    $sth->finish;

    my $source = $$row_hashref{'source'};
    my $db_id = $$row_hashref{'id'};

    my $rc = RightsGlobals::OK_ID;

    $rc |= RightsGlobals::BAD_ID     if (! $db_id);
    $rc |= RightsGlobals::NO_SOURCE  if (! $source);

    return ($source, $rc);
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _determine_access_type

Determine for each what sort of access class a user falls into in
order to determine authorization for each value of the rights
attribute in mdp.rights table.

=cut

# ---------------------------------------------------------------------
sub _determine_access_type {
    my ($C, $id) = @_;

    my $access_type = $RightsGlobals::ORDINARY_USER;

    # Is this a ssd user?
    my $ssd = $C->get_object('CGI')->param('ssd');
    if (
        defined($id)
        &&
        $ssd
        &&
        (_user_ssd_status($C, $id) eq 'allowed')
       ) {
        $access_type = $RightsGlobals::SSD_USER
    }
    else {
        my $auth = $C->get_object('Auth');

        # Being in a (UM) library gives rights to see in-copyright
        # brittle book images. If not, see if user is a HathiTrust affiliate
        # that can gain exclusive access
        if ($auth->is_in_library()) {
            # Allows brittle book access to unlimited number of users
            $access_type = $RightsGlobals::LIBRARY_IPADDR_USER;
        }
        elsif ($auth->affiliation_is_umich($C)) {
            # on or off-campus full PDF + outside of library exclusive
            # brittle access + some DLPS ic works
            $access_type = $RightsGlobals::UM_AFFILIATE;
        }
        elsif ($auth->affiliation_is_hathitrust($C)) {
            # full PDF + exclusive brittle access
            $access_type = $RightsGlobals::HT_AFFILIATE;
        }
    }
    DEBUG('pt,auth,all',
          sub {
              my $a = $RightsGlobals::g_access_type_names{$access_type};
              my $s = qq{<h4>AccessType="$a" SDRINST="$ENV{'SDRINST'}", SDRLIB="$ENV{'SDRLIB'}", id="$id"</h4>};
              return $s;
          });

    return $access_type;
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _resolve_access_by_GeoIP

Description

=cut

# ---------------------------------------------------------------------
sub _resolve_access_by_GeoIP {
    require "Geo/IP.pm";

    my $status;

    # Allow caller to specify IP address, optionally
    my $IPADDR = shift || $ENV{'REMOTE_ADDR'};

    my $geoIP = Geo::IP->new();
    my $country_code = $geoIP->country_code_by_addr($IPADDR);
    if (grep(/$country_code/, @RightsGlobals::g_pdus_country_codes)) {
        $status = 'allow';
    }
    else {
        $status = 'deny';
    }
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _check_access_exclusivity

Description

=cut

# ---------------------------------------------------------------------
sub _check_access_exclusivity {
    my ($C, $id) = @_;

    my $status = 'deny';

    if (defined($id)) {
        my $identity = $C->get_object('Auth')->get_user_name($C);
        my ($granted, $owner, $expires) =
            Auth::Exclusive::check_exclusive_access($C, $id, $identity);
        if ($granted) {
            $status = 'allow';
        }
        else {
            $status = 'deny';
        }
    }

    return $status;
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _assert_access_exclusivity

Description

=cut

# ---------------------------------------------------------------------
sub _assert_access_exclusivity {
    my ($C, $id) = @_;

    my $status;

    my $auth = $C->get_object('Auth');
    my $identity = $auth->get_user_name($C);
    my $affiliation = $auth->get_eduPersonScopedAffiliation($C);

    my ($granted, $owner, $expires) =
        Auth::Exclusive::acquire_exclusive_access($C, $id, $identity, $affiliation);
    if ($granted) {
        $status = 'allow';
    }
    else {
        $status = 'deny';
    }

    return ($status, $granted, $owner, $expires);
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _user_ssd_status_wo_session

Helper for _user_ssd_status.  The "gr" CGI needs access status but does
not maintain a session nor pass an ssd parameter to compute SSD status
so to cut down on overhead the SSD status will be
denied-notcheckedout.

=cut

# ---------------------------------------------------------------------
sub _user_ssd_status_wo_session {
    my ($C, $id) = @_;

    my $ssd = 'denied-nonsession';
    DEBUG('pt,auth,all', qq{<h4>SSD status="$ssd"</h4>});
    return $ssd;
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _user_ssd_status_w_session

Helper for _user_ssd_status. A user must be logged to have ssd status
regardless of the state of the ssd flag on the session

=cut

# ---------------------------------------------------------------------
my %cached_ssd_status;

sub _user_ssd_status_w_session {
    my ($C, $id) = @_;

    # Prevent needless database accesses
    return $cached_ssd_status{$id}
        if ($cached_ssd_status{$id});

    my $ses = $C->get_object('Session');
    my $auth = $C->get_object('Auth');

    my $logged_in = $auth->is_logged_in();
    my $ssd_requested = $C->get_object('CGI')->param('ssd');

    my $ssd = $ses->get_persistent_subkey('ssd', $id);
    DEBUG('pt,auth,all', qq{<h4>SSD status [ON ENTRY]="$ssd"</h4>});

    if (! $ssd) {
        $ses->set_persistent_subkey('ssd', $id, 'initial');
        $cached_ssd_status{$id} = $ssd;
    }

    if (! $ssd_requested) {
        my $ssd = 'denied-notrequested';
        $ses->set_persistent_subkey('ssd', $id, $ssd);
        $cached_ssd_status{$id} = $ssd;
        DEBUG('pt,auth,all', qq{<h4>SSD status="$ssd"</h4>});

        return $ssd;
        # NOTREACHED
    }

    if (! $logged_in) {
        # Cannot be ssd for any ID if not logged in
        my $ssd = 'denied-notloggedin';
        $ses->set_persistent_subkey('ssd', $id, $ssd);
        $cached_ssd_status{$id} = $ssd;
        DEBUG('pt,auth,all', qq{<h4>SSD status="$ssd"</h4>});

        return $ssd;
        # NOTREACHED
    }

    # The user is now logged in and now requests SSD status. Check
    # again if status is not 'allowed'
    my $check_status = 0;
    $ssd = $ses->get_persistent_subkey('ssd', $id);
    if ($ssd ne 'allowed') {
        $check_status = 1;
    }

    if ($check_status) {
        # Test user for ssd privilege for this ID
        my $uniqname = $auth->get_user_name();
        if (_authenticate_ssd_user($C, $uniqname, $id)) {
            $ssd = 'allowed';
            $cached_ssd_status{$id} = $ssd;
            $ses->set_persistent_subkey('ssd', $id, $ssd);
        }
        else {
            $ssd = 'denied-notcheckedout';
            $cached_ssd_status{$id} = $ssd;
            $ses->set_persistent_subkey('ssd', $id, $ssd);
        }
    }

    DEBUG('pt,auth,all', qq{<h4>SSD status="$ssd"</h4>});

    return $ssd;
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _user_ssd_status

A user must be logged to have ssd status regardless of the state
of the ssd flag on the session

=cut

# ---------------------------------------------------------------------
sub _user_ssd_status {
    my ($C, $id) = @_;

    my $ssd;

    if ($C->has_object('Session')) {
        $ssd = _user_ssd_status_w_session($C, $id);
    }
    else {
        $ssd = _user_ssd_status_wo_session($C, $id);
    }

    return $ssd;
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE:_authenticate_ssd_user

Description

=cut

# ---------------------------------------------------------------------
sub _authenticate_ssd_user {
    my ($C, $uniqname, $id) = @_;

    return 0 if (! $uniqname);

    my $authenticated = 0;

    my $url = $MirlynGlobals::g_ssd_access_url;
    $url =~ s,__UNIQNAME__,$uniqname,g;

    my $response = Utils::get_user_agent()->get($url);
    my $response_ok = $response->is_success;
    my $response_status = $response->status_line;

    if ($response_ok) {
        my $patron_data = $response->content;

        DEBUG('ptdata',
              sub {
                  my $d = $patron_data; Utils::map_chars_to_cers(\$d, [q{"}, q{'}]);
                  return qq{<h4>Patron data:<br/></h4> $d};
              });

        if ($patron_data) {
            $patron_data = Encode::decode_utf8($patron_data);

            # parse for ssd user flag and "barcode" in question
            if (($patron_data =~ m,<z305-field-3>SSD</z305-field-3>,)
                &&
                ($patron_data =~ m,<z30-call-no-2>$id</z30-call-no-2>,)) {
                $authenticated = 1;
            }
        }
    }
    DEBUG('pt,auth,all',
          sub {
              my $u = $url; Utils::map_chars_to_cers(\$u);
              return qq{<h4>SSD authentication result="$authenticated"<br/>URL="$u"<br/>XServer response="$response_status"</h4>};
          });

    return $authenticated;
}

1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-10 ©, The Regents of The University of Michigan, All Rights Reserved

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
