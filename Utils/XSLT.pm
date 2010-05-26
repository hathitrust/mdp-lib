package Utils::XSLT;

=head1 NAME

Utils::XSLT

=head1 DESCRIPTION

Non OO package containing XSLT related utilities.

=head1 SUBROUTINES

=over 8

=cut

# Perl
use Cwd;

# XML libraries
use XML::LibXSLT;
use XML::LibXML;

use Utils;

my $g_xml_parser  = XML::LibXML->new();
my $g_xslt_engine = XML::LibXSLT->new();



# ---------------------------------------------------------------------

=item parse_xml

Parse an XML file into a DOM tree

=cut

# ---------------------------------------------------------------------
sub parse_xml
{
    my ($xml_page_ref, $filename) = @_;

    my $parsed_xml;
    eval
    {
        $parsed_xml = $g_xml_parser->parse_string($$xml_page_ref);
    };
    ASSERT(!$@, qq{Parsing error msg="$@" in ref="$$xml_page_ref" from file="$filename"});

    return $parsed_xml;
}

# ---------------------------------------------------------------------

=item transform_driver

Parse the stylesheet text, compile the parsed result and apply that to
the parsed populated XML template to finish the transformation to HTML.

=cut

# ----------------------------------------------------------------------
sub transform_driver
{
    my ($parsed_xml, $xml_filename, $xsl_page_ref, $relative_dir) = @_;

    # So XSLT engine can find XSL imports without paths
    my $cwd;
    if ($relative_dir)
    {   
        $cwd = cwd();
        chdir($relative_dir);   
    }

    my $parsed_xsl = parse_xml($xsl_page_ref);

    # Compile XSL DOM tree into into a stylesheet object
    my $stylesheet = compile_stylesheet($parsed_xsl);

    my $results_ref = transform($stylesheet, $parsed_xml, $xml_filename);

    if ($relative_dir)
    {   chdir($cwd);   }

    return $results_ref;
}



# ---------------------------------------------------------------------

=item compile_stylesheet

What is says.

=cut

# ----------------------------------------------------------------------
sub compile_stylesheet
{
    my $parsed_xsl = shift;

    my $compiled_stylesheet;
    eval
    {
        $compiled_stylesheet = $g_xslt_engine->parse_stylesheet($parsed_xsl);
    };
    ASSERT(!$@, qq{Error compiling stylesheet DOM tree, msg="$@"});

    return $compiled_stylesheet;
}


# ---------------------------------------------------------------------

=item transform

Transform the XML using the compiled stylesheet and get the result as
a printable string.

=cut

# ----------------------------------------------------------------------
sub transform
{
    my ($stylesheet, $parsed_xml, $xml_filename) = @_;

    my $intermediate;
    eval
    {
        $intermediate = $stylesheet->transform($parsed_xml);
    };
    ASSERT(!$@, qq{Error msg="$@" when transforming file=$xml_filename});

    my $result;
    eval
    {
        $result = $stylesheet->output_string($intermediate);
    };
    ASSERT(!$@, qq{Error msg="$@" converting transformed XML to string XML="$xml_filename});

    return \$result;
}

1;





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

# ---------------------------------------------------------------------
