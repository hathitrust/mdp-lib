package RightsGlobals;

=head1 SYNOPSIS

 ATTRIBUTES
 id        name        type      dscr
 1         pd          copyright public domain
 2         ic          copyright in-copyright
 3         op          copyright out-of-print (implies in-copyright) @OPB
 4         orph        copyright copyright-orphaned (implies in-copyright)
 5         und         copyright undetermined copyright status
 6         umall       access    available to UM affiliates and walk-in patrons (all campuses)
 7         ic-world    access    in-copyright and available to everyone in the world
 8         nobody      access    available to nobody; blocked for all users
 9         pdus        copyright public domain only when viewed in the US
 18        und-world   access    undetermined copyright status and permitted as world viewable
 19        icus        copyright in copyright in the US

 (Creative Commons)

 id     name            type            dscr
 17     cc-zero         copyright       cc0 license implies pd

 10	cc-by-3.0	copyright	Creative Commons Attribution license, 3.0 Unported
 11	cc-by-nd-3.0	copyright	Creative Commons Attribution-NoDerivatives license, 3.0 Unported
 12	cc-by-nc-nd-3.0	copyright	Creative Commons Attribution-NonCommercial-NoDerivatives license, 3.0 Unported
 13	cc-by-nc-3.0	copyright	Creative Commons Attribution-NonCommercial license, 3.0 Unported
 14	cc-by-nc-sa-3.0	copyright	Creative Commons Attribution-NonCommercial-ShareAlike license, 3.0 Unported
 15	cc-by-sa-3.0	copyright	Creative Commons Attribution-ShareAlike license, 3.0 Unported

 20	cc-by-4.0	copyright	Creative Commons Attribution 4.0 International license
 21	cc-by-nd-4.0	copyright	Creative Commons Attribution-NoDerivatives 4.0 International license
 22	cc-by-nc-nd-4.0	copyright	Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International license
 23	cc-by-nc-4.0	copyright	Creative Commons Attribution-NonCommercial 4.0 International license
 24	cc-by-nc-sa-4.0	copyright	Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International license
 25	cc-by-sa-4.0	copyright	Creative Commons Attribution-ShareAlike 4.0 International license
 26     pd-pvt          access          public domain but access limited due to privacy concerns

 (Orphan works project)

 id        name        type        dscr
 16        orphcand    copyright   orphan candidate - in 90-day holding period (implies in-copyright)

 STATEMENT KEYS

 by-permission
 candidates

 cc-by-3.0
 cc-by-nc-3.0
 cc-by-nc-nd-3.0
 cc-by-nc-sa-3.0
 cc-by-nd-3.0
 cc-by-sa-3.0

 cc-by-4.0
 cc-by-nc-4.0
 cc-by-nc-nd-4.0
 cc-by-nc-sa-4.0
 cc-by-nd-4.0
 cc-by-sa-4.0

 cc-zero

 ic
 ic-access
 ic-us
 ic-us-google
 oa
 oa-google
 orphans
 pd
 pd-google
 pd-us
 pd-us-google

=cut

# For GeoIP address checking we do not want to exclude private network addresses forwarded through routers etc.
#   10.0.0.0        -   10.255.255.255
#   172.16.0.0      -   172.31.255.255
#   192.168.0.0     -   192.168.255.255
#
our $private_network_ranges_regexp = q{^10\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))$|^172\.(1[6-9]|2[0-9]|3[0-1])\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))$|^192\.168\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))$};

# Bad rights_current.{attr,access_profile} value
our $NOOP_ATTRIBUTE = 0;

# ---------------------------------------------------------------------
# Keys are attributes in the Rights Matrix database Attributes table
# Values are authorizations by "user class" keys in the sub-hash:
# 'ordinary'
# 'ssd' (disabled, sight impaired)
# 'in a library building'
# 'UM authenticated'
# ---------------------------------------------------------------------
our $HT_TOTAL_USER       = 1;
our $ORDINARY_USER       = 2;
our $SSD_USER            = 3;
our $SSD_PROXY_USER      = 4;
our $LIBRARY_IPADDR_USER = 5;
our $HT_AFFILIATE        = 7;
our $ENHANCED_TEXT_USER  = 8;
our $EMERGENCY_ACCESS_AFFILIATE = 9;
our $HT_STAFF_USER       = 10;

