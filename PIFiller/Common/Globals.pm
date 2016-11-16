=head1 NAME

Globals.pm

=head1 DESCRIPTION

This a PI handler package for the PIs that a re global, i.e. as in mbooks_globals.xml

=head1 SYNOPSIS

BEGIN
{
    require "PIFiller/Common/Globals.pm";
}

=head1 METHODS

=over 8

=cut
use Encode;

use Utils;
use Debug::DUtils;
use Utils::Js;
use Access::Statements;
use Access::Rights;
use Access::Holdings;
use Auth::Auth;
use Auth::ACL;

# ---------------------------------------------------------------------

=item handle_CGI_GLOBALS_PI : PI_handler(CGI_GLOBALS)

Handler for CGI_GLOBALS

=cut

# ---------------------------------------------------------------------
sub handle_CGI_GLOBALS_PI
    : PI_handler(CGI_GLOBALS)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $cgi = $C->get_object('CGI');

    my $output;
    foreach my $param_name ($cgi->param())
    {
        my @param_values = $cgi->multi_param($param_name);
        foreach my $val (@param_values)
        {
            $output .= wrap_string_in_tag($val, 'Param', [['name', $param_name]]);
        }
    }

    return $output;
}

# ---------------------------------------------------------------------

=item handle_SESSION_ID_PI :  PI_handler(SESSION_ID)

Handler for SESSION_ID

=cut

# ---------------------------------------------------------------------
sub handle_SESSION_ID_PI
    : PI_handler(SESSION_ID)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $ses = $C->get_object('Session');
    my $sid = $ses->get_session_id();

    return $sid;
}

# ---------------------------------------------------------------------

=item handle_HAS_OCR_PI :  PI_handler(HAS_OCR)

Some object lack OCR entirely -- not even empty OCR files

=cut

# ---------------------------------------------------------------------
sub handle_HAS_OCR_PI
    : PI_handler(HAS_OCR)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $mdp_item = $C->get_object('MdpItem');
    my $has_ocr = $mdp_item->Get('has_ocr') ? 'YES':'NO';

    return $has_ocr;

}

# ---------------------------------------------------------------------

=item handle_HT_ID_PI :  PI_handler(HT_ID)

The HathiTrust Id

=cut

# ---------------------------------------------------------------------
sub handle_HT_ID_PI
    : PI_handler(HT_ID)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $mdp_item = $C->get_object('MdpItem');
    my $id = $mdp_item->GetId();

    return $id;

}

# ---------------------------------------------------------------------

=item handle_ACCESS_USE_PI :  PI_handler(ACCESS_USE)

Container for the short description of Access and Use Policy,
e.g. "Public Domain" and the link to the full policy description.

=cut

# ---------------------------------------------------------------------
sub handle_ACCESS_USE_PI
    : PI_handler(ACCESS_USE)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $id = $C->get_object('CGI')->param('id');

    my $ar = $C->get_object('Access::Rights');

    my $attr = $ar->get_rights_attribute($C, $id);
    if ($attr == $RightsGlobals::g_suppressed_attribute_value) {
        return wrap_string_in_tag('This item is suppressed', 'Header');
    }

    my $access_profile = $ar->get_access_profile_attribute($C, $id);

    my $ref_to_arr_of_hashref =
      Access::Statements::get_stmt_by_rights_values($C, undef, $attr, $access_profile,
                                                  {
                                                   stmt_url      => 1,
                                                   stmt_url_aux  => 1,
                                                   stmt_head     => 1,
                                                   stmt_icon     => 1,
                                                   stmt_icon_aux => 1,
                                                  });
    my $hashref = $ref_to_arr_of_hashref->[0];
    my $url = $hashref->{stmt_url};
    my $aux_url = $hashref->{stmt_url_aux};
    my $head = $hashref->{stmt_head};
    my $icon = $hashref->{stmt_icon};
    my $aux_icon = $hashref->{stmt_icon_aux};

    my $s;
    $s .= wrap_string_in_tag($head, 'Header');
    $s .= wrap_string_in_tag($url, 'Link');
    $s .= wrap_string_in_tag($aux_url, 'AuxLink');
    $s .= wrap_string_in_tag($icon, 'Icon');
    $s .= wrap_string_in_tag($aux_icon, 'AuxIcon');

    return $s;
}

# ---------------------------------------------------------------------

