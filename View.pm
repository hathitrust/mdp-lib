package View;

=head1 NAME

View (vw)

=head1 DESCRIPTION

This class is responsible for template management and binding of the
PI handlers in Actions to the PIs in the template and the invocation
of said PI handlers.

=head1 VERSION

$Id: View.pm,v 1.43 2010/02/03 20:33:32 pfarber Exp $

=head1 SYNOPSIS

my $vw = new View($C);

$vw->execute_view($C, $act);

$vw->output($C);

or

$self->output_HTTP($C, $data_ref, ['text/xml'] );

PRIVATE:

$vw->_install_PI_handlers($C, $act);

$vw->_run_PI_handlers($C);

$vw->_render_template($C);


=head1 METHODS

=over 8

=cut

BEGIN
{
    if ($ENV{'HT_DEV'})
    {
        require "strict.pm";
        strict::import();
    }
}


use PI;
use Context;
use Utils;
use Action;
use Debug::DUtils;
use Utils::XSLT;

use Operation::Status;

use Utils;
use HTTP::Headers;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}



# ---------------------------------------------------------------------

=item _initialize

Initialize View.

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my $C = shift;

    $self->{'pio'} = new PI;

    my $ab = $C->get_object('Bind');

    $self->read_template($C, $ab);
    $self->process_template_includes($C, $ab);
    $self->parse_template_PIs($C, $ab);
}



# ---------------------------------------------------------------------

=item get_page

Description

=cut

# ---------------------------------------------------------------------
sub get_page {
    my $self = shift;

    my $page = $self->{'page'};
    ASSERT($page, qq{View page not set});

    return $page;
}


# ---------------------------------------------------------------------

=item execute_view

Handle the logic of the view including determination of whether the
application should redirect to produce the view or simply produce the
view inline.

=cut

# ---------------------------------------------------------------------
sub execute_view {
    my $self = shift;
    my ($C, $act) = @_;

    # bind the Action's PIFiller to the template PIs
    $self->_install_PI_handlers($C, $act);

    # run the PI handlers
    $self->_run_PI_handlers($C);

    # transform XML -> HTML via XSLT
    $self->_render_template($C);
}




# ---------------------------------------------------------------------

=item read_template

Read the text of the template for the action in question from the disk

=cut

# ---------------------------------------------------------------------
sub read_template {
    my $self = shift;
    my ($C, $ab) = @_;

    my $template_name = $ab->get_action_template_name($C);
    my ($template_ref, $full_path) = find_file($C, $template_name, 0);

    $self->{'template_data_ref'} = $template_ref;
    $self->{'template_name'} = $full_path;
}


# ---------------------------------------------------------------------

=item get_template_data

Template text data ref accessor.

=cut

# ---------------------------------------------------------------------
sub get_template_data {
    my $self = shift;
    my $C = shift;

    return $self->{'template_data_ref'};
}




# ---------------------------------------------------------------------

=item get_template_name

Template name accessor.

=cut

# ---------------------------------------------------------------------
sub get_template_name {
    my $self = shift;
    my $C = shift;

    return $self->{'template_name'};
}


# ---------------------------------------------------------------------

=item process_template_includes

Iteratively process chunk PIs until no more chunk PIs are seen as a
result of doing the inclusions. (Chunks can have chunks).

Note that only one level of infinite loop checking is performed,
i.e. A incl A is trapped and A incl B incl A is trapped but A incl B
incl B is not. Good enough for government work.

=cut

