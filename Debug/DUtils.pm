package Debug::DUtils;

=head1 NAME

Debug::DUtils

=head1 DESCRIPTION

This is a package of development enviroment tools

=head1 VERSION

=head1 SYNOPSIS

use Debug::DUtils;
setup_debug_environment($ses);


=head1 SUBROUTINES

=over 8

=cut

BEGIN {
    use Exporter ();
    @Debug::DUtils::ISA = qw(Exporter);
    @Debug::DUtils::EXPORT = qw(
                                   DEBUG
                              );
}

use CGI;
use Session;
use Utils;
use Auth::ACL;


# Package lexical to enable debug message buffering for later display
# across redirects
my $g_session = undef;
my $g_xml_debugging = undef;


# DEBUG
my $non_HathiTrust_IP = '0.0.0.0';
my %HathiTrust_IP_hash =
  (
   'uom'  => '141.211.175.37', # clamato
   'wisc' => '198.150.174.127',
   'ind'  => '192.203.115..127',
   'ucal' => '128.195.127.127',
   'msu'  => '207.73.115..127',
   'nwu'  => '209.100.79.127',
   'osu'  => '128.146.127.127',
   'psu'  => '150.231.127.127',
  );

# ---------------------------------------------------------------------

=item setup_debug_environment

Set DEBUG envvar based on debug CGI param.  We want
CGI::Carp::DebugScreen when we are not running under the
debugger.

Under the web server we want the debug screen when in a
development environment and the error screen when in a production
environment.

Should be called early in the compilation phase to
reliably report errors.

=cut

# ---------------------------------------------------------------------
sub setup_debug_environment {
    my $ses = shift;

    # To retrieve the debug message buffer
    $g_session = $ses if ($ses);

    return if (! debugging_enabled());

    my $cgi = new CGI;
    my $debugging = $cgi->param('debug');

    $ENV{'DEBUG'} = $debugging
      if ($debugging);

    my @requested_switches =  split(',', $debugging);
    set_xml_debugging_enabled(\@requested_switches);

    # Record surrogate auth system file message
    ASSERT($main::g_auth_debug_message !~ m/\[FATAL\]/,
           $main::g_auth_debug_message);
    DEBUG('all,auth', $main::g_auth_debug_message);

    set_HathiTrust_debug_environment();
}


# ---------------------------------------------------------------------

=item set_HathiTrust_debug_environment

Allow debug switches debug=hathi,{ind|pst|...|uc1}, debug=nonhathi by
setting corresponding IP addrs.

debug=nonlib allows SDRINST untouched but makes it appear that user is
not in a library building.

=cut

# ---------------------------------------------------------------------
sub set_HathiTrust_debug_environment {
    if (DEBUG('hathi')){
        foreach my $inst_code (keys %HathiTrust_IP_hash) {
            if (DEBUG($inst_code)) {
                $ENV{'SDRINST'} = $inst_code;
                delete $ENV{'SDRLIB'};
                $ENV{'REMOTE_ADDR'} = $HathiTrust_IP_hash{$inst_code};
                last;
            }
        }
        if (DEBUG('shib')) {
            $ENV{'AUTH_TYPE'} = 'shibboleth';
            $ENV{'affiliation'} = 'member@umich.edu';
            $ENV{'unscoped-affiliation'} = 'member';
        }
    }
    elsif (DEBUG('nonhathi')) {
        delete $ENV{'AUTH_TYPE'};
        delete $ENV{'SDRINST'};
        delete $ENV{'SDRLIB'};
        delete $ENV{'eppn'};
        delete $ENV{'affiliation'};
        delete $ENV{'unscoped-affiliation'};

        $ENV{'REMOTE_ADDR'} = $non_HathiTrust_IP;
    }
    elsif (DEBUG('notlogged')) {
        delete $ENV{'REMOTE_USER'};
        delete $ENV{'AUTH_TYPE'};
        delete $ENV{'eppn'};
        delete $ENV{'affiliation'};
        delete $ENV{'unscoped-affiliation'};
    }

    if (DEBUG('nonlib')) {
        delete $ENV{'SDRLIB'};
        $ENV{'REMOTE_ADDR'} = $non_HathiTrust_IP;
    }

    DEBUG('hathi,nonhathi,nonlib,shib,notlogged',
          qq{HathiTrust DEBUG: SDRINST='$ENV{'SDRINST'}' SDRLIB='$ENV{'SDRLIB'}' eduPersonAffiliation=$ENV{'unscoped-affiliation'} eduPersonScopedAffiliation=$ENV{'affiliation'} eduPersonPrincipalName=$ENV{'eppn'} displayName=$ENV{'displayName'} AUTH_TYPE=$ENV{'AUTH_TYPE'} REMOTE_ADDR='$ENV{'REMOTE_ADDR'}'});
}


