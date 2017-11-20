package MdpGlobals;

# Copyright 2007 The Regents of The University of Michigan, All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Set path to feedback cgi as a function of development state and auth state.
my $auth_type = $ENV{AUTH_TYPE} || '';

our $is_cosign_active = ( defined $ENV{HT_IS_COSIGN_STILL_HERE} && $ENV{HT_IS_COSIGN_STILL_HERE} eq 'yes' );
my $cgi_path_component = ($auth_type eq 'shibboleth' && is_cosign_active) ? '/shcgi' : '/cgi';
# my $protocol  = $auth_type ? 'https://' : 'http://';
my $protocol = 'https://';

my $host = $ENV{'HTTP_HOST'} || '';

$gFeedbackCGIUrl = $protocol . $host . $cgi_path_component . q{/feedback};

# General configuration
$adminLink  = q{mailto:dlps-help@umich.edu};
$adminText  = q{UMDL Help};

# App::MdpItem
$gMetsFileExtension    = '.mets.xml';
$gOcrXmlFileExtension  = '.ocr.xml';
$gInitFileExtension    = '.init';

$gDefaultOrientation  = '0';
$gDefaultRotation     = '0';

%gValidRotationValues = 
    (
     '0' => '0',
     '1' => '90',
     '2' => '180',
     '3' => '270'
    );

# When we get XML compliant HTML for hOCR
$ghOCREnabled          = 0;

# ---------------------------------------------------------------------
# Page Features
# ---------------------------------------------------------------------
%gMdpPageFeatureHash =
    (
     'ADVERTISEMENTS'              => 'Advertisements',
     'APPENDIX'                    => 'Appendix',
#     'BACK_COVER'                  => 'Back Cover',
     'CHAPTER_START'               => 'Section',
     'COPYRIGHT'                   => 'Copyright',
     'FIRST_CONTENT_CHAPTER_START' => 'Section',
     'FRONT_COVER'                 => 'Front Cover',
#     'FOLDOUT'                     => 'Foldout',
     'INDEX'                       => 'Index',
#     'IMAGE_ON_PAGE'               => 'Image',
     'LIST_OF_ILLUSTRATIONS'       => 'List of Illustrations',
     'LIST_OF_MAPS'                => 'List of Maps',
     'MAP'                         => 'Map',
     'MULTIWORK_BOUNDARY'          => 'Section',
     'NOTES'                       => 'Notes',
     'PREFACE'                     => 'Preface',
     'REFERENCES'                  => 'Bibliography',
     'TABLE_OF_CONTENTS'           => 'Table of Contents',
     'TITLE'                       => 'Title Page',     
    );


# OBSOLETE
%gMiunPageFeatureHash =
    (
     '1STPG' =>'First Page',
#     'ACK'  =>'Acknowledgement',
     'ADV'  =>'Advertisement',
     'APP'  =>'Appendix',
     'BIB'  =>'Bibliography',
#     'BLP'  =>'Blank Page',
#     'CTP'  =>'Cover Title Page',
     'CTP'  =>'Title Page',
     'DIG'  =>'Digest',
     'ERR'  =>'Errata',
#     'FNT'  =>'Front Matter',
#     'HIS'  =>'History',
#     'IND'  =>'Comprehensive Index',
     'IND'  =>'Index',
     'LOI'  =>'List of Illustrations',
     'LOT'  =>'List of Tables',
     'MAP'  =>'Map',
#     'MIS'  =>'Miscellaneous',
#     'MSS'  =>'Manuscript',
     'NOT'  =>'Notes',
#     'NPN'  =>'[n/a]',
#     'ORD'  =>'Ordinances',
     'PNI'  =>'Author/Name Index',
     'PNT'  =>'Production Note',
     'PRE'  =>'Preface',
     'PRF'  =>'Preface',
     'REF'  =>'References',
#     'REG'  =>'Regulations',
#     'RUL'  =>'Rules',
     'SPI'  =>'Special Index',
     'SUI'  =>'Subject Index',
     'SUP'  =>'Supplement',
#     'TAB'  =>'Table',
     'TOC'  =>'Table of Contents',
     'TPG'  =>'Title Page',
#     'UNS'  =>'',
#     'VES'  =>'Volume End Sheets',
#     'VLI'  =>'Volume List of Illus',
     'VLI'  =>'List of Illustrations',
     'VOI'  =>'Volume Index',
#     'VPG'  =>'Various Pagination',
#     'VTP'  =>'Volume Title Page',
     'VTP'  =>'Title Page',
#     'VTV'  =>'Volume Title Page Verso',
     'VTV'  =>'Title Page',
);     

$gPageFeatureHashRef = \%gMdpPageFeatureHash,


1;