# ---------------------------------------------------------------------
sub process_template_includes {
    my $self = shift;

    my ($C, $ab) = @_;

    my $template_name = $ab->get_action_template_name($C);
    my $template_ref = $self->get_template_data($C);

    my $chunkRegExp = '<\?CHUNK\s+(\w+)="(.*?)"(\s+(\w+)="(.*?)")?\?>';

    while ( $$template_ref =~ s,$chunkRegExp,<sp0t>,s ) {
        my $filename_param = $1;
        my $filename_val = $2;

        my $optional_param = $4;
        my $optional_val = $5;

        ASSERT($template_name ne $filename_val,
                qq{Infinite recursion: parent file=$template_name, chunk file=$filename_val});
        ASSERT($filename_param eq 'filename',
                qq{CHUNK PI has invalid parameter name "$filename_param=$filename_val"});
        ASSERT($optional_param eq 'optional',
                qq{CHUNK PI has invalid parameter name "$optional_param=$optional_val"})
            if ($optional_param);

        my $optional = ($optional_val eq "1") ? "1" : "0";
        my ($include_ref, $include_path) = find_file($C, $filename_val, $optional);

        $$template_ref =~ s,<sp0t>,$$include_ref,s;
    }
}



# ---------------------------------------------------------------------

=item parse_template_PIs

Parse and store an array of PI names found in the template for this
view.

=cut

# ---------------------------------------------------------------------
sub parse_template_PIs {
    my $self = shift;
    my $C = shift;

    my $pio = $self->get_pio();

    my $template_ref = $self->get_template_data($C);
    my $PI_arr_ref = $pio->get_PIs($template_ref);

    # remove XML PIs
    @$PI_arr_ref = grep(!/^xml(-stylesheet)?/, @$PI_arr_ref);
    my %PI_hash = map { $_ => 0 } @$PI_arr_ref;
    $self->{'PIs'} = \%PI_hash;
}


# ---------------------------------------------------------------------

=item get_view_PIs

Return an array of PI names found in the template for this view.

=cut

# ---------------------------------------------------------------------
sub get_view_PIs {
    my $self = shift;
    my $C = shift;
    return $self->{'PIs'};
}



# ---------------------------------------------------------------------

=item _install_PI_handlers


PRIVATE: Bind the PI handlers in PIFillers to the PIs in the template
for this view.

The PIFiller has a hash of code references to its PI handlers formed
at compile time via the CPAN Attribute::Handlers package.

The keys of the hash are the PIs that each of its PI handlers was
declared to handle.

Get this list and bind the code references to the actual PI
occurrencess in the template for this view.

=cut

# ---------------------------------------------------------------------
sub _install_PI_handlers {
    my $self = shift;

    my($C, $act) = @_;

    my $pio = $self->get_pio();

    my $view_PIs_hashref = $self->get_view_PIs($C);

    DEBUG('pis,all',
          sub {
              my $s = qq{<h3>PIs found:</h3>};
              foreach my $pi (keys %$view_PIs_hashref) {
                  $s .= qq{<h5>$pi</h5>};
              }
              return $s;
          });

    my $PI_to_handler_hashref = $act->get_PI_handler_mapping($C);

    DEBUG('pis,all',
          sub {
              require Data::Dumper;
              $Data::Dumper::Indent = 2;
              $Data::Dumper::Deparse = 1;
              my $dump = Data::Dumper->Dump( [$PI_to_handler_hashref], [qw($PI_to_handler_hashref)] );
              Utils::map_chars_to_cers(\$dump) if Debug::DUtils::under_server();
              return qq{<pre>$dump</pre>};
          });

    # assign a handler code ref to one of the PIs in the template
    foreach my $handled_PI (keys %$PI_to_handler_hashref) {
        my $PI_handler = $$PI_to_handler_hashref{$handled_PI};

        # is this PI handler needed for a PI in this template?
        if (exists($$view_PIs_hashref{$handled_PI})) {
            # yes!
            $$view_PIs_hashref{$handled_PI}++;
            ASSERT($$view_PIs_hashref{$handled_PI} == 1,
                   qq{Duplicate handler for PI="$handled_PI" found in } . ref($act));

            $pio->add_PI($handled_PI, $PI_handler, [$C, $act]);
        }
        else {
            # no!
            DEBUG('pis', qq{Unneeded PI handler for "$handled_PI" found in } . ref($act));
        }
    }

    # Are any template PIs left unhandled?
    foreach my $PI (keys %$view_PIs_hashref) {
        DEBUG('pis', qq{PI="$PI" not handled for action=} . ref($act))
            if (! $$view_PIs_hashref{$PI});
    }
}


