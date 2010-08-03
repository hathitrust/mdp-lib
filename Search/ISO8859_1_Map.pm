package App::Search::ISO8859_1_Map;


=head1 NAME

App::Search::CharMapping

=head1 DESCRIPTION

This package defines a hash to map Latin1 ligatures and characters
like LATIN SMALL LETTER SHARP S (ß) to two characters on input of OCR
for XPAT indexing and of the users qusry string.  Solr/Lucene performs
this mapping using the ISOLatin1AccentFilter.  XPAT cannot map a
single character to to characters.

The map is taken from ISOLatin1AccentFilter.java.
 
=head1 SYNOPSIS

=over 8

=cut

my %mapH =
(
 "\x{00C6}" => 'AE', # Æ
 "\x{0132}" => 'IJ', # Ĳ
 "\x{0152}" => 'OE', # Œ
 "\x{00DE}" => 'TH', # Þ
 "\x{0133}" => 'ij', # ĳ
 "\x{0153}" => 'oe', # œ
 "\x{00DF}" => 'ss', # ß
 "\x{00FE}" => 'th', # þ
 "\x{FB00}" => 'ff', # ﬀ
 "\x{FB01}" => 'fi', # ﬁ
 "\x{FB02}" => 'fl', # ﬂ
 "\x{FB05}" => 'ft', # ﬅ
 "\x{FB06}" => 'st', # ﬆ
);


# ---------------------------------------------------------------------

=item iso8859_1_mapping

Description

=cut

# ---------------------------------------------------------------------
sub iso8859_1_mapping {
    my $s_ref = shift;

    foreach my $char (keys %mapH) {
        $$s_ref =~ s,\Q$char\E,$mapH{$char},g;
    }
}

1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008-9 ©, The Regents of The University of Michigan, All Rights Reserved

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
