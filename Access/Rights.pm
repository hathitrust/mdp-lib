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
a CGI and an Database object.

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
use Auth::ACL;
use Auth::Exclusive;
use RightsGlobals;
use MirlynGlobals;

use Access::Holdings;
use Access::Orphans;

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

See RightsGlobals.pm for documentation on Attributes, Sources, etc.

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

SOURCES See RightsGlobals.pm

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

For this user (assuming user is authenticated) for user's institution,
which rights attributes equate to 'fulltext'

WARNING: The list returned by this subroutine is valid ONLY when
called to construct a filter query that INCLUDES A TEST FOR HOLDINGS.
It is permissive of the attributes that equate to 'allow' in the
CERTAIN KNOWLEDGE that these rights attribute values will be QUALIFIED
BY THIS HOLDINGS TEST.

=cut

# ---------------------------------------------------------------------
sub get_fulltext_attr_list {
    my $C = shift;
    return _get_final_access_status_attr_list($C, 'allow');
}

# ---------------------------------------------------------------------

=item CLASS PUBLIC: get_no_fulltext_attr_list

For this user (assuming user is authenticated) for user's institution,
which rights attributes equate to 'search-only', i.e. no 'fulltext'.

This includes attr=8 (nobody).  Even though we don't index those
volumes we still need to assert that 8 is denied here.  

=cut

# ---------------------------------------------------------------------
sub get_no_fulltext_attr_list {
    my $C = shift;
    return _get_final_access_status_attr_list($C, 'deny');
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
    my $access_type = _determine_access_type($C);

    my $initial_access_status =
        _determine_initial_access_status($rights_attribute, $access_type);

    my ($final_access_status, $granted, $owner, $expires) =
        _Assert_final_access_status($C, $initial_access_status, $id);

    $self->{'finalaccessstatus'} = $final_access_status;
    $self->{'access_type'} = $access_type;
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

=item get_access_type

Description

=cut

# ---------------------------------------------------------------------
sub get_access_type {
    my $self = shift;
    my ($C, $as_string) = @_;
    
    my $access_type = $self->{'access_type'};
    my $at = 
      $as_string 
        ? $RightsGlobals::g_access_type_names{$access_type} 
          : $access_type;
 
    return $at;
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
    my $access_type = _determine_access_type($C);

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

As of Mon Mar 21 17:01:55 2011

Allowed are: 

1) non-google pd/pdus(on US soil)/world/cc for anyone

2) google pd/pdus(anywhere)/world only authenticated HathiTrust
affiliates. Affiliates of non-US institutions must be at a US IP
address. Excludes UM friend accounts.

3) LOC users "in-a-library" are now Thu Mar 8 16:04:11 2012
considered equivalent to authenticated HathiTrust affiliates.

Exceptions: UM Press (ump)(source=3)

=cut

