package RightsGlobals;

=head1 SYNOPSIS

 SOURCES
 id        name           dscr
 1         google         Google
 2         lit-dlps-dc    LIT, DLPS, Digital Conversion
 3         ump            University of Michigan Press 
 4         ia             Internet Archive
 5         yale           Yale University
 6         umn            University of Minnesota
 7         mhs            Minnesota Historical Society
 8         usup           Utah State University Press
 9         ucm            Universidad Complutense de Madrid
 10        purd           Purdue University
 11        getty          Getty Research Institute
 12        um-dc-mp       University of Michigan, Duderstadt Center, Millennium Project
 13        uiuc           University of Illinois at Urbana-Champaign 

 ATTRIBUTES
 id        name        type      dscr
 1         pd          copyright public domain
 2         ic          copyright in-copyright
 3         opb         copyright out-of-print and brittle (implies in-copyright)
 4         orph        copyright copyright-orphaned (implies in-copyright)
 5         und         copyright undetermined copyright status
 6         umall       access    available to UM affiliates and walk-in patrons (all campuses)
 7         ic-world    access    in-copyright and available to everyone in the world
 8         nobody      access    available to nobody; blocked for all users
 9         pdus        copyright public domain only when viewed in the US
 18        und-world   access    undetermined copyright status and permitted as world viewable
 19        icus        copyright in copyright in the US

 (Creative Commons)

 id        name        type       dscr
 10        cc-by       copyright  attribute work in manner specified by author
 11        cc-by-nd    copyright  cc-by + no derivatives upon distribution
 12        cc-by-nc-nd copyright  cc-by-nd + non-commercial use only
 13        cc-by-nc    copyright  cc-by +  non-commercial use only
 14        cc-by-nc-sa copyright  cc-by-nc + ccby-sa
 15        cc-by-sa    copyright  cc-by + same license upon redistribution
 17        cc-zero     copyright  cc0 license implies pd

 (Orphan works project)

 id        name        type        dscr
 16        orphcand    copyright   orphan candidate - in 90-day holding period (implies in-copyright)

 STATEMENT KEYS
 pd
 pd-google
 pd-us
 pd-us-google
 oa
 oa-google
 ic-access
 ic
 cc-by
 cc-by-nd
 cc-by-nc-nd
 cc-by-nc
 cc-by-nc-sa
 cc-by-sa
 orphcand
 cc-zero
 ic-us
 ic-us-google

=cut

# Return codes from Database access
our $OK_ID          = 0;
our $BAD_ID         = 1;
our $NO_ATTRIBUTE   = 2;
our $NO_SOURCE      = 4;

our $NOOP_ATTRIBUTE = 0;

# ---------------------------------------------------------------------
# Keys are attributes in the Rights Matrix database Attributes table
# Values are authorizations by "user class" keys in the sub-hash:
# 'ordinary'
# 'ssd' (disabled, sight impaired)
# 'in a library building'
# 'UM authenticated'
# ---------------------------------------------------------------------
our $ORDINARY_USER       = 1;
our $SSD_USER            = 2;
our $LIBRARY_IPADDR_USER = 3;
our $UM_AFFILIATE        = 4;
our $HT_AFFILIATE        = 5;

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
   '1'  => 'public-domain',
   '2'  => 'in-copyright',
   '3'  => 'in-copyright out-of-print brittle',
   '4'  => 'in-copyright orphaned',
   '5'  => 'undetermined copyright',
   '6'  => 'available to um affiliates + walk-ins',
   '7'  => 'available to everyone',
   '8'  => 'available to nobody',
   '9'  => 'public-domain in us', 
   '10' => 'copyright attribute work in manner specified by author',
   '11' => 'copyright cc-by + no derivatives upon distribution',
   '12' => 'copyright cc-by-nd + only non-commercial use only',
   '13' => 'copyright cc-by +  only non-commercial use only',
   '14' => 'copyright cc-by-nc + ccby-sa',
   '15' => 'copyright cc-by + same license upon redistribution',
   '16' => 'in-copyright orphan candidate',
   '17' => 'cc0 no rights reserved license implies pd',
   '18' => 'available to everyone',
   '19' => 'in copyright in the US',
  );

%g_attribute_keys =
  (
   1  => 'pd',
   2  => 'ic',
   3  => 'opb',
   4  => 'orph',
   5  => 'und',
   6  => 'umall',
   7  => 'ic-world',
   8  => 'nobody',
   9  => 'pdus',
   10 => 'cc-by',
   11 => 'cc-by-nd',
   12 => 'cc-by-nc-nd',
   13 => 'cc-by-nc',
   14 => 'cc-by-nc-sa',
   15 => 'cc-by-sa',
   16 => 'orphcand',
   17 => 'cc-zero',
   18 => 'und-world',
   19 => 'ic-us',
  );