# ---------------------------------------------------------------------

=item _run_PI_handlers

Fire the PI handlers to fill the PI

=cut

# ---------------------------------------------------------------------
sub _run_PI_handlers {
    my $self = shift;
    my $C = shift;

    return if (DEBUG('rawxml'));

    __debug($C);

    my $pio = $self->get_pio();
    my $template_data_ref = $self->get_template_data($C);

    $pio->process_PIs($template_data_ref);

}

# ---------------------------------------------------------------------

=item _set_transformed_xml

PRIVATE: Save the transformed template data

=cut

# ---------------------------------------------------------------------
sub _set_transformed_xml {
    my $self = shift;
    my $transformed_xml_ref = shift;

    $self->{'transformed_xml'} = $transformed_xml_ref;
}



# ---------------------------------------------------------------------

=item _get_transformed_xml

PRIVATE: Get the saved transformed template data

=cut

# ---------------------------------------------------------------------
sub _get_transformed_xml {
    my $self = shift;
    return $self->{'transformed_xml'};
}

# ---------------------------------------------------------------------

=item __transform_paths

Support for debug=local switch for web paths.  See also Vendor.pm for
functionality to paths to Perl modules.

Take a reference to the output string and map web paths containing
'//common-web/' to common-web submodule or local clone of mdp-web.git
depending on the value of DEBUG.

=cut

# ---------------------------------------------------------------------
sub __transform_paths {
    my $self = shift;
    my ($C, $ref) = @_;
    
    if (DEBUG('local')) {
        $$ref =~ s,//common-web/,/mdp-web/,g;
    }
    else {
        my $app_name = $C->get_object('App')->get_app_name();
        $$ref =~ s,//common-web/,/$app_name/common-web/,g;
    }
}

# ---------------------------------------------------------------------

=item _render_template

PRIVATE: Transform the XML via XSLT

=cut

# ---------------------------------------------------------------------
sub _render_template
{
    my $self = shift;
    my $C = shift;

    my $template_data_ref = $self->get_template_data($C);
    my $template_name = $self->get_template_name($C);

    # Debug message buffer support
    handle_DEBUG_MESSAGES_PI($C, $template_data_ref);

    if (DEBUG('xml,rawxml')) {
        $$template_data_ref = Encode::encode_utf8($$template_data_ref);
        # remove empty PI handlers to avoid browser rendering issues
        Utils::remove_PI($template_data_ref);
        $self->output_HTTP($C, $template_data_ref, 'text/xml' );
        exit 0;
    }
    # POSSIBLY NOTREACHED


    my $stylesheet_text_ref =
        $self->build_virtual_stylesheet($C, $template_data_ref, $template_name);

    if (DEBUG('xsl')) {
        $self->output_HTTP($C, $stylesheet_text_ref, 'text/xml' );
        exit 0;
    }
    # POSSIBLY NOTREACHED


    if (DEBUG('xsltwrite')) {
        my $config = $C->get_object('MdpConfig');
        my $cache_dir = Utils::get_true_cache_dir($C, 'xsltwrite_cache_dir') . '/';
        Utils::mkdir_path($cache_dir);
        my $user = (Utils::Get_Remote_User() || 'anonymous-' . time());
        my $partial_path = $cache_dir . $user;
        my $xsl_filename = $partial_path . '.temp.xsl';
        my $xml_filename = $partial_path . '.temp.xml';

        write_data_to_file($stylesheet_text_ref, $xsl_filename);
        write_data_to_file($template_data_ref, $xml_filename);
        my $m = qq{wrote files: $xsl_filename, $xml_filename};
        $self->output_HTTP($C, \$m);
        exit 0;
    }
    # POSSIBLY NOTREACHED


    my $parsed_xml =
        Utils::XSLT::parse_xml($template_data_ref, $template_name);

    my $transformed_xml_ref =
        Utils::XSLT::transform_driver($parsed_xml, $template_name,
                                           $stylesheet_text_ref);

    # Serious magic
    $self->__transform_paths($C, $transformed_xml_ref);

    $self->_set_transformed_xml($transformed_xml_ref);
}