# ---------------------------------------------------------------------

=item under_server

Description

=cut

# ---------------------------------------------------------------------
sub under_server {
    return (Utils::HTTP_hostname() ne 'localhost');
}

# ---------------------------------------------------------------------

=item set_xml_debugging_enabled

Description

=cut

# ---------------------------------------------------------------------
sub set_xml_debugging_enabled {
    my $requested_switches_ref = shift;
    $Debug::DUtils::g_xml_debugging =
      scalar(grep(/^xml$|^rawxml$|^xsl$/, @$requested_switches_ref));
}

# ---------------------------------------------------------------------

=item setup_DebugScreen

=cut

# ---------------------------------------------------------------------
sub setup_DebugScreen {
    if (under_server()) {
        my $development = $ENV{'HT_DEV'};

        require CGI::Carp::DebugScreen;
        import CGI::Carp::DebugScreen ('engine' => 'HTML::Template');
        CGI::Carp::DebugScreen->debug($development);
        CGI::Carp::DebugScreen->show_modules(0);
        CGI::Carp::DebugScreen->show_environment($development);
        CGI::Carp::DebugScreen->ignore_overload(0);
        CGI::Carp::DebugScreen->show_raw_error($development);
    }
    # Support early DEBUG calls before Session is created.
    setup_debug_environment();
}

# ---------------------------------------------------------------------

=item process_availability_file_msg

Description

=cut

# ---------------------------------------------------------------------
sub process_availability_file_msg {
    my $template_file_text_ref = shift;
    my $msg = shift;

    my $msg_ref;

    if (defined($msg)) {
        $msg_ref = \$msg;
    }
    else {
        my $default_filename = $ENV{'SDRROOT'} . '/mdp-web/default-availability-message.txt';
        $msg_ref = Utils::read_file($default_filename, 1);
    }

    if ($msg_ref) {
        $$template_file_text_ref =~ s,<\?AVAILABILITY_MESSAGE\?>,$$msg_ref,;
    }
}


# ---------------------------------------------------------------------

=item handle_template_file

Select the correct message template file for the error condition

=cut

# ---------------------------------------------------------------------
sub handle_template_file {
    my $msg = shift;

    my $template_ref;

    if (defined($ENV{'UNAVAILABLE'})) {
        my $filename = $ENV{'SDRROOT'} . '/mdp-web/MBooks_unavailable.html';
        $template_ref = Utils::read_file($filename, 1);
        process_availability_file_msg($template_ref, $msg);
    }
    else {
        my $filename = $ENV{'SDRROOT'} . '/mdp-web/production_error.html';
        $template_ref = Utils::read_file($filename, 1);
    }

    CGI::Carp::DebugScreen->set_error_template($$template_ref)
        if ($$template_ref);
}


# ---------------------------------------------------------------------

=item set_error_template

WARNING: IDEMPOTENT: if anything fails here and calls ASSERT we have an
infinite loop. Should only be called from ASSERT_core().

=cut

# ---------------------------------------------------------------------
my $set_error_template_done = 0;
sub set_error_template {
    my $msg = shift;

    return if ($set_error_template_done);

    my $development = $ENV{'HT_DEV'};
    if (under_server() && (! $development)) {
        handle_template_file($msg);
    }

    $set_error_template_done = 1;
}

# ---------------------------------------------------------------------

=item __debug_Log

Description

=cut

# ---------------------------------------------------------------------
my $debug_logging = 0 ;
sub __debug_Log {
    my $msg = shift;
    my $force = shift;

    unless ($force) {
        return if (! $debug_logging)
    }

    my $debug_log_file = '/tmp/mdpdebugging.log';
    open(DBG, ">>$debug_log_file");
    chmod 0666, $debug_log_file;
    my $m = ((ref($msg) eq 'CODE') ? &$msg : $msg);
    print DBG qq{$m\n};
    close (DBG);
}

# ---------------------------------------------------------------------

=item DEBUG

conditionally emit debugging info passed as a string parameter.  Returns
true if switch matched DEBUG envvar