%g_source_names = 
  (
   '1'  => 'google',
   '2'  => 'lit-dlps-dc',
   '3'  => 'ump',
   '4'  => 'ia',
   '5'  => 'yale',
   '6'  => 'mdl',
   '7'  => 'mhs',
   '8'  => 'usup',
   '9'  => 'ucm',
   '10' => 'purd',
   '11' => 'getty',
   '12' => 'um-dc-mp',
   '13' => 'uiuc',
  );

@g_stmt_fields = 
  qw(
        stmt_key
        stmt_url
        stmt_url_aux
        stmt_head
        stmt_icon
        stmt_icon_aux
        stmt_text
   );

# Coordinates with table=mdp.access_stmts
%g_stmt_keys =
  (
   'pd'           => {
                      'stmt_icon' => '',
                     },
   'pd-google'    => {
                      'stmt_icon' => '',
                     },
   'pd-us'        => {
                      'stmt_icon' => '',
                     },
   'pd-us-google' => {
                      'stmt_icon' => '',
                     },
   'oa'           => {
                      'stmt_icon' => '',
                     },
   'oa-google'    => {
                      'stmt_icon' => '',
                     },
   'ic-access'    => {
                      'stmt_icon' => '',
                     },
   'ic'           => {
                      'stmt_icon' => '',
                     },
   'cc-by'        => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/by/3.0/us/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/licenses/by/3.0/us/',
                     },
   'cc-by-nd'     => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/by-nd/3.0/us/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/licenses/by-nd/3.0/us/',
                     },
   'cc-by-nc-nd'  => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/by-nc-nd/3.0/us/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/licenses/by-nc-nd/3.0/us/',
                     },
   'cc-by-nc'     => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/by-nc/3.0/us/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/licenses/by-nc/3.0/us/',
                     },
   'cc-by-nc-sa'  => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/by-nc-sa/3.0/us/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/licenses/by-nc-sa/3.0/us/',
                     },
   'cc-by-sa'     => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/by-sa/3.0/us/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/licenses/by-sa/3.0/us/',
                     },
   'cc-zero'      => {
                      'stmt_icon_aux' => 'http://i.creativecommons.org/l/zero/1.0/80x15.png',
                      'stmt_url_aux'  => 'http://creativecommons.org/publicdomain/zero/1.0/',
                     },
   'candidates'   => {
                      'stmt_icon' => '',
                     },
   'orphans'      => {
                      'stmt_icon' => '',
                     },
   'ic-us'        => {
                      'stmt_icon' => '',
                     },
   'ic-us-google' => {
                      'stmt_icon' => '',
                     },
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
           $SSD_USER              => 'allow_ssd_by_holdings',
           $LIBRARY_IPADDR_USER   => 'deny',
           $UM_AFFILIATE          => 'deny',
           $HT_AFFILIATE          => 'deny',
          },
   # OPB out-of-print and brittle (implies in-copyright).
   # ---------------------------------------------------------------
   # 1) As of Feb 2010, UM affiliates can view OPB without being in a
   # library but only one such user is allowed to do so at a
   # time. Exclusivity is enforced and access granted downstream.  
   #
   # 2) Holding is implied @ Wed Aug 10 2011 for allow_by_lib_ipaddr,
   # and allow_by_exclusivity because all OPB in database are held by
   # uom. THIS WILL CHANGE WHEN WE HAVE CONDITION DATA IN Holdings
   # databse FOR OTHER INSTITUTIONS.
   #
   # 3) We now Thu Mar 8 15:49:56 2012 have IP ranges for institutions
   # besides UM (LOC) but they can't see brittle books because we
   # don't have condition data for them in Holdings hence
   # allow_by_lib_ipaddr becomes allow_by_uom_lib_ipaddr
   '3' => { 
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings',
           $LIBRARY_IPADDR_USER   => 'allow_by_uom_lib_ipaddr',
           $UM_AFFILIATE          => 'allow_by_exclusivity',
           $HT_AFFILIATE          => 'deny', 
          },
   # copyright-orphaned (implies in-copyright)
   '4' => { 
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings',
           $LIBRARY_IPADDR_USER   => 'allow_orph_by_holdings_by_agreement',
           $UM_AFFILIATE          => 'allow_orph_by_holdings_by_agreement',
           $HT_AFFILIATE          => 'allow_orph_by_holdings_by_agreement',
          },
   # undetermined copyright status
   '5' => { 
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings',
           $LIBRARY_IPADDR_USER   => 'deny',
           $UM_AFFILIATE          => 'deny',
           $HT_AFFILIATE          => 'deny',
          },
   # available to UM affiliates and UM walk-in patrons (all
   # campuses), these moved to 7 (world) so then are equivalent to 7
   # if a volume appears as 6
   '6' => { 
           $ORDINARY_USER         => 'allow',
           $SSD_USER              => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow',
           $UM_AFFILIATE          => 'allow',
           $HT_AFFILIATE          => 'allow',
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
   # available if IP is US or affiliated with a US partner at any
   # IP address
   '9' => { 
           $ORDINARY_USER         => 'allow_by_us_geo_ipaddr', # US IP only
           $SSD_USER              => 'allow_us_aff_by_ipaddr', # only US affiliate any IP or US IP only 
           $LIBRARY_IPADDR_USER   => 'allow', # US IP by definition, currently
           $UM_AFFILIATE          => 'allow', # US affiliate any IP
           $HT_AFFILIATE          => 'allow_us_aff_by_ipaddr', # only US affiliate any IP or US IP only 
          },
   # available if IP is non-US or affiliated with non-US partner at
   # any IP address
   '19' => { 
            $ORDINARY_USER         => 'allow_by_nonus_geo_ipaddr', # non-US IP only
            $SSD_USER              => 'allow_ssd_by_holdings_by_geo_ipaddr', # US IP + held or non-US IP
            $LIBRARY_IPADDR_USER   => 'deny', # US IP address by definition, currently
            $UM_AFFILIATE          => 'allow_by_nonus_geo_ipaddr', # non-US IP only
            $HT_AFFILIATE          => 'allow_nonus_aff_by_ipaddr', # only non-US affiliate any IP or non-US IP only 
           },
   # available to everyone in the world http://creativecommons.org/licenses/by/3.0/
   '10' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },
   # available to everyone in the world http://creativecommons.org/licenses/by-nd/3.0/
   '11' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },  
   # available to everyone in the world http://creativecommons.org/licenses/by-nc-nd/3.0/
   '12' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },  
   # available to everyone in the world http://creativecommons.org/licenses/by-nc/3.0/
   '13' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },  
   # available to everyone in the world http://creativecommons.org/licenses/by-nc-sa/3.0/
   '14' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },  
   # available to everyone in the world http://creativecommons.org/licenses/by-sa/3.0/
   '15' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },
   # orphan candidate (implied in-copyright)
   '16' => { 
            $ORDINARY_USER         => 'deny',
            $SSD_USER              => 'allow_ssd_by_holdings',
            $LIBRARY_IPADDR_USER   => 'deny',
            $UM_AFFILIATE          => 'deny',
            $HT_AFFILIATE          => 'deny',
           },
   # available to everyone in the world http://creativecommons.org/publicdomain/zero/1.0/
   '17' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },
   # available to everyone in the world
   '18' => { 
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $UM_AFFILIATE          => 'allow',
            $HT_AFFILIATE          => 'allow',
           },
  );