# ---------------------------------------------------------------------

=item P_output_data_HTTP

Description: Procedural interface to output data

=cut

# ---------------------------------------------------------------------
sub P_output_data_HTTP {
    my ($C, $data_ref, $content_type) = @_ ;

    if (Debug::DUtils::xml_debugging_enabled()) {
        Utils::remove_PI($data_ref, 'xml');
    }

    $content_type = 'text/html'
        if (! $content_type);

    my $charset = 'UTF-8';
    
    Utils::add_header($C, 'Content-type' => qq{$content_type; charset=$charset});
    
    my $ses = $C->get_object('Session', 1);
    if ($ses) {
        my $cookie = $ses->get_cookie();
        Utils::add_header($C, 'Cookie' => $cookie);
    }    
    
    my $auth = $C->get_object('Auth', 1);
    if ($auth && $auth->isa_new_login()) {
        my $cookie = Utils::get_user_status_cookie($C, $auth);
        Utils::add_header($C, 'Cookie' => $cookie);
    }
    
    my $headers_ref = $C->get_object('HTTP::Headers');
    
    print STDOUT "Status: 200" . $CGI::CRLF;
    print STDOUT $headers_ref->as_string($CGI::CRLF);
    print STDOUT $CGI::CRLF;
    $$data_ref =~ s,^<!DOCTYPE [^>]+>,<!DOCTYPE html>,;
    _add_ie_specific_code($data_ref);
    print STDOUT $$data_ref;
}

sub IF_LT_IE9 {
    return <<END;
<!--[if lt IE 9]>
<script src="//ie7-js.googlecode.com/svn/version/2.1(beta4)/IE9.js"></script>
<script src="//html5shiv.googlecode.com/svn/trunk/html5.js"></script>
<![endif]-->
END
}

sub IF_LT_IE8 {
    return <<END;
<!--[if lt IE 8]>
<link rel="stylesheet" type="text/css" href="/common/unicorn/css/ie7.css" />
<script src="/common/unicorn/vendor/js/selectivizr.js" type="text/javascript"></script>
<![endif]-->
END
}

sub _add_ie_specific_code {
    my ( $data_ref ) = @_;

    my $html = IF_LT_IE9();
    $$data_ref =~ s{<!--IE PRE-SETUP-->}{$html};
    $html = IF_LT_IE8();
    $$data_ref =~ s{<!--IE POST-SETUP-->}{$html};

}



# ---------------------------------------------------------------------

=item output

Description: interface to output data.  Can be over-ridden to
call different output methods


=cut

# ---------------------------------------------------------------------
sub output {
    my $self = shift;
    my $C = shift;
    my $content_type = shift;
    
    my $transformed_xml_ref = $self->_get_transformed_xml($C);
    $self->output_HTTP($C, $transformed_xml_ref, $content_type);
}



# ---------------------------------------------------------------------

=item output_HTTP

Description: interface to output data.  Can be over-ridden to
call different output methods

=cut

# ---------------------------------------------------------------------
sub output_HTTP {
    my $self = shift;
    my ($C, $data_ref, $content_type) = @_ ;

    View::P_output_data_HTTP($C, $data_ref, $content_type);
}


# ---------------------------------------------------------------------

=item build_virtual_stylesheet

Parse xml template xsl fallback list and construct in memory
stylesheet source. Compile it.

=cut