@g_access_types = ($HT_TOTAL_USER .. $HT_STAFF_USER);

%g_access_type_names =
    (
     $HT_STAFF_USER          => 'ht_staff_user',
     $HT_TOTAL_USER          => 'ht_total_user', 
     $ORDINARY_USER          => 'ordinary_user',
     $SSD_USER               => 'ssd_user',
     $SSD_PROXY_USER         => 'ssd_proxy_user',
     $LIBRARY_IPADDR_USER    => 'in_library_user',
     $HT_AFFILIATE           => 'ht_affiliate',
     $ENHANCED_TEXT_USER     => 'enhanced_text_user',
     $EMERGENCY_ACCESS_AFFILIATE  => 'emergency_access_affiliate',
    );

%g_attribute_names =
  (
   '1'  => 'public-domain',
   '2'  => 'in-copyright',
   '3'  => 'in-copyright out-of-print',
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
   '20' => 'Creative Commons Attribution 4.0 International license',
   '21' => 'Creative Commons Attribution-NoDerivatives 4.0 International license',
   '22' => 'Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International license',
   '23' => 'Creative Commons Attribution-NonCommercial 4.0 International license',
   '24' => 'Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International license',
   '25' => 'Creative Commons Attribution-ShareAlike 4.0 International license',
   '26' => 'public domain but access limited due to privacy concerns',
   '27' => 'suppressed from view',
  );

%g_source_names =
  (
   1  => 'google',
   2  => 'lit-dlps-dc',
   3  => 'ump',
   4  => 'ia',
   5  => 'yale',
   6  => 'mdl',
   7  => 'mhs',
   8  => 'usup',
   9  => 'ucm',
   10 => 'purd',
   11 => 'getty',
   12 => 'um-dc-mp',
   13 => 'uiuc',
   14 => 'brooklynmuseum',
   15 => 'uf',
   16 => 'tamu',
   17 => 'udel',
   18 => 'private',
   19 => 'umich',
   20 => 'clark',
   21 => 'ku',
   22 => 'mcgill',
   23 => 'bc',
   24 => 'nnc',
   25 => 'geu',
   26 => 'borndigital',
   27 => 'yale2',
   28 => 'mou',
   29 => 'chtanc',
   30 => 'bentley-umich',
   31 => 'clements-umich',
   32 => 'wau',
   33 => 'cornell',
   34 => 'cornell-ms',
   35 => 'umd',
   36 => 'frick',
   37 => 'northwestern',
   38 => 'umn',
  );

%g_attribute_keys =
  (
   1  => 'pd',
   2  => 'ic',
   3  => 'op',
   4  => 'orph',
   5  => 'und',
   6  => 'umall',
   7  => 'ic-world',
   8  => 'nobody',
   9  => 'pdus',
   10 => 'cc-by-3.0',
   11 => 'cc-by-nd-3.0',
   12 => 'cc-by-nc-nd-3.0',
   13 => 'cc-by-nc-3.0',
   14 => 'cc-by-nc-sa-3.0',
   15 => 'cc-by-sa-3.0',
   16 => 'orphcand',
   17 => 'cc-zero',
   18 => 'und-world',
   19 => 'icus',
   20 => 'cc-by-4.0',
   21 => 'cc-by-nd-4.0',
   22 => 'cc-by-nc-nd-4.0',
   23 => 'cc-by-nc-4.0',
   24 => 'cc-by-nc-sa-4.0',
   25 => 'cc-by-sa-4.0',
   26 => 'pd-pvt',
   27 => 'supp',
  );