# ---------------------------------------------------------------------
sub get_full_PDF_access_status {
    my $self = shift;
    my ($C, $id) = @_;
    
    $self->_validate_id($id);

    my $status = 'deny';
    my $message = q{NOT_AVAILABLE};
    
    my $creative_commons = $self->creative_commons($C, $id);

    if ($creative_commons) {
        $status = 'allow';
    }
    else {
        my $source = $self->get_source_attribute($C, $id);

        # Affiliates of US institutions can download pd/pdus from
        # anywhere on Earth. Unaffiliated users and non-US affiliates
        # only from US IP addresses.  This "pd" determination is
        # fully-wrapped by call to public_domain_world() next.

        my $pd = $self->public_domain_world($C, $id);

        if (grep(/^$source$/, @RightsGlobals::g_full_PDF_download_closed_source_values)) {
            #  Restricted pd sources (google) require affiliation.
            if ($pd) {
                my $auth = $C->get_object('Auth');
                my $is_affiliated = (
                                     $auth->affiliation_is_hathitrust($C) 
                                     ||
                                     $auth->is_in_library()
                                    );
                if ( $is_affiliated ) {
                    $status = 'allow';
                }
                else {
                    $message = q{NOT_AFFILIATED};                    
                }
            }
        }
        elsif (grep(/^$source$/, @RightsGlobals::g_full_PDF_download_open_source_values)) {
            if ($pd) {
                $status = 'allow';
            }
        }
        else {
            if ($pd) {
                # There's some sort of source restriction on whole book
                # download like that which applies to UM Press
                $message = q{RESTRICTED_SOURCE};
            }
        }
    }

    # 'allow' at this point may be because of attr=1 from upstream for
    # debugging or CRMS/quality/orphan research activity.  As of Feb
    # 13 2012 only superusers (developers) within a restricted IP
    # range are allowed full book download of in-copyright books.
    if ($status eq 'allow') {
        my ($in_copyright, $attr) = Access::Rights::in_copyright_suppress_debug_switches($C, $id);
        if ($in_copyright) {
            my $role = Auth::ACL::a_GetUserAttributes('role');
            if ($role ne 'superuser') {
                $status = 'deny';
                $message = q{NOT_AVAILABLE};
            }
        }
    }

    # clear the error message if $status eq 'allow'
    $message = '' if ( $status eq 'allow' );

    DEBUG('pt,auth', qq{<h5>get_full_PDF_access_status: status=$status message=$message</h5>});
    return ($message, $status);
}

# ---------------------------------------------------------------------

=item public_domain_world_creative_commons

Can you think of a better name?

=cut

# ---------------------------------------------------------------------
sub public_domain_world_creative_commons {
    my $self = shift;
    my ($C, $id) = @_;

    return (
            $self->creative_commons($C, $id)
            ||
            $self->public_domain_world($C, $id)
           );
}

# ---------------------------------------------------------------------

=item PUBLIC: public_domain_world

Description: is this id pd/pdus/world? In the pdus case, unaffiliated
users of non-US institutions must be at a US IP address for this id to
be in the public domain.

=cut

# ---------------------------------------------------------------------
sub public_domain_world {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);
    my $attribute = $self->get_rights_attribute($C, $id);

    if (grep(/^$attribute$/, @RightsGlobals::g_public_domain_world_attribute_values)) {
        if ($attribute == $RightsGlobals::g_public_domain_US_attribute_value) {
            my $us_status = $C->get_object('Auth')->get_institution_us_status($C);
            if ($us_status eq 'affus') {
                return 1;
            }
            else {
                return (_resolve_access_by_GeoIP($C) eq 'allow');
            }
        }
        else {
            return 1;
        }
    }
    else {
        return 0;
    }
}

# ---------------------------------------------------------------------

=item in_copyright

Description

=cut

# ---------------------------------------------------------------------
sub in_copyright {
    my $self = shift;
    my ($C, $id) = @_;
    
    if ($self->public_domain_world_creative_commons($C, $id)) {
        return 0;
    }
    return 1;
}

# ---------------------------------------------------------------------

=item CLASS PUBLIC: in_copyright_suppress_debug_switches

Get the true ic value independent of debugging switches.  Required for
IC security logging.

Returns the true rights_current.attr

=cut

# ---------------------------------------------------------------------
sub in_copyright_suppress_debug_switches {
    my ($C, $id) = @_;
    
    my ($attribute, $rc) = _determine_rights_attribute($C, $id, 1);
    $attribute = RightsGlobals::NOOP_ATTRIBUTE if ($rc != RightsGlobals::OK_ID);

    # pessimistic
    my $in_copyright = 1;
    
    if ($attribute == $RightsGlobals::g_public_domain_US_attribute_value) {
        # pdus is pd for authenticated US affiliates coming from non-US IP addresses
        my $us_status = $C->get_object('Auth')->get_institution_us_status($C);
        if ($us_status eq 'affus') {
            $in_copyright = 0;
        }
        else {
            $in_copyright = (_resolve_access_by_GeoIP($C) eq 'deny');
        }
    }
    else {
        my @freely_available = 
          (
           @RightsGlobals::g_creative_commons_attribute_values, 
           @RightsGlobals::g_public_domain_world_attribute_values
          );
    
        $in_copyright = (! grep(/^$attribute$/, @freely_available));        
    }

    return ($in_copyright, $attribute);
}


