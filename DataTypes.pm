package DataTypes;


use strict;
use warnings;


use XML::LibXML;

=head1 NAME

DataTypes

=head1 DESCRIPTION

This package provides an interface to determine, for a given object in
the HathiTrust repository, what its data type is based on METS profile
and other defining attributes.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

our %dataTypeMatrix =
  (
   q{http://www.hathitrust.org/documents/hathitrust-mets-profile2.1.xml} =>
   [{
     _xpath   => q{},
     _value   => q{},
     _type    => q{volume},
     _subtype => q{volume},
    }],

   q{http://www.hathitrust.org/documents/hathitrust-mets-profile2.0.xml} =>
   [{
     _xpath   => q{},
     _value   => q{},
     _type    => q{volume},
     _subtype => q{volume},
    }],

   q{http://www.hathitrust.org/documents/hathitrust-epub-mets-profile1.0.xml} =>
   [{
     _xpath   => q{},
     _value   => q{},
     _type    => q{volume},
     _subtype => q{EPUB},
    }],

   q{http://www.hathitrust.org/documents/hathitrust-structured-mets-profile1.0.xml} =>
   [{
     _xpath   => q{normalize-space(/METS:mets/METS:amdSec/METS:techMD[@ID='textMD1']/METS:mdWrap[@MDTYPE='TEXTMD']/METS:xmlData/textMD:textMD/textMD:markup_language)},
     _value   => q{http://dtd.nlm.nih.gov/publishing/3.0/journalpublishing3.dtd},
     _type    => q{article},
     _subtype => q{JATS},
    },
    {
     _xpath   => q{normalize-space(/METS:mets/METS:amdSec/METS:techMD[@ID='textMD1']/METS:mdWrap[@MDTYPE='TEXTMD']/METS:xmlData/textMD:textMD/textMD:markup_language)},
     _value   => q{http://www.tei-c.org/release/xml/tei/schema/dtd//tei.dtd},
     _type    => q{volume},
     _subtype => q{TEI},
    }],

   q{http://www.hathitrust.org/documents/hathitrust-audio-mets-profile1.0.xml} =>
   [{
     _xpath   => q{},
     _value   => q{},
     _type    => q{audio},
     _subtype => q{audio},
    }],

    q{http://www.hathitrust.org/documents/hathitrust-emma-mets-profile1.0.xml} => 
    [{
      _xpath   => q{},
      _value   => q{},
      _type    => q{emma},
      _subtype => q{emma},
    }],
  );


# ---------------------------------------------------------------------

=item getDataType

Description

=cut

# ---------------------------------------------------------------------
sub getDataType {
    my $METS_root = shift;

    return __getMatrixValue($METS_root, '_type');
}


# ---------------------------------------------------------------------

=item getDataType

Description

=cut

# ---------------------------------------------------------------------
sub getDataSubType {
    my $METS_root = shift;

    return __getMatrixValue($METS_root, '_subtype');
}

sub getMarkupLanguage {
    my $METS_root = shift;
    return __getMatrixValue($METS_root, '_value');
}

# ---------------------------------------------------------------------

=item __getMatrixValue

Description

=cut

# ---------------------------------------------------------------------
sub __getMatrixValue {
    my $METS_root = shift;
    my $level = shift;

    my $profile = __get_METS_profile_URI($METS_root);

    my $discriminators = $dataTypeMatrix{$profile};

    if ($discriminators) {
        foreach my $d_hashref (@$discriminators) {
            my $xpath = $d_hashref->{_xpath};
            if ($xpath) {
                if ($METS_root->findvalue($xpath) eq $d_hashref->{_value}) {
                    return $d_hashref->{$level};
                }
            }
            else {
                return $d_hashref->{$level};
            }
        }
    }

    return undef;
}


# ---------------------------------------------------------------------

=item __get_METS_profile_URI

Description

=cut

# ---------------------------------------------------------------------
sub __get_METS_profile_URI {
    my $METS_root = shift;

    my $xpath = q{/METS:mets/@PROFILE};
    return $METS_root->findvalue($xpath);
}

1;

__END__

=back

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2013 ©, The Regents of The University of Michigan, All Rights Reserved

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