%g_access_profile_names =
  (
   1  => 'open',
   2  => 'google',
   3  => 'page',
   4  => 'page+lowres',
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


 # As of Mon Mar 21 15:51:00 2016 SSD_PROXY_USER has access to any in-copyright
 # materials, regardless of holdings state.
%g_rights_matrix =
  (
   # public domain
   '1' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'allow',
           $SSD_USER              => 'allow',
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow',
           $HT_AFFILIATE          => 'allow',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # in-copyright
   '2' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings',
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'deny',
           $HT_AFFILIATE          => 'deny',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow_emergency_access_by_holdings',
          },
   # OP out-of-print (implies in-copyright). (Was OPB out-of-print, brittle) @OPB
   # ----------------------------------------------------------------------------
   # As of Wed Nov 28 12:52:40 2012 we have HOLDINGS so access
   # exclusivity is granted if on US Soil and held and:
   # ((OP AND BRLM) AND (LIBRARY_IPADDR_USER OR *_AFFILIATE)) OR (OP AND SSD_USER)
   # ... the saga continues ...
   # As of Mon Oct 27 14:20:30 2014 exclusive access is granted if held and:
   # ((OP AND BRLM) AND LIBRARY_IPADDR_USER OR (OP AND SSD_USER))
   '3' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings', # US implied
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow_by_held_BRLM', # US + exclusivity implied
           $HT_AFFILIATE          => 'deny',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow_emergency_access_by_holdings',
          },
   # copyright-orphaned (implies in-copyright)
   '4' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings',
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow_orph_by_holdings_by_agreement',
           $HT_AFFILIATE          => 'allow_orph_by_holdings_by_agreement',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow_emergency_access_by_holdings',
          },
   # undetermined copyright status
   '5' => {
           $HT_STAFF_USER          => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'allow_ssd_by_holdings',
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'deny',
           $HT_AFFILIATE          => 'deny',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow_emergency_access_by_holdings',
          },
   # available to UM affiliates and UM walk-in patrons (all
   # campuses), these moved to 7 (world) so then are equivalent to 7
   # if a volume appears as 6
   '6' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'allow',
           $SSD_USER              => 'allow',
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow',
           $HT_AFFILIATE          => 'allow',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world
   '7' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'allow',
           $SSD_USER              => 'allow',
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow',
           $HT_AFFILIATE          => 'allow',
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to no one in the world
   '8' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'deny',
           $ORDINARY_USER         => 'deny',
           $SSD_USER              => 'deny',
           $SSD_PROXY_USER        => 'deny',
           $LIBRARY_IPADDR_USER   => 'deny',
           $HT_AFFILIATE          => 'deny',
           $ENHANCED_TEXT_USER    => 'deny',
           $EMERGENCY_ACCESS_AFFILIATE => 'deny',
          },
   # available if IP is US or affiliated with a US partner at any
   # IP address
   '9' => {
           $HT_STAFF_USER         => 'allow',
           $HT_TOTAL_USER         => 'allow',
           $ORDINARY_USER         => 'allow_by_us_geo_ipaddr', # US IP only
           $SSD_USER              => 'allow_us_aff_by_ipaddr', # only US affiliate any IP or US IP only
           $SSD_PROXY_USER        => 'allow',
           $LIBRARY_IPADDR_USER   => 'allow', # US IP by definition, currently
           $HT_AFFILIATE          => 'allow_by_us_geo_ipaddr', # US IP only
           $ENHANCED_TEXT_USER    => 'allow',
           $EMERGENCY_ACCESS_AFFILIATE => 'allow_us_aff_by_ipaddr_or_emergency_access_by_holdings',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by/3.0/
   '10' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
           },
   # available to everyone in the world http://creativecommons.org/licenses/by-nd/3.0/
   '11' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
           },
   # available to everyone in the world http://creativecommons.org/licenses/by-nc-nd/3.0/
   '12' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by-nc/3.0/
   '13' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
           },
   # available to everyone in the world http://creativecommons.org/licenses/by-nc-sa/3.0/
   '14' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by-sa/3.0/
   '15' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
           },
   # orphan candidate (implied in-copyright)
   '16' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'deny',
            $SSD_USER              => 'allow_ssd_by_holdings',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'deny',
            $HT_AFFILIATE          => 'deny',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow_emergency_access_by_holdings',
         },
   # available to everyone in the world http://creativecommons.org/publicdomain/zero/1.0/
   '17' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world
   '18' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
           },
   # available if IP is non-US or affiliated with non-US partner at
   # any IP address
   '19' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow_by_nonus_geo_ipaddr', # non-US IP only
            $SSD_USER              => 'allow_ssd_by_holdings_by_geo_ipaddr', # US IP + held or non-US IP
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'deny', # US IP address by definition, currently
            $HT_AFFILIATE          => 'allow_nonus_aff_by_ipaddr', # only non-US affiliate any IP or non-US IP only
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow_emergency_access_by_holdings_by_geo_ipaddr',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by/4.0/
   '20' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
           },
   # available to everyone in the world http://creativecommons.org/licenses/by-nd/4.0/
   '21' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by-nc-nd/4.0/
   '22' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by-nc/4.0/
   '23' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by-nc-sa/4.0/
   '24' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # available to everyone in the world http://creativecommons.org/licenses/by-sa/4.0/
   '25' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'allow',
            $ORDINARY_USER         => 'allow',
            $SSD_USER              => 'allow',
            $SSD_PROXY_USER        => 'allow',
            $LIBRARY_IPADDR_USER   => 'allow',
            $HT_AFFILIATE          => 'allow',
            $ENHANCED_TEXT_USER    => 'allow',
            $EMERGENCY_ACCESS_AFFILIATE => 'allow',
          },
   # not available to view but searchable, more restrictive than ic(2) but less than nobody(8)
   '26' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'deny',
            $ORDINARY_USER         => 'deny',
            $SSD_USER              => 'deny',
            $SSD_PROXY_USER        => 'deny',
            $LIBRARY_IPADDR_USER   => 'deny',
            $HT_AFFILIATE          => 'deny',
            $ENHANCED_TEXT_USER    => 'deny',
            $EMERGENCY_ACCESS_AFFILIATE => 'deny',
          },
   # not available to view, not searchable, more restrictive than nobody(8)
   '27' => {
            $HT_STAFF_USER         => 'allow',
            $HT_TOTAL_USER         => 'deny',
            $ORDINARY_USER         => 'deny',
            $SSD_USER              => 'deny',
            $SSD_PROXY_USER        => 'deny',
            $LIBRARY_IPADDR_USER   => 'deny',
            $HT_AFFILIATE          => 'deny',
            $ENHANCED_TEXT_USER    => 'deny',
            $EMERGENCY_ACCESS_AFFILIATE => 'deny',
          },
  );