# ---------------------------------------------------------------------

=item PUBLIC: orphan_candidate

Description: is this id an orphand candidate?

=cut

# ---------------------------------------------------------------------
sub orphan_candidate {
    my $self = shift;
    my ($C, $id) = @_;

    my $attribute = $self->get_rights_attribute($C, $id);
    if ($attribute == $RightsGlobals::g_orphan_candidate_attribute_value) {
        return 1;
    }
    else {
        return 0;
    }
}

# ---------------------------------------------------------------------

=item PUBLIC: creative_commons

Description: is this id one of the Creative Commons
rights_current.attr valuse?

=cut

# ---------------------------------------------------------------------
sub creative_commons {
    my $self = shift;
    my ($C, $id) = @_;

    $self->_validate_id($id);
    my $attribute = $self->get_rights_attribute($C, $id);

    if (grep(/^$attribute$/, @RightsGlobals::g_creative_commons_attribute_values)) {
        return 1;
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

For this user, which rights attributes equate to 'allow' or 'deny' and
see notes on _Check_final_access_status()

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

    DEBUG('pt,auth,all', qq{<h4>attr="$rights_attribute" InitialAccessStatus="$initial_access_status"</h4>});

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

    DEBUG('pt,auth,all', qq{<h4>FinalAccessStatus="<span style="color:blue;">$final_access_status</span>" REMOTE_USER="$ENV{'REMOTE_USER'}"</h4>});
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _Assert_final_access_status

Description

=cut

# ---------------------------------------------------------------------
sub _Assert_final_access_status {
    my ($C, $initial_access_status, $id) = @_;

    my ($final_access_status, $granted, $owner, $expires) =
        ($initial_access_status, 0, undef, '0000-00-00 00:00:00');

    if 
      ($initial_access_status eq 'allow_by_geo_ipaddr') {
        $final_access_status = _resolve_access_by_GeoIP($C);
    }
    elsif 
      ($initial_access_status eq 'allow_non_us_aff_by_ip_addr') {
        $final_access_status = _resolve_non_us_aff_access_by_GeoIP($C);
    }
    elsif 
      ($initial_access_status eq 'allow_by_exclusivity') {
        ($final_access_status, $granted, $owner, $expires) =
          _assert_access_exclusivity($C, $id);
    }
    elsif 
      ($initial_access_status eq 'allow_by_uom_lib_ipaddr') {
        if ($C->get_object('Auth')->is_in_uom_library()) {
            ($final_access_status, $granted, $owner, $expires) =
              _assert_access_exclusivity($C, $id);
        }
        else {
            $final_access_status = 'deny';
        }
    }
    elsif
      ($initial_access_status eq 'allow_orph_by_holdings_by_agreement') {
        ($final_access_status, $granted, $owner, $expires) = 
          _resolve_access_by_held_and_agreement($C, $id, 1);
    }
    elsif 
      ($initial_access_status eq 'allow_ssd_by_holdings') {
        $final_access_status = _resolve_ssd_access_by_held($C, $id, 1);
    }

    ___final_access_status_check($final_access_status);

    return ($final_access_status, $granted, $owner, $expires);
}

# ---------------------------------------------------------------------

=item  CLASS PRIVATE: _Check_final_access_status

The id is required to determine holdings. If the id is not available
(such as determining which attributes equate to 'allow' for a Facet
for just fulltext items), set access to 'allow'. Downstream code will
have to filter records based on its holdings data over all items to
determine which should appear in search results. There are two cases
where holdings come into play in the absence of an id.

(1) If the initial_access_status is 'allow_by_exclusivity' we set
final_access_status to 'allow'. It is highly improbable that an item
to which exclusive access applies will be acquired by a user other
that the user viewing results filtered by the 'fulltext' Facet.  The
anomaly here is a 'search-only' link to pageturner in the search
results for 'fulltext' only.

(2) If the initial_access_status is 'allow_orph_by_holdings_by_agreement' we set 
final_access_status to 'allow'.

=cut

# ---------------------------------------------------------------------
sub _Check_final_access_status {
    my ($C, $initial_access_status, $id) = @_;

    my $final_access_status = $initial_access_status;

    if 
      ($initial_access_status eq 'allow_by_geo_ipaddr') {
        $final_access_status = _resolve_access_by_GeoIP($C);
    }
    elsif 
      ($initial_access_status eq 'allow_non_us_aff_by_ip_addr') {
        $final_access_status = _resolve_non_us_aff_access_by_GeoIP($C);
    }
    elsif 
      ($initial_access_status eq 'allow_by_uom_lib_ipaddr') {
        if (defined($id)) {
            if ($C->get_object('Auth')->is_in_uom_library()) {
                ($final_access_status, $granted, $owner, $expires) = 
                  _check_access_exclusivity($C, $id);
            }
            else {
                $final_access_status = 'deny';
            }
        }
        else {
            $final_access_status = 'allow';
        }
    }
    elsif 
      ($initial_access_status eq 'allow_by_exclusivity') {
        if (defined($id)) {
            ($final_access_status, $granted, $owner, $expires) = 
              _check_access_exclusivity($C, $id);
        }
        else {
            $final_access_status = 'allow';
        }
    }
    elsif 
      ($initial_access_status eq 'allow_orph_by_holdings_by_agreement') {
        if (defined($id)) {
            ($final_access_status, $granted, $owner, $expires) = 
              _resolve_access_by_held_and_agreement($C, $id, 0);
        }
        else {
            # downstream must filter on holdings if $final_access_status = 'allow'
            $final_access_status = _institution_has_orphan_agreement($C) ? 'allow' : 'deny'; 
        }
    }
    elsif 
      ($initial_access_status eq 'allow_ssd_by_holdings') {
        if (defined($id)) {
            $final_access_status = _resolve_ssd_access_by_held($C, $id, 0);
        }
        else {
            # downstream must filter on holdings
            $final_access_status = 'allow';
        }
    }
    
    ___final_access_status_check($final_access_status);

    return $final_access_status;

}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _determine_rights_attribute

This will need to be enhanced to test for the triple
[institution,id,condition] in the Holdings Database and if
condition="brittle", return 3 else return value in
mdp.rights_current.attr

If institution is not known return mdp.rights_current.attr 

=cut

# ---------------------------------------------------------------------
sub _determine_rights_attribute {
    my ($C, $id, $skip_debug_test) = @_;

    my ($attr, $rc) = (undef, RightsGlobals::OK_ID);

    # ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
    if (! $skip_debug_test) {
        my $cgi = $C->get_object('CGI');
        if (defined($cgi->param('attr')) && Debug::DUtils::debugging_enabled()) {
            $attr = $cgi->param('attr');
            ASSERT(grep(/^$attr$/, @RightsGlobals::g_rights_attribute_values ),
                   qq{Invalid attribute value for 'attr' parameter: } . $attr);
        }
        # for Facet debugging, if this is the special ID
        if ($id eq $Identifier::non_um_in_copyright_id) {
            if (DEBUG('orph')) {
                $attr = $RightsGlobals::g_orphan_attribute_value;
            }
            elsif (DEBUG('orphcand')) {
                $attr = $RightsGlobals::g_orphan_candidate_attribute_value;
            }
        }
    }

    if (! defined($attr)) {
        ($attr, $rc) = _get_rights_attribute($C, $id);
    }

    DEBUG('db,auth,all',
          qq{<h4>id="$id", attr=$attr (DEBUG SUPPRESSED="$skip_debug_test") desc=$RightsGlobals::g_attribute_names{$attr}</h4>});

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
        qq{SELECT id, attr FROM rights_current WHERE id=? AND namespace=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $stripped_id, $namespace);

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
    my $statement = qq{SELECT id, source FROM rights_current WHERE id=? AND namespace=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $stripped_id, $namespace);

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
attribute in mdp.rights_current table.

=cut

# ---------------------------------------------------------------------
sub _determine_access_type {
    my $C = shift;

    my $access_type = $RightsGlobals::ORDINARY_USER;

    # Tests are in order of which access type would give most
    # privileges.

    my $auth = $C->get_object('Auth');

    if 
      ($auth->get_eduPersonEntitlement_print_disabled($C)) {
        $access_type = $RightsGlobals::SSD_USER;
    }
    elsif 
      ($auth->affiliation_is_umich($C)) {
        # on or off-campus full PDF of pd + outside of library
        # exclusive brittle access + some DLPS ic works + orphans
        $access_type = $RightsGlobals::UM_AFFILIATE;
    }
    elsif 
      ($auth->affiliation_is_hathitrust($C)) {
        # full PDF + exclusive brittle access + orph modulo geo location
        $access_type = $RightsGlobals::HT_AFFILIATE;
    }
    elsif 
      ($auth->is_in_library()) {
        # brittle book access limited by number held and 24h
        # exclusivity: UM only until Holding Db carries condition
        # data.
        $access_type = $RightsGlobals::LIBRARY_IPADDR_USER;
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

=item CLASS PRIVATE: _resolve_non_us_aff_access_by_GeoIP

 if (affiliate of US institution)
    allow 
 else if (affiliate of non-US institution)
    allow if IP address is US
 else
    deny
 endif

=cut

# ---------------------------------------------------------------------
sub _resolve_non_us_aff_access_by_GeoIP {
    my $C = shift;

    my $status = 'deny';
    
    my $us_status = $C->get_object('Auth')->get_institution_us_status($C);
    if ($us_status eq 'affus') {
        $status = 'allow';
    } 
    elsif ($us_status eq 'affnotus') {
        # non-US affiliate: on us soil?
        $status = _resolve_access_by_GeoIP($C);
    }

    return $status;
}


# ---------------------------------------------------------------------

=item CLASS PRIVATE: _resolve_access_by_GeoIP

First check IP for U.S. origin then test for proxies.

=cut

# ---------------------------------------------------------------------
sub _resolve_access_by_GeoIP {
    my $C = shift;

    my $status = 'deny';

    # Use forwarded IP address if proxied, else UA IP addr
    my $IPADDR = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};

    require "Geo/IP.pm";
    my $geoIP = Geo::IP->new();
    my $country_code = $geoIP->country_code_by_addr($IPADDR);
    if (grep(/$country_code/, @RightsGlobals::g_pdus_country_codes)) {
        # veryify this is not a blacklisted US proxy that does not set
        # HTTP_X_FORWARDED_FOR for a non-US request
        require "Access/Proxy.pm";
        my $dbh = $C->get_object('Database')->get_DBH($C);

        if (Access::Proxy::blacklisted($dbh, $IPADDR, $ENV{SERVER_ADDR}, $ENV{SERVER_PORT})) {
            $status = 'deny';
        }
        else {
            $status = 'allow';
        }
    }
    else {
        $status = 'deny';
    }

    return $status;
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _check_access_exclusivity

Description

=cut

# ---------------------------------------------------------------------
sub _check_access_exclusivity {
    my ($C, $id) = @_;

    my ($status, $granted, $owner, $expires) = ('deny', 0, undef, '0000-00-00 00:00:00');

    if (defined($id)) {
        ($granted, $owner, $expires) =
          Auth::Exclusive::check_exclusive_access($C, $id);
        if ($granted) {
            $status = 'allow';
        }
        else {
            $status = 'deny';
        }
    }

    return ($status, $granted, $owner, $expires);
}

# ---------------------------------------------------------------------

=item _resolve_access_by_held_and_agreement

Orphan users must be "US soil" authed affiliates of a HT institution,
the user's institution must hold the work and agree to allow orphan
access and no more simultaneous users from that institution than
number of print copies held by that institution.

=cut

# ---------------------------------------------------------------------
sub _resolve_access_by_held_and_agreement {
    my ($C, $id, $assert_ownership) = @_;

    my ($status, $granted, $owner, $expires) = ('deny', 0, undef, '0000-00-00 00:00:00');

    my $inst = 'not defined';
    my $held = 0;
    my $agreed = 0;
    
    my $US_status = _resolve_access_by_GeoIP($C);
    if ($US_status eq 'allow') {
        $inst = $C->get_object('Auth')->get_institution($C);
        $agreed = Access::Orphans::institution_agreement($C, $inst);
        if ($agreed) {
            $held = Access::Holdings::id_is_held($C, $id, $inst);
            if ($held) {
                if ($assert_ownership) {
                    ($status, $granted, $owner, $expires) = _assert_access_exclusivity($C, $id);
                }
                else {
                    ($status, $granted, $owner, $expires) = _check_access_exclusivity($C, $id);
                }
            }
        }
    }
    DEBUG('pt,auth,all,agree,notagree,held,notheld', 
          qq{<h5>Held+agreement status=$status inst of requestor=$inst held=$held agreed=$agreed</h5>});

    return $status;
}

# ---------------------------------------------------------------------

=item _resolve_ssd_access_by_held

As of Tue Nov 29 13:17:04 2011, access is limited to one simultaneous
ssd user on US soil

=cut

# ---------------------------------------------------------------------
sub _resolve_ssd_access_by_held {
    my ($C, $id, $assert_ownership) = @_;

    my ($status, $granted, $owner, $expires) = ('deny', 0, undef, '0000-00-00 00:00:00');
    my $inst = 'not defined';
    my $held = 0;
    
    my $US_status = _resolve_access_by_GeoIP($C);
    if ($US_status eq 'allow') {
        $inst = $C->get_object('Auth')->get_institution($C);
        $held = Access::Holdings::id_is_held($C, $id, $inst);
        if ($held) {
            if ($assert_ownership) {
                ($status, $granted, $owner, $expires) = _assert_access_exclusivity($C, $id);
            }
            else {
                ($status, $granted, $owner, $expires) = _check_access_exclusivity($C, $id);
            }
        }
    }

    DEBUG('pt,auth,all,held,notheld', qq{<h5>SSD access=$status Holdings institution=$inst held=$held"</h5>});

    return $status;
}

# ---------------------------------------------------------------------

=item _institution_has_orphan_agreement

Description

=cut

# ---------------------------------------------------------------------
sub _institution_has_orphan_agreement {
    my $C = shift;

    my $inst = $C->get_object('Auth')->get_institution($C);
    return Access::Orphans::institution_agreement($C, $inst);
}

# ---------------------------------------------------------------------

=item CLASS PRIVATE: _assert_access_exclusivity

Description

=cut

# ---------------------------------------------------------------------
sub _assert_access_exclusivity {
    my ($C, $id) = @_;

    my $status;

    my ($granted, $owner, $expires) =
        Auth::Exclusive::acquire_exclusive_access($C, $id);
    if ($granted) {
        $status = 'allow';
    }
    else {
        $status = 'deny';
    }

    return ($status, $granted, $owner, $expires);
}

1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-11 ©, The Regents of The University of Michigan, All Rights Reserved

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
