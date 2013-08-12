package Utils;

=head1 NAME

Utils;

=head1 DESCRIPTION

This is a package of shared utility subroutines with no application
specific dependencies.  Let's keep it that way.

=head1 VERSION

=head1 SUBROUTINES

=over 8

=cut



BEGIN
{
    use Exporter();
    @Utils::ISA = qw(Exporter);
    @Utils::EXPORT = qw(
                             ASSERT
                             ASSERT_fail
                             soft_ASSERT
                             silent_ASSERT
                             find_file
                             read_file
                             write_data_to_file
                             add_attribute
                             wrap_string_in_tag
                             wrap_string_in_tag_by_ref
                             min
                             max
                            );
}

use Carp;
use CGI;
use URI;
use Encode;
use LWP::UserAgent;

# Local
use Context;
use View::Fallback;
use Debug::DUtils;

use JSON::XS;


# ---------------------------------------------------------------------

=item ASSERT_fail

degugging breakable routine to trap at assert failues

=cut

# ---------------------------------------------------------------------
sub ASSERT_fail
{
    undef;
}

# ---------------------------------------------------------------------

=item ASSERT_core

Basic assertion functionality

=cut

# ---------------------------------------------------------------------
sub ASSERT_core
{
    my ($condition, $msg, $send_email, $die, $force) = @_;

    ASSERT_fail();

    my $development = $ENV{'HT_DEV'} || ($ENV{HTTP_HOST} eq 'test.babel.hathitrust.org');
    if ( $send_email )
    {
        if (Debug::DUtils::under_server() && (! $development || $force))
        {
            require Debug::Email;
            Debug::Email::buffer_debug_email($msg);
        }
    }

    if ($die)
    {
        # route around weird conflict between Plack and HTML::Template
        unless ( exists($ENV{'psgi.version'}) ) {
            Debug::DUtils::set_error_template($msg);
        }
        croak('ASSERT_FAIL: '. $msg)
    }
}


# ---------------------------------------------------------------------

=item silent_ASSERT

trap error conditions, die without email

=cut

# ---------------------------------------------------------------------
sub silent_ASSERT
{
    my ($condition, $msg) = @_;

    if (! $condition)
    {
        ASSERT_core($condition, $msg, 0, 1);
    }
}


# ---------------------------------------------------------------------

=item soft_ASSERT

trap error conditions, send email under the server when not in
development mode (unless the force parameter is true) and keep running

=cut

# ---------------------------------------------------------------------
sub soft_ASSERT
{
    my ($condition, $msg, $force) = @_;

    if (! $condition)
    {
        # send mail only when available
        my $send_mail = (! defined($ENV{'UNAVAILABLE'}));
        ASSERT_core($condition, $msg, $send_mail, 0, $force);
    }
}


# ---------------------------------------------------------------------

=item ASSERT

trap error conditions, send email under the server when not in development mode and die

=cut

# ---------------------------------------------------------------------
sub ASSERT
{
    my ($condition, $msg) = @_;

    if (! $condition)
    {
        # send mail only when available
        my $send_mail = (! defined($ENV{'UNAVAILABLE'}));
        ASSERT_core($condition, $msg, $send_mail, 1);
    }
}

# ---------------------------------------------------------------------

=item get_hostname

Description

=cut

# ---------------------------------------------------------------------
sub get_hostname
{
    my $host = `hostname`;
    chomp($host);
    return $host;
}

# ---------------------------------------------------------------------

=item get_cookie_domain

Class method to build a domain string "two dot" requirement based on
the virtual host

=cut

# ---------------------------------------------------------------------
sub get_cookie_domain
{
    my $cgi = shift;

    my $virtual_host = HTTP_hostname();

    my ($cookie_domain) = ($virtual_host =~ m,^.*(\..+?\..+?)$,);
    if (! $cookie_domain)
    {
        $cookie_domain = '.' . $virtual_host;
    }

    return $cookie_domain;
}

# ---------------------------------------------------------------------