# ---------------------------------------------------------------------
# Attribute sets
# ---------------------------------------------------------------------
#
@g_creative_commons_attribute_values = (10, 11, 12, 13, 14, 15, 17, 20, 21, 22, 23, 24, 25); # All users
@g_public_domain_world_attribute_values = (1, 7, 9, 18, 19); # All users
@g_access_requires_holdings_attribute_values = (2, 3, 4, 5, 6, 16); # SSD only, if institution holds

$g_access_requires_brittle_holdings_attribute_value = 3; # Some users, if institution holds
$g_available_to_no_one_attribute_value = 8;
$g_public_domain_US_attribute_value = 9;
$g_public_domain_non_US_attribute_value = 19;
$g_orphan_attribute_value = 4;
$g_orphan_candidate_attribute_value = 16;
$g_suppressed_attribute_value = 27;

# ------------------------------------------------------------------------
# rights_current.access_profile values that allow full book PDF download.
# ------------------------------------------------------------------------
#
@g_full_PDF_download_open_access_profile_values    = (
                                                      1,  # open
                                                     );
@g_full_PDF_download_limited_access_profile_values = (
                                                      2, # google
                                                     );

@g_rights_attribute_values = keys %g_rights_matrix;
@g_rights_access_profile_values = keys %g_access_profile_names;

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
     'PR', # Puerto Rico
     'MH', # Marshall Islands,
     'GU', # Guam
     'MP', # Northern Mariana Islands
     # 'AS', # America Samoa - not as of 2015-10-22
    );

%g_pdus_country_codes_hash = map { $_ => 1 } @g_pdus_country_codes;
%g_attributes = map { $g_attribute_keys{$_} => $_ } keys %g_attribute_keys;
%g_sources = map { $g_source_names{$_} => $_ } keys %g_source_names;
%g_access_profiles = map { $g_access_profile_names{$_} => $_ } keys %g_access_profile_names;

1;

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-15 ©, The Regents of The University of Michigan, All Rights Reserved

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