if (DEBUG('foo,bar,baz')
{
   # do some debug related code that
   # does not store a message in the debug message buffer
   # such as set a flag e.g. DBI_TRACE
}

or

DEBUG('foo,bar,baz' qq{this is a message));

Store a message in the debug buffer

or use a closure to execute code to generate the message to store in
the debug message buffer.  Messages must be a parameter to debug
either as a coderef or a scalar

DEBUG('foo,bar',
          sub
          {
              my $x2 = $pageQuery;
              Utils::map_chars_to_cers(\$x2);
              return $x2;
          });

=cut

# ---------------------------------------------------------------------
sub DEBUG {
    my ($switches, $msg) = @_;

    return 0 if (! $ENV{'DEBUG'});

    my @requested_switches =  split(',', $ENV{'DEBUG'});
    my $match = 0;

    # printing a msg for 'xml' or 'rawxml' or 'xsl' messes up the
    # output.  See also Debug::DUtils::setup_debug_environment()
    my $server_debugging = under_server();

    my @switches = split(',', $switches);
    if (! $g_xml_debugging) {
        @switches = ('all')
          if (grep(/all/, @requested_switches)
              &&
              grep(/all/, @switches));
    }

    my $msg_out = 0;
    foreach my $switch (@switches) {
        if (grep(/^$switch$/, @requested_switches)) {
            if ($msg) {
                if (! $g_xml_debugging) {
                    next if ($msg_out);

                    if ($server_debugging) {
                        handle_buffered_debug_msg($msg);
                    }
                    else {
                        handle_terminal_debug_msg($msg);
                    }
                    $msg_out = 1;
                }
                __debug_Log($msg, 1);
            }
            $match++;
        }
    }

    return $match;
}


# ---------------------------------------------------------------------

=item handle_buffered_debug_msg

Store message on for later output

=cut

# ---------------------------------------------------------------------
sub handle_buffered_debug_msg {
    my $message = shift;

    my $msg;
    if (ref($message) eq 'CODE') {
        # Invoke closure
        $msg = $message->();
    }
    else {
        $msg = $message;
    }

    my $message_buffer_ref = $g_session->get_persistent('debug_message_buffer');
    $msg = qq{<p><font color="brown"> $msg </font></p>\n};
    $$message_buffer_ref .= $msg;

    $g_session->set_persistent('debug_message_buffer', $message_buffer_ref);
}

# ---------------------------------------------------------------------

=item handle_terminal_debug_msg

Emit message immediately

=cut

# ---------------------------------------------------------------------
sub handle_terminal_debug_msg {
    my $msg = shift;

    my $message;
    if (ref($msg) eq 'CODE') {
        $message = $msg->();
    }
    else {
        $message = $msg;
    }

    # Remove HTML tags intended for debug messages intended for
    # browser display
    # Utils::replace_endtags_with_newlines(\$message);

    # If we are not attached to a terminal only save to message buffer.
    if ($ENV{'TERM'}) {
        print qq{$message\n};
        $main::MESSAGE_BUFFER .= qq{$message\n};
    }
    else {
        $main::MESSAGE_BUFFER .= qq{$message\n};
    }
}


# ---------------------------------------------------------------------

=item debugging_enabled

Limit debug= functionality for certain classes of users.  Rules:

(1) Production web: allowed when authenticated
(2) Development command line: allowed globally
(3) Development web: allowed for HT_DEV == uniqname

=cut

# ---------------------------------------------------------------------
sub debugging_enabled {
    my $user_type = shift;

    # Over-ride all authorization checking.  DO NOT GO INTO PRODUCTION
    # WITH THIS SET!
    my $___no_ACL_debugging_test = ($ENV{'HT_DEV'} =~ m,[a-z]+,) || $ENV{'TERM'};

    return 1
      if ($___no_ACL_debugging_test);
    # POSSIBLY NOTREACHED

    return Auth::ACL::a_Authorized($user_type);
}


# ---------------------------------------------------------------------

=item print_env

Format the %ENV hash

=cut

# ---------------------------------------------------------------------
sub print_env {
    my $format = shift;

    my ($html_start, $html_end) = ('<h4>', '</h4>')
      if ($format eq 'html');

    my $s;
    foreach my $key (sort keys(%ENV)) {
        my $e = $ENV{$key};
        Utils::map_chars_to_cers(\$e);
        $s .= qq{$html_start$key = $e$html_end\n};
    }
    return $s;
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
