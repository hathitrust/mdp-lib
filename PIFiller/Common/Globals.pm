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

use Utils;
use Debug::DUtils;
use Utils::Js;
use Access::Statements;
use Access::Rights;

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
        my @param_values = $cgi->param($param_name);
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
    my $source = $ar->get_source_attribute($C, $id);

    my $ref_to_arr_of_hashref = 
      Access::Statements::get_stmt_by_rights_values($C, undef, $attr, $source, 
                                                  {
                                                   stmt_url  => 1,
                                                   stmt_head => 1,
                                                  });
    my $hashref = $ref_to_arr_of_hashref->[0];
    my $url = $hashref->{stmt_url};
    my $head = $hashref->{stmt_head};
        
    my $s;
    $s .= wrap_string_in_tag($head, 'Header');
    $s .= wrap_string_in_tag($url, 'Link');

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
    # occassionally environment variable has chars in need of
    # mapping. e.g., AT&T
    Utils::map_chars_to_cers(\$v);

    return $v;
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
    $s .= wrap_string_in_tag($debug_js, JS);
    $s .= wrap_string_in_tag($debug_css, CSS);
    return $s;
}

# ---------------------------------------------------------------------
#
#                         Shared Subroutines
#
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------

=item get_owner_string

If the owner of a collection is an $SID (i.e. 32 characters) return
the $temp_coll_owner_string This is to replace the $SID which is used
for the owner name if collection created when user is not logged in

=cut

# ---------------------------------------------------------------------
sub get_owner_string
{
    my $C = shift;
    my $owner_string = shift;

    my $config = $C->get_object('MdpConfig');
    my $temp_coll_owner_string = $config->get('temp_coll_owner_string');
    
    if (
        (length($owner_string) == 32)
        &&
        ($owner_string =~ m,^[0-9a-f]+$,g)
       )
    {
        # The only time owner will be 32 characters and all hex digits
        # is if its a session_id
        $owner_string = $temp_coll_owner_string;
    } 

    # Obfuscate
    if ($owner_string ne $temp_coll_owner_string)
    {
        my @parts = split('@', $owner_string);
        $owner_string = $parts[0];
        if (scalar(@parts) > 1)
        {
            $owner_string .= " (*)";
        }
    }
    

    return $owner_string;
}
# ---------------------------------------------------------------------

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