# ---------------------------------------------------------------------
sub build_virtual_stylesheet {
    my $self = shift;

    my ($C, $xml_page_ref, $xml_page_name) = @_;

    # Get virtual stylesheet file list
    my @xsl_filename_list;
    my $parsed_xml = Utils::XSLT::parse_xml($xml_page_ref, $xml_page_name);

    foreach my $xsl_filename_node ($parsed_xml->findnodes('//XslFileList/Filename')) {
        my $xsl_path;
        my $filename = $xsl_filename_node->findvalue('.');

        $xsl_path = Utils::resolve_fallback_path($C, $filename, 0);

        push(@xsl_filename_list, $xsl_path);
    }

    # Construct in-memory stylesheet
    my $transform_template = $C->get_object('MdpConfig')->get('transform_template');
    my ($stylesheet_text_ref, $stylesheet_path) = find_file($C, $transform_template, 0);

    my $pio = new PI;
    $pio->add_PI('XSL_FILE_LIST', 'handle_XSL_FILELIST_PI',
                [$self, $C, \@xsl_filename_list]);

    $pio->process_PIs($stylesheet_text_ref);

    DEBUG('transform', qq{virtual XSL stylesheet derived from $transform_template});

    return $stylesheet_text_ref;
}


# ---------------------------------------------------------------------

=item handle_XSL_FILELIST_PI

Local PI handler for processing a PI in the template for the virtual
stylesheet.  Does not play the Perl Attribute::Handler game.

=cut

# ---------------------------------------------------------------------
sub handle_XSL_FILELIST_PI {
    my $self = shift;
    my ($C, $file_arr_ref) = @_;

    my $s = '';

    foreach my $f (@$file_arr_ref) {
        $s .= wrap_string_in_tag('', 'xsl:import', [['href', $f]],
                                 undef, 'singleton');
    }

    return $s;
}


# ---------------------------------------------------------------------

=item get_pio

PI object accessor

=cut

# ---------------------------------------------------------------------
sub get_pio {
    my $self = shift;
    return $self->{'pio'};
}

# ---------------------------------------------------------------------

=item handle_DEBUG_MESSAGES_PI

Place debug messages stored on session in the output stream.

NOTE: This is **NOT** a PI handler that obeys the Attribute::Handler
syntax in its declaration like normal PI handlers.  It is called
*after* PI handling is complete so that any buffered debug statements
generated after PI handling can make it into the outpurt stream.

=cut

# ---------------------------------------------------------------------
sub handle_DEBUG_MESSAGES_PI {
    my ($C, $data_ref) = @_;

    return unless (
                   Debug::DUtils::debugging_enabled
                   &&
                   $C->has_object('Session')
                  );

    my $ses = $C->get_object('Session');

    # Dump session contents to the debug message buffer at the last
    # possible instant before the <?DEBUG_MESSAGES?> PI is to be
    # processed.
    DEBUG('fullsession',
          sub {
              return $ses->session_dumper();
          });

    my $buffer_ref = $ses->get_persistent('debug_message_buffer');
    $$data_ref =~ s,<\?DEBUG_MESSAGES\?>,($buffer_ref && $$buffer_ref) ? $$buffer_ref : '',e;

    # Dispose messages
    $ses->set_persistent('debug_message_buffer', undef);
}


# ---------------------------------------------------------------------

=item __debug

Description

=cut

# ---------------------------------------------------------------------
sub __debug {
    my $C = shift;

    DEBUG('version,all',
          sub {
              my $s = sprintf( "<h3>Perl version = %vd</h3>", $^V );
              $s .= qq{<h3>main program version = $::VERSION</h3><br />};
              return $s;
          });

    DEBUG('cgi,all',
          sub {
              my $cgi = $C->get_object('CGI');
              my $s = $cgi->as_string();
              return $s;
          });

    DEBUG('env,all',
          sub {
              my $s = Debug::DUtils::print_env('html');
              return $s;
          });

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