# ---------------------------------------------------------------------
# "Public domain"
# ---------------------------------------------------------------------
#
@g_creative_commons_attribute_values = (10, 11, 12, 13, 14, 15, 17);
@g_public_domain_world_attribute_values = (1, 7, 9, 18, 19);
@g_access_requires_holdings_attribute_values = (2, 3, 4, 5, 6, 16);

$g_available_to_no_one_attribute_value = 8;
$g_public_domain_US_attribute_value = 9;
$g_public_domain_non_US_attribute_value = 19;
$g_orphan_attribute_value = 4;
$g_orphan_candidate_attribute_value = 16;

# ---------------------------------------------------------------------
# Source values authorized for full book PDF download.
# ---------------------------------------------------------------------
#                                          
@g_full_PDF_download_open_source_values = (
                                           2,  # lit-dlps-dc
                                           4,  # ia
                                           5,  # yale
                                           8,  # usup
                                           9,  # ucm
                                           10, # purd
                                           11, # getty
                                           12, # um-dc-mp
                                           13, # uiuc
                                          );
@g_full_PDF_download_closed_source_values = (
                                             1, # google
                                            );

@g_source_values = keys %g_source_names;
@g_rights_attribute_values = keys %g_rights_matrix;

# ---------------------------------------------------------------------
# Geographic IP Information
# ---------------------------------------------------------------------
# Country codes used to determine public domain via the GeoIP database
# for attribute numbers 9, 19
#
@g_pdus_country_codes = 
    (
     'US', # United States
     'UM', # United States Minor Outlying Islands
     'VI', # Virgin Islands, U.S.
    );

1;

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