=item handle_IN_LIBRARY_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_IN_LIBRARY_PI
    : PI_handler(IN_LIBRARY)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $auth = $C->get_object('Auth');

    my $inst = $auth->get_institution_code($C, 'mapped');
    my $is_in = $auth->is_in_library($C) ? 'YES' : 'NO';

    my $s;
    $s .= wrap_string_in_tag($is_in, 'Status');
    $s .= wrap_string_in_tag($inst, 'Institution');

    return $s;
}

# ---------------------------------------------------------------------

=item handle_INSTITUTION_NAME_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_INSTITUTION_NAME_PI
    : PI_handler(INSTITUTION_NAME)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $auth = $C->get_object('Auth');
    my $institution_name = $auth->get_institution_name($C, 'mapped');

    return $institution_name;
}

# ---------------------------------------------------------------------

=item handle_INSTITUTION_CODE_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_INSTITUTION_CODE_PI
    : PI_handler(INSTITUTION_CODE)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $auth = $C->get_object('Auth');
    my $institution_code = $auth->get_institution_code($C, 'mapped');

    return $institution_code;
}


# ---------------------------------------------------------------------

=item handle_ACCESS_HOLDINGS_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_ACCESS_HOLDINGS_PI
    : PI_handler(ACCESS_HOLDINGS)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $held = 'NO';
    my $brittle_held = 'NO';
    my $inst = 'notaninstitution';

    my $id = $C->get_object('CGI')->param('id');
    if ($id) {
        $inst = $C->get_object('Auth')->get_institution_code($C, 'mapped');
        if (Access::Holdings::id_is_held($C, $id, $inst)) {
            $held = 'YES';
        }
        if (Access::Holdings::id_is_held_and_BRLM($C, $id, $inst)) {
            $brittle_held = 'YES';
        }
    }

    my $s;
    $s .= wrap_string_in_tag($held, 'Held');
    $s .= wrap_string_in_tag($brittle_held, 'BrittleHeld');
    $s .= wrap_string_in_tag($inst, 'Institution');

    return $s;
}


# ---------------------------------------------------------------------

=item handle_LOGGED_IN_PI :  PI_handler(LOGGED_IN)

is user logged in?  emits YES/NO

=cut

# ---------------------------------------------------------------------
sub handle_LOGGED_IN_PI
    : PI_handler(LOGGED_IN)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $auth = $C->get_object('Auth');
    my $is_logged_in = $auth->is_logged_in($C) ? 'YES':'NO';
    if ( $is_logged_in eq 'NO' ) {
        my $ses = $C->get_object('Session');
        if ( $ses->get_transient('logged_out') == 1 ) {
            $is_logged_in = 'EXPIRED';
        }
    }

    return $is_logged_in;

}

# ---------------------------------------------------------------------

=item handle_LOGGED_IN_JS_PI :  PI_handler(LOGGED_IN_JS)

is user logged in?  emits javascript that returns true or false

=cut

# ---------------------------------------------------------------------
sub handle_LOGGED_IN_JS_PI
    : PI_handler(LOGGED_IN_JS)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $auth = $C->get_object('Auth');
    my $function_name = 'isLoggedIn';
    my $var_name = 'LoggedInVar';
    my $var_val = $auth->is_logged_in($C) ? 'true':'false';
    my $js = Utils::Js::build_javascript_var($function_name, $var_name,$var_val);

    return $js;
}


# ---------------------------------------------------------------------

=item handle_DEBUG_SWITCH_PI :  PI_handler(DEBUG_SWITCH)

If $DEBUG == ?? return YES For now will set to listinfo

=cut

# ---------------------------------------------------------------------
sub handle_DEBUG_SWITCH_PI
    : PI_handler(DEBUG_SWITCH)
{
    my ($C, $act, $piParamHashRef) = @_;
    my $config = $C->get_object('MdpConfig');
    my $debug_css = $config->get('debug_css');

    my $debug = 'NO';
    if (DEBUG('listinfo,xml,all'))
    {
        $debug = 'YES';
    }
    elsif( $debug_css =='1')
    {
        $debug = 'YES';
    }
    return $debug;
}

# ---------------------------------------------------------------------

=item handle_ENV_VAR_PI :  PI_handler(ENV_VAR)

=cut

# ---------------------------------------------------------------------
sub handle_ENV_VAR_PI
    : PI_handler(ENV_VAR)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $environment_variable = $$piParamHashRef{'variable'};
    my $v = $ENV{$environment_variable};
    $v = Encode::decode_utf8($v);

    # occassionally environment variable has chars in need of
    # mapping. e.g., AT&T
    Utils::map_chars_to_cers(\$v);
    # occassionally environment variable contains invalid XML cahrs
    my $removed = Utils::remove_invalid_xml_chars(\$v);

    return $v;
}