=item max

Description

=cut

# ---------------------------------------------------------------------

sub max
{
    my ($a, $b) = @_;
    return $b if ($b > $a);
    return $a;
}


# ---------------------------------------------------------------------

=item trim_spaces

Description

=cut

# ---------------------------------------------------------------------
sub trim_spaces
{
    my $s_ref = shift;

    $$s_ref =~ s,^\s*,,;
    $$s_ref =~ s,\s*$,,;
}


# ---------------------------------------------------------------------

=item Name

Description

=cut

# ---------------------------------------------------------------------
sub min
{
    my ($a, $b) = @_;
    return $b if ($b < $a);
    return $a;
}

# ---------------------------------------------------------------------

=item obfuscate_email_addr

turn an email address into a javascript concatenation for use as:
<a href="" onmouseover="this.href='foo'+'@'+'bar'+'.com'">foobar</a>

=cut

# ---------------------------------------------------------------------
sub obfuscate_email_addr
{
    my $addr = shift;
    my @chars = split( //, $addr );
    return "'" . join( "'+'", @chars ) . "'";
}

# ---------------------------------------------------------------------

=item display_stats

Description

=cut

# ---------------------------------------------------------------------
sub display_stats
{
    my ( $cpuUSER, $cpuSYSTEM ) = times;
    my ( $realEND ) = time;
    my $elapsed  = $realEND - $main::realSTART;

    my $t = qq{<TABLE BORDER="0"><TR><TD>Realtime (sec.) </TD><TD>CPU User (sec.)</TD><TD>CPU System (sec.) </TD></TR><TR><TD>$elapsed </TD><TD>$cpuUSER </TD><TD>$cpuSYSTEM </TD></TR></TABLE>};

    return $t;
}


# ---------------------------------------------------------------------

=item min_of_list

Description

=cut

# ---------------------------------------------------------------------
sub min_of_list
{
    my @list = @_;
    my $min;
    if (@list)
    {
        $min = shift( @list );
        foreach my $n (@list)
        {
            $min = $n
                if ($n < $min)
        }
    }
    return $min;
}

# ---------------------------------------------------------------------

=item max_of_list

Description

=cut

# ---------------------------------------------------------------------
sub max_of_list
{
    my @list = @_;
    my $max;
    if ( @list )
    {
        $max = shift( @list );
        foreach my $n ( @list )
        {
            $max = $n
                if ($n > $max)
        }
    }
    return $max;
}

# ---------------------------------------------------------------------

=item get_tmp_logdir

Description

=cut

# ---------------------------------------------------------------------
sub get_tmp_logdir {
    my $logdir = $ENV{SDRROOT} . '/logs/tmp';
    Utils::mkdir_path($logdir);
    chmod(0777, $logdir) if (-o $logdir);

    return $logdir;
}

# ---------------------------------------------------------------------

=item mkdir_path

Description

=cut

# ---------------------------------------------------------------------
sub mkdir_path {
    my $path = shift;

    use File::Path;

    if (! -e $path) {
        DEBUG('all,pt', qq{<h4>MkdirPath: $path, umask=} . umask() . qq{</h4>\n});
        eval { File::Path::mkpath( $path ); };
        ASSERT((! $@), qq{mkpath/mkdir error: "$@" for destination="$path"});
    }
}

# ---------------------------------------------------------------------

=item minimal_CER_to_NCR_map

Handle mapping to NCRs (so they'll parse in XML) a few CERs that are
likely to appear in names. see Auth::Auth:: __get_parsed_displayName() e.g.

Based on http://www.w3.org/TR/xhtml1/DTD/xhtml-lat1.ent

=cut

# ---------------------------------------------------------------------
sub minimal_CER_to_NCR_map {
    my $cer = shift;

    $cer =~ s,[;&],,g;

    my %h = (
             Agrave => '&#192;', Aacute => '&#193;', Acirc  => '&#194;', Atilde => '&#195;', Auml   => '&#196;', Aring  => '&#197;',
             AElig  => '&#198;', Ccedil => '&#199;', Egrave => '&#200;', Eacute => '&#201;', Ecirc  => '&#202;', Euml   => '&#203;',
             Igrave => '&#204;', Iacute => '&#205;', Icirc  => '&#206;', Iuml   => '&#207;', ETH    => '&#208;', Ntilde => '&#209;',
             Ograve => '&#210;', Oacute => '&#211;', Ocirc  => '&#212;', Otilde => '&#213;', Ouml   => '&#214;', Oslash => '&#216;',
             Ugrave => '&#217;', Uacute => '&#218;', Ucirc  => '&#219;', Uuml   => '&#220;', Yacute => '&#221;', THORN  => '&#222;',
             szlig  => '&#223;', agrave => '&#224;', aacute => '&#225;', acirc  => '&#226;', atilde => '&#227;', auml   => '&#228;',
             aring  => '&#229;', aelig  => '&#230;', ccedil => '&#231;', egrave => '&#232;', eacute => '&#233;', ecirc  => '&#234;',
             euml   => '&#235;', igrave => '&#236;', iacute => '&#237;', icirc  => '&#238;', iuml   => '&#239;', eth    => '&#240;',
             ntilde => '&#241;', ograve => '&#242;', oacute => '&#243;', ocirc  => '&#244;', otilde => '&#245;', ouml   => '&#246;',
             divide => '&#247;', oslash => '&#248;', ugrave => '&#249;', uacute => '&#250;', ucirc  => '&#251;', uuml   => '&#252;',
             yacute => '&#253;', thorn  => '&#254;', yuml   => '&#255;',
            );
    return $h{$cer};
}


# ---------------------------------------------------------------------

=item map_chars_to_cers

map things like Simon & Schuster to Simon &amp; Schuster But leave
Espa&#x00F1;ol unaltered.

OCR may have random garbage that turns out to looks like a valid NCR
or CER. Since it's garbage, do not unescape the escaped '&'

=cut

# ---------------------------------------------------------------------
my %cer_hash =
    (
     qq{<} => qq{&lt;},
     qq{>} => qq{&gt;},
     qq{'} => qq{&apos;},
     qq{"} => qq{&quot;},
     qq{&} => qq{&amp;},
    );

my %cer_name_hash =
    (
     qq{<} => qq{lt},
     qq{>} => qq{gt},
     qq{'} => qq{apos},
     qq{"} => qq{quot},
     qq{&} => qq{amp},
    );

sub map_chars_to_cers {
    my $s_ref = shift;
    my $exclude_arr_ref = shift;
    my $skip_restore_step = shift;

    my %l_cer_hash = %cer_hash;
    if ($exclude_arr_ref) {
        foreach my $c (@$exclude_arr_ref) {
            delete $l_cer_hash{$c};
        }
    }

    foreach my $char (keys %l_cer_hash) {
        $$s_ref =~ s,\Q$char\E,$l_cer_hash{$char},g;
    }

    # restore XML character entity references like "&amp;" that became
    # "&amp;amp;" or &gt; that became &amp;gt; from the above mapping
    foreach my $name (values %cer_name_hash) {
        $$s_ref =~ s|\&amp;$name;|\&$name;|g;
    }

    # If input is known to be OCR we can (probably) safely skip the
    # following restore
    if (! $skip_restore_step) {
        # fix decimal and hexadecimal NCRs broken by above mapping
        $$s_ref =~ s|\&amp;(\#[xX]([0-9a-fA-F]){1,4};)|\&$1|g;
        $$s_ref =~ s|\&amp;(\#([0-9]){1,4};)|\&$1|g;
    }
}

my %reverse_cer_hash = reverse( %cer_hash );
sub remap_cers_to_chars
{
    my $s_ref = shift;
    $$s_ref =~ s|(\&[a-z]{2,4};)|$reverse_cer_hash{$1} ? $reverse_cer_hash{$1} : $1|ges;
}

# ---------------------------------------------------------------------

=item xml_escape_url_separators

XML escape '&' in a &-separated URL. There is no predefined XML
character entity reference for ';' which is also a legitimate URL
separator but some services do not recognize it as a separator so to
be friendly we convert ';' separators to &amp; too. Any occurrences of
& and ; in parameter /values/ must already have been URL escaped to
%26 and %3B or the URL would not have been valid.

=cut

# ---------------------------------------------------------------------
sub xml_escape_url_separators {
    my $url = shift;

    my $escaped_url = $url;

    $escaped_url =~ s,[&],&amp;,g;
    if ($escaped_url eq $url) {
        # was not &-separated. check for ;-separated
        $escaped_url =~ s,[;],&amp;,g;
    }

    return $escaped_url;
}

# ---------------------------------------------------------------------

=item remove_nonprinting_chars

Description

=cut

# ---------------------------------------------------------------------
sub remove_nonprinting_chars
{
    my $s_ref = shift;
    $$s_ref =~ s,[\n\r\t\f\e], ,g;

    # Kill characters that are invalid in XML data. Valid XML
    # characters and ranges are:

    #  (c == 0x9) || (c == 0xA) || (c == 0xD)
    #             || ((c >= 0x20) && (c <= 0xD7FF))
    #             || ((c >= 0xE000) && (c <= 0xFFFD))
    #             || ((c >= 0x10000) && (c <= 0x10FFFF))

    $$s_ref =~ s,[\000-\010\013-\014\016-\037]+, ,gs;
}

# ---------------------------------------------------------------------

=item clean_cgi_params

Perform a variety of processes on incoming CGI parameters to make data
inside the program UTF-8 and XML clean

=cut

# ---------------------------------------------------------------------
sub clean_cgi_params
{
    my $cgi = shift;

    foreach my $p ($cgi->param)
    {
        my @vals = $cgi->param($p);
        my @newvals = ();
        foreach my $v (@vals)
        {
            if (defined($v) && ($v !~ m,^\s*$,))
            {
                $v = Encode::decode_utf8($v);
                remove_nonprinting_chars(\$v);
                remove_truncated_cers(\$v);
                map_chars_to_cers(\$v, [qq{"}, qq{'}]);
                trim_spaces(\$v);

                push(@newvals, $v);
            }
        }

        if (scalar(@newvals) > 0)
        {
            $cgi->param($p, @newvals);
        }
        else
        {
            $cgi->delete($p);
        }
    }
}


# ---------------------------------------------------------------------

=item url_over_SSL_to

Change http to https

=cut

# ---------------------------------------------------------------------
sub url_over_SSL_to
{
    my $url = shift;

    $url =~ s,^http(:|%3A),https$1,;
    return $url;
}

# ---------------------------------------------------------------------

=item url_over_nonSSL_to

Change https to http

=cut

# ---------------------------------------------------------------------
sub url_over_nonSSL_to
{
    my $url = shift;

    $url =~ s,^https,http,;
    return $url;
}

# ---------------------------------------------------------------------

=item Name

Wrapper for CGI::self_url so we can build the correct url for link
building to a cgi program from within a different cgi.

CGI::self_url always returns $ENV{SCRIPT_NAME} which may not be the
cgi to which we want to build a link. Do reverse character entity
mapping to undo the mapping performed CGI object to recover the user's
original input

=cut

# ---------------------------------------------------------------------
sub url_to
{
    my ($cgi, $script_name) = @_;

    my $temp_cgi = new CGI($cgi);

    foreach my $p ($temp_cgi->param())
    {
        my @vals = $temp_cgi->param($p);
        my @newvals = ();
        foreach my $v (@vals)
        {
            $v = Encode::decode_utf8($v);
            remap_cers_to_chars(\$v);
            push(@newvals, $v);
        }
        if (scalar(@newvals) > 0)
        {
            $temp_cgi->param($p, @newvals);
        }
        else
        {
            $temp_cgi->delete($p);
        }
    }

    my $url;
    if ($script_name) {
        $url = $temp_cgi->url(-query=>1, -absolute=>1, -rewrite=>0);
    }
    else {
        $url = $temp_cgi->url(-query=>1, -absolute=>1, -rewrite=>1);
    }

    # if a scriptname was explicitly passed in, use it instead
    if ( $script_name )
    {
        my $curr_script_name = $temp_cgi->script_name();
        $url =~ s,$curr_script_name,$script_name,;
    }

    return $url;
}

# ---------------------------------------------------------------------

=item wrap_string_in_tag

put an XML tab pair with optional attributes around some element
content.  $attributes_array_ref is an reference to an array of
attribute name/value pairs, each pair in an array ref

             e.g.:
             [
               [ 'name1', 'value1' ],
               [ 'name2', 'value2' ],
             ]

wrap_string_in_tag($href, 'LoginLink');

=cut

# ---------------------------------------------------------------------
sub wrap_string_in_tag
{
    my ($s, $tag, $attributes_array_ref, $singleton) = @_;

    my $open_tag;
    $open_tag .= '<' . $tag;
    if ($attributes_array_ref)
    {
        foreach my $attribute_pair_ref (@$attributes_array_ref)
        {
            $open_tag .= ' ' . $$attribute_pair_ref[ 0 ] . qq{=\"} . $$attribute_pair_ref[ 1 ] . qq{\"};
        }
    }
    $open_tag .= $singleton ? qq{/>} : qq{>};

    my $closeTag;
    if ($singleton)
    {
        $closeTag =  qq{\n};
    }
    else
    {
        $closeTag = qq{</} . $tag . qq{>} . qq{\n};
    }

    return $open_tag . $s . $closeTag;
}



# ---------------------------------------------------------------------

=item wrap_string_in_tag_by_ref

Same as wrap_string_in_tag but by reference

=cut

# ---------------------------------------------------------------------
sub wrap_string_in_tag_by_ref
{
    my ($s_ref, $tag, $attributes_array_ref) = @_;

    my $open_tag;
    $open_tag .= '<' . $tag;
    if ($attributes_array_ref)
    {
        foreach my $attribute_pair_ref (@$attributes_array_ref)
        {
            $open_tag .= ' ' . $$attribute_pair_ref[ 0 ] . qq{=\"} . $$attribute_pair_ref[ 1 ] . qq{\"};
        }
    }
    $open_tag .= '>';

    my $close_tag = '</' . $tag . '>' . qq{\n};

    $$s_ref = $open_tag . $$s_ref . $close_tag;

    return $$s_ref;
}

# ---------------------------------------------------------------------

=item add_attribute

Description

=cut

# ---------------------------------------------------------------------
sub add_attribute
{
    my ( $s_ref, $attribute_name, $attribute_value ) = @_;
    $$s_ref =~ s,^<(.*?)>,'<'.$1.' '.$attribute_name.qq{="}.$attribute_value.qq{"}.'>',es;
}



# ---------------------------------------------------------------------

=item build_hidden_var_XML

Build the XML that plays with the HiddenVars template in
xsl2htmlutils.xsl

=cut

# ---------------------------------------------------------------------
sub build_hidden_var_XML
{
    my ($cgi, $var) = @_;

    my @a = ($cgi->param( $var ));

    my $toReturn = '';
    if (@a)
    {
        foreach my $a (@a)
        {
            $toReturn .= wrap_string_in_tag($a, 'Variable', [['name', $var]]);
        }
    }

    return $toReturn;
}



# ---------------------------------------------------------------------

=item get_user_agent

What it says.  Cache UA in file lexical

=cut

# ---------------------------------------------------------------------
my $user_agent = undef;
sub get_user_agent
{
    return $user_agent if $user_agent;

    $user_agent = LWP::UserAgent->new;
    $user_agent->timeout(10);
    $user_agent->env_proxy;
    return $user_agent;
}

# ---------------------------------------------------------------------

=item get_true_cache_dir

Construct $SDRROOT/{cache|cache-full}/$key

=cut

# ---------------------------------------------------------------------
sub get_true_cache_dir {
    my $C = shift;
    my $cache_dir_key = shift;

    # polymorphic : allow MdpConfig or Context as parameter
    my $config = ref($C) eq 'Context' ? $C->get_object('MdpConfig') : $C;

    my $cache_dir = $ENV{SDRROOT} . $config->get($cache_dir_key);
    my $true_cache_component = ($ENV{SDRVIEW} eq 'full') ? 'cache-full' : 'cache';

    $cache_dir =~ s,___CACHE___,$true_cache_component,;

    return $cache_dir;
}


# ---------------------------------------------------------------------

=item get_uber_config_path

Description

=cut

# ---------------------------------------------------------------------
sub get_uber_config_path {
    my $app_name = shift;

    my $path;
    if (DEBUG('local')) {
        $path = $ENV{SDRROOT} . "/mdp-lib/Config/uber.conf"
    }
    else {
        $path = $ENV{SDRROOT} . "/$app_name/vendor/common-lib/lib/Config/uber.conf"
    }

    return $path;
}


# ---------------------------------------------------------------------

=item resolve_fallback_path

Description

=cut

# ---------------------------------------------------------------------
sub resolve_fallback_path
{
    my $C = shift;
    my $bare_filename = shift;
    my $optional = shift;

    my $resolved_path;
    my $fb = new View::Fallback($C);
    my $fallback_path_arr_ref = $fb->get_fallback_path($C);

    DEBUG('tpl', qq{---<br/>resolving file="$bare_filename" optional=} . ($optional ? "yes" : "NO"));

    foreach my $path (@$fallback_path_arr_ref)
    {
        my $filename = $ENV{'SDRROOT'} . $path . '/' . $bare_filename;

        if (DEBUG('tpl')) {
            require Utils::Logger;
            Utils::Logger::__Log_simple(qq{resolving file="$filename"});
        }

        if (-e $filename)
        {
            $resolved_path = $filename;
            DEBUG('tpl', qq{<b>HIT:</b> file="$filename"<br/>---});
            last;
        }
        else
        {
            DEBUG('tpl', qq{miss: file="$filename"});
        }
    }

    return $resolved_path;
}


# ---------------------------------------------------------------------

=item find_file

Wrapper for read_file to support fallback.

=cut

# ---------------------------------------------------------------------
sub find_file
{
    my $C = shift;
    my $bare_filename = shift;
    my $optional = shift;

    my $resolved_path = resolve_fallback_path($C, $bare_filename, $optional);
    return (read_file($resolved_path, $optional), $resolved_path);
}


# ---------------------------------------------------------------------

=item read_file

Obvious

=cut

# ---------------------------------------------------------------------
sub read_file
{
    my $filename = shift;
    my $optional = shift;
    my $retry = shift;

    my $text = '';
    my $ok;

    $ok = open(PAGE, '<:utf8', "$filename");
    if ($ok)
    {
        $text = join('', <PAGE>);
        my $is_utf8 = (length($text) == 0) || Encode::is_utf8($text, 1);

        if (! $is_utf8)
        {
            if ($retry)
            {
                # try raw
                $ok = open(PAGE, "$filename");
                if ($ok)
                {
                    $text = join('', <PAGE>);
                }
            }
        }
    }

    silent_ASSERT($ok, qq{could not open file="$filename"})
        unless ($optional);

    close (PAGE);

    return \$text;
}


# ---------------------------------------------------------------------

=item write_data_to_file

Obvious

=cut

# ----------------------------------------------------------------------
sub write_data_to_file
{
    my ($data_ref, $filename) = @_;

    ASSERT(open(OUTFILE, ">:utf8", $filename),
           qq{Cannot open $filename for writing});
    print OUTFILE $$data_ref;
    close( OUTFILE );
}

# ---------------------------------------------------------------------

=item resolve_data_root, using_localdataroot

Support alternative data root for sample HTDE environment and for
developing outside the real repository for a designated list of IDs.

=cut

# ---------------------------------------------------------------------
sub using_localdataroot {
    my ($C, $id) = @_;

    # Only in development or on the beta-* with a local.conf present
    return unless (defined $ENV{HT_DEV});
    # POSSIBLY NOTREACHED

    # Attempt to stop use of local.conf::localdataroot = /sdr1
    my $config = $C->get_object('MdpConfig');
    if ($config->has('localdataroot')) {
        my $localdataroot = $config->get('localdataroot');
        die if ($localdataroot =~ m,^/sdr1,);

        if ($config->has('localdevelopmentids')) {
            my @development_ids = $config->get('localdevelopmentids');
            if (grep(/^$id$/, @development_ids)) {
                return $ENV{SDRDATAROOT} = $localdataroot;
            }
        }
    }
    # POSSIBLY NOTREACHED

    return;
}

sub resolve_data_root {
    my $id = shift;
    my $C = new Context;

    # This could be early in the Plack layers before app initialization
    my $config = $C->get_object('MdpConfig', 1);
    return '/dev/null' unless (defined $config);
    # POSSIBLY NOTREACHED

    my $dataroot = using_localdataroot($C, $id);

    return $ENV{SDRDATAROOT} unless(defined $dataroot);
    return $dataroot;
}

# ---------------------------------------------------------------------

=item HTTP_hostname

wrap HTTP_HOST

=cut

# ---------------------------------------------------------------------
sub HTTP_hostname
{
    return $ENV{'HTTP_HOST'} ? $ENV{'HTTP_HOST'} : 'localhost';
}


# ---------------------------------------------------------------------

=item remove_truncated_tags

Description

=cut

# ---------------------------------------------------------------------
sub remove_truncated_tags
{
    my $s_ref = shift;

    # clean chopped half-tags at line beginnings
    $$s_ref =~ s,^[^<>]*>, ,;
    # clean chopped half-tags at line endings
    $$s_ref =~ s,<[^<>]*$, ,;
}


# ---------------------------------------------------------------------

=item remove_truncated_cers

the only chopped XML entities we expect to see are lt, gt, apos, quot
and amp hence the limit of 4 below

=cut

# ---------------------------------------------------------------------
sub remove_truncated_cers
{
    my $s_ref = shift;

    # remove what might be chopped entities at beginning of string
    $$s_ref =~ s/^[^&]{1,4}\;//;

    # remove what might be chopped entities at end of string
    # or a lone &
    $$s_ref =~ s/\&\#?[Xx]?[0-9a-zA-Z-]*$//;
}

# ---------------------------------------------------------------------

=item remove_tags

Description

=cut

# ---------------------------------------------------------------------
sub remove_tags
{
    my ( $s_ref, $element ) = @_;

    if ( $element )
    {
        # remove entire elements ...
        $$s_ref =~ s,<([A-Za-z0-9]+)[^>]*>.*?</\1>,,gs;
        # ...and singletons
        $$s_ref =~ s,<[A-Za-z0-9]+[^>]*>,,gs;
    }
    else
    {
        # just remove tags ( and PIs like <?xml ...?>)
        $$s_ref =~ s,</?[A-Za-z0-9]+[^>]*>,,gs;
        $$s_ref =~ s,<\?.*?\?>,,gs;
    }
}


# ---------------------------------------------------------------------

=item remove_PI

Description

=cut

# ---------------------------------------------------------------------
sub remove_PI {
    my ( $s_ref, $PI ) = @_;

    # just remove this PI like <?xml ...?> else all of them)
    if ($PI) {
        $$s_ref =~ s,<\?$PI.*?\?>,,gs;
    }
    else {
        $$s_ref =~ s,<\?.*?\?>,,gs;
    }
}

# ---------------------------------------------------------------------

=item replace_endtags_with_newlines

Description

=cut

# ---------------------------------------------------------------------
sub replace_endtags_with_newlines
{
    my ( $s_ref ) = @_;

    $$s_ref =~ s,</[^>]*>,\n,gs;
}


# ---------------------------------------------------------------------

=item file_exists

Not there or there but zero length

=cut

# ---------------------------------------------------------------------
sub file_exists
{
    my $fileName = shift;

    use constant SIZE_IN_BYTES => 7;
    return (-e $fileName && (stat($fileName))[SIZE_IN_BYTES] > 0)
}

# ---------------------------------------------------------------------

=item build_HTML_pulldown_XML

$list_ref is an array_ref of select *values*

$label_hashref is a hashref of select menu labels keyed by the values

=cut

# ---------------------------------------------------------------------
sub build_HTML_pulldown_XML
{
    my ($name, $list_ref, $label_hashref, $default, $pi_param_hashref) = @_;

    my $s;

    # concoct labels for eventual HTML Select object's options and
    # their values
    foreach my $item (@$list_ref)
    {
        my $item_string;
        my $label = $$label_hashref{$item} ? $$label_hashref{$item} : $item;
        $item_string .= wrap_string_in_tag($label, 'Label');
        $item_string .= wrap_string_in_tag($item, 'Value');
        $item_string .= wrap_string_in_tag('true', 'Focus')
            if ($item =~ m,^$default$,);

        $s .= wrap_string_in_tag($item_string, 'Option');
    }
    $s .= wrap_string_in_tag($name, 'Name');
    $s .= wrap_string_in_tag($default, 'Default');

    return $s;
}


# ---------------------------------------------------------------------

=item sort_uniquify_list

sort and uniq any list (alphabetically by default, numerically if any
second param with any value at all is passed in)

=cut

# ---------------------------------------------------------------------
sub sort_uniquify_list
{
    my ($a_ref, $numeric) = @_;
    my %hash;

    foreach my $item (@$a_ref)
    {
        $hash{$item}++;
    }

    if (defined ($numeric) )
    {
        @$a_ref = sort {$a <=> $b} (keys %hash);
    }
    else
    {
        @$a_ref = sort (keys %hash);
    }
}

# ---------------------------------------------------------------------

=item add_header

add HTTP response header to HTTP::Headers object in Config.

=cut

# ---------------------------------------------------------------------
sub add_header
{
    my ($C, $key, $value) = @_;
    my $headers_ref = $C->get_object('HTTP::Headers', 1);
    unless(ref($headers_ref)) {
        $headers_ref = HTTP::Headers->new;
        $C->set_object('HTTP::Headers', $headers_ref);
    }
    if ( lc $key eq 'cookie' ) {
        $key = 'Set-Cookie';
        my @values = $headers_ref->header($key);
        push @values, $value;
        $headers_ref->header($key => \@values);
    } else {
        $headers_ref->header($key => $value);
    }
}

sub get_user_status_cookie
{
    my ($C, $auth) = @_;

    my $displayName = $auth->get_user_display_name($C, 'unscoped');
    my $institution = $auth->get_institution_code($C, 'mapped');
    my $institution_name = $auth->get_institution_name($C, 'mapped');
    my $print_disabled = $auth->get_eduPersonEntitlement_print_disabled($C);
    my $auth_type;
    if ( $auth->auth_sys_is_SHIBBOLETH($C) ) {
        $auth_type = 'shibboleth';
    }
    elsif ( $auth->auth_sys_is_COSIGN($C) ) {
        $auth_type = 'cosign';
    }
    my $status = { authType => $auth_type, displayName => $displayName, institution => $institution, affiliation => $institution_name, u => $print_disabled };

    my $cookie = new CGI::Cookie(
        -name => "HTstatus",
        -path => "/",
        -domain => get_cookie_domain(),
        -value => encode_json($status)
    );

    return $cookie;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-12 ©, The Regents of The University of Michigan, All Rights Reserved

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


