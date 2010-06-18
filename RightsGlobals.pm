package RightsGlobals;

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

# Return codes from Database access
use constant OK_ID        => 0;
use constant BAD_ID       => 1;
use constant NO_ATTRIBUTE => 2;
use constant NO_SOURCE    => 4;
 
use constant NOOP_ATTRIBUTE => 0;

# ---------------------------------------------------------------------
# Keys are attributes in the Rights Matrix database Attributes table
# Values are authorizations by "user class" keys in the sub-hash:
# 'ordinary'
# 'ssd' (disabled, sight impaired)
# 'in a library building'
# 'UM authenticated'
# ---------------------------------------------------------------------
$ORDINARY_USER          = 1;
$SSD_USER               = 2;
$LIBRARY_IPADDR_USER    = 3;
$UM_AFFILIATE           = 4;
$HT_AFFILIATE           = 5;

@g_access_types = ($ORDINARY_USER .. $HT_AFFILIATE);

%g_access_type_names = 
    (
     $ORDINARY_USER          => 'ordinary_user',
     $SSD_USER               => 'ssd_user',
     $LIBRARY_IPADDR_USER    => 'in_library_user',
     $UM_AFFILIATE           => 'um_affiliate',
     $HT_AFFILIATE           => 'ht_affiliate',
    );

%g_attribute_names = 
    (
     '1' => 'public-domain',
     '2' => 'in-copyright',
     '3' => 'in-copyright out-of-print brittle',
     '4' => 'in-copyright orphaned',
     '5' => 'undetermined copyright',
     '6' => 'available to um affiliates + walk-ins',
     '7' => 'available to everyone',
     '8' => 'available to nobody',
     '9' => 'public-domain in us',     
    );

%g_source_names = 
    (
     '1' => 'google',
     '2' => 'dlps',
     '3' => 'um press',
     '4' => 'internet archive',
    );

%g_rights_matrix =
    (
     # public domain
     '1' => { 
             $ORDINARY_USER         => 'allow',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'allow',
             $UM_AFFILIATE          => 'allow',
             $HT_AFFILIATE          => 'allow',
            },
     # in-copyright
     '2' => { 
             $ORDINARY_USER         => 'deny',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'deny',
             $UM_AFFILIATE          => 'deny',
             $HT_AFFILIATE          => 'deny',
            },
     # OPB out-of-print and brittle (implies in-copyright).  As of Feb
     # 2010, UM affiliates can view OPB without being in a library but
     # only one such user is allowed to do so at a time. Exclusivity
     # is enforced and access granted downstream.
     '3' => { 
             $ORDINARY_USER         => 'deny',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'allow_by_lib_ipaddr',
             $UM_AFFILIATE          => 'allow_by_exclusivity', 
             $HT_AFFILIATE          => 'deny', 
            },
     # copyright-orphaned (implies in-copyright)
     '4' => { 
             $ORDINARY_USER         => 'deny',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'deny',
             $UM_AFFILIATE          => 'deny',
             $HT_AFFILIATE          => 'deny',
            },
     # undetermined copyright status
     '5' => { 
             $ORDINARY_USER         => 'deny',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'deny',
             $UM_AFFILIATE          => 'deny',
             $HT_AFFILIATE          => 'deny',
            },
     # available to UM affiliates and UM walk-in patrons (all campuses)
     '6' => { 
             $ORDINARY_USER         => 'deny',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'allow',
             $UM_AFFILIATE          => 'allow',
             $HT_AFFILIATE          => 'deny',
            },
     # available to everyone in the world
     '7' => { 
             $ORDINARY_USER         => 'allow',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'allow',
             $UM_AFFILIATE          => 'allow',
             $HT_AFFILIATE          => 'allow',
            },
     # available to no one in the world
     '8' => { 
             $ORDINARY_USER         => 'deny',
             $SSD_USER              => 'deny',
             $LIBRARY_IPADDR_USER   => 'deny',
             $UM_AFFILIATE          => 'deny',
             $HT_AFFILIATE          => 'deny',
            },
     # available if IP is in the "U.S."
     '9' => { 
             $ORDINARY_USER         => 'allow_by_geo_ipaddr',
             $SSD_USER              => 'allow',
             $LIBRARY_IPADDR_USER   => 'allow',
             $UM_AFFILIATE          => 'allow_by_geo_ipaddr',
             $HT_AFFILIATE          => 'allow_by_geo_ipaddr',
            },
    );

# ---------------------------------------------------------------------
# "Public domain"
# ---------------------------------------------------------------------
@g_public_domain_attribute_values = (1, 7, 9);
$g_public_domain_US_attribute_value = 9;

# ---------------------------------------------------------------------
# Source values authorized for full book PDF download.
# ---------------------------------------------------------------------
@g_full_PDF_download_open_source_values = (2, 4);
@g_full_PDF_download_closed_source_values = (1);

@g_source_values = keys %g_source_names;
@g_rights_attribute_values = keys %g_rights_matrix;

# ---------------------------------------------------------------------
# Geographic IP Information
# ---------------------------------------------------------------------
# Country codes used to determine public domain via the GeoIP database
# for attribute number 9
@g_pdus_country_codes = 
    (
     'US', # United States
     'UM', # United States Minor Outlying Islands
     'VI', # Virgin Islands, U.S.
    );