# ---------------------------------------------------------------------

=item handle_SUPPRESS_ACCESS_BANNER : PI_handler(SUPPRESS_ACCESS_BANNER)

Prevent access_banner_01.js from posting dialog for ACL access=total
users -- it gets in the way of routine work. Allow it to model
behavior correctly when certain debug= parameters are present.

=cut

# ---------------------------------------------------------------------
sub handle_SUPPRESS_ACCESS_BANNER
    : PI_handler(SUPPRESS_ACCESS_BANNER)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $suppress;

    if (Auth::ACL::S___total_access()) {
        $suppress = 'true'
    }
    else {
        $suppress = 'false'
    }

    # Correctly model certain debug behaviors
    if ($suppress eq 'true') {
        if (DEBUG('ord,ssd,hathi')) {
            $suppress = 'false';
        }
    }

    return $suppress;
}


# ---------------------------------------------------------------------

=item handle_DEBUG_UNCOMPRESSED :  PI_handler(DEBUG_UNCOMPRESSED)

Load the  individual uncompressed  CSS and JS files instead of the concatenated compressed ones

=cut

# ---------------------------------------------------------------------
sub handle_DEBUG_UNCOMPRESSED_PI
    : PI_handler(DEBUG_UNCOMPRESSED)
{
    my ($C, $act, $piParamHashRef) = @_;

    # Debug message buffer support
    my $config = $C->get_object('MdpConfig');
    my $debug_js = $config->get('debug_uncompressed_js');
    my $debug_css = $config->get('debug_uncompressed_css');

    my $s;
    $s .= wrap_string_in_tag($debug_js, 'JS');
    $s .= wrap_string_in_tag($debug_css, 'CSS');
    return $s;
}

# ---------------------------------------------------------------------

=item handle_SELECT_COLLECTION_WIDGET_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_SELECT_COLLECTION_WIDGET_PI
    : PI_handler(SELECT_COLLECTION_WIDGET)
{
    my ($C, $act, $piParamHashRef) = @_;
    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');

    # XXX tbw  Hack for use by LS.
    # original code gets data from action where operation put it but LS doesnt do that
    #    my $coll_hashref =
    #        $act->get_transient_facade_member_data($C, 'list_items_owned_collection_data');
    # is there a co on the ls action yes!
    my $co = $act->get_transient_facade_member_data($C, 'collection_object');
    my $owner = $co->get_user_id;
    my $CS = $act->get_transient_facade_member_data($C, 'collection_set_object');
    my $coll_hashref = $CS->get_coll_data_from_user_id($owner);
    # end hack

    my $s = '';
    foreach my $row (@{$coll_hashref})
    {
         # don't list current collection
        if ($row->{'MColl_ID'} != $coll_id)
        {
            my $collinfo = '';
            $collinfo .= wrap_string_in_tag($row->{'MColl_ID'}, 'collid');
            $collinfo .= wrap_string_in_tag($row->{'collname'}, 'CollName');
            $s .= wrap_string_in_tag($collinfo, 'Coll');
        }
    }

    return $s;
}


# ---------------------------------------------------------------------

=item PT_HREF_helper

Does path mapping to support development vs. production path elements
and to support The Shibboleth Dirty Hack: /shcgi/

=cut

# ---------------------------------------------------------------------
sub PT_HREF_helper {
    my ($C, $extern_id, $which) = @_;

    my $temp_cgi = new CGI('');
    $temp_cgi->param('id', $extern_id);
    $temp_cgi->param('debug', scalar CGI::param('debug'));

    my $cgi = $C->get_object('CGI');
    my $q1 = $cgi->param('q1');
    $temp_cgi->param('q1', $q1);


    my $config = $C->get_object('MdpConfig');
    my $key;
    if ($which eq 'pt_search') {
        $key = 'pt_search_script';
    }
    else {
        $key = 'pt_script';
    }
    my $pt_script = $config->get($key);

    # The Shibboleth Dirty Hack
    my $shib = $C->get_object('Auth')->auth_sys_is_SHIBBOLETH($C) && $C->get_object('Auth')->is_cosign_active();
    if ($shib) {
        $pt_script =~ s,/cgi/,/shcgi/,;
    }
    my $href = Utils::url_to($temp_cgi, $pt_script);

    return $href;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007 ©, The Regents of The University of Michigan, All Rights Reserved

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
