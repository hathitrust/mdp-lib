package MdpUsers;

# Copyright 2010 The Regents of The University of Michigan, All Rights Reserved
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

# Mon Feb 13 2012 Superusers are restricted to these ranges
# 141.211.43.128/25   141.211.43.129  - 141.211.43.254  - LIT offices 
# 141.211.84.128/25   141.211.84.129  - 141.211.84.254  - Library VPN 
# 141.211.168.128/25  141.211.168.129 - 141.211.168.254 - Hatcher server room 
# 141.211.172.0/22    141.211.172.1   - 141.211.172.254 - Hatcher/Shapiro buildings 
# 141.213.128.128/25  141.213.128.129 - 141.213.128.254 - MACC data center 
# 141.213.232.192/26  141.213.232.193 - 141.213.232.254 - MACC data center (this will  be retired sometime in 2012)
#                     141.211.174.173 - 141.211.174.199 - ULIC Shapiro 4th floor

$gSuperuserSubnetRangesRef =
  [
   q{^141\.211\.43\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4]))$},
   q{^141\.211\.84\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4]))$},
   q{^141\.211\.168\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4]))$},
   q{^141\.211\.(1(7[2-5]))\.([1-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-4]))$},
   q{^141\.213\.128\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4]))$},
   q{^141\.213\.232\.(1(9[3-9])|2([0-4][0-9]|5[0-4]))$},
   q{^141\.211\.174\.(1(7[3-9]|[8-9][0-9]))$},
  ];

# Staff, students are restricted to internal subnets. Friend-accounts
# are locked to an exact IP address that should be hardcoded for the
# 'iprestrict' key.
# Mon Apr 23 10:58:29 2012: Updated subset to match superuser defns above
$gStaffSubnetRangesRef =
  [
   q{^141\.211\.(1(7[2-5]))\.([1-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-4]))$}, # Hatcher/Shapiro/CRMS
   q{^141\.211\.43\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4]))$}, # LIT 3rd floor Hatcher
  ];

# ULIC 141.211.174.173 - 141.211.174.199
$gULIC_SubnetRangesRef = [
                          q{^141\.211\.174\.(1(7[3-9]|[8-9][0-9]))$},
                         ];
$gCRMS_WorkshopExpireDate = '2012-05-04 23:59:59';


# Superuser access expires on date:
$gSuperuserExpireDate = '2012-12-31 23:59:59';
# Staff, student,friend access expires on date:
$gStaffExpireDate = '2012-12-31 23:59:59';
# CRMS users
$gCRMS_ExpireDate = '2012-12-01 23:59:59';

# Send warnings of inpending expiration to supervisors this many days
# from the end
@gAccessExpireWarningDays = (30, 15);

# New users should be configured with the same inception date as all
# the other staff of the given supervisor.
#
# WARNING: keys to this hash must be lower-case to work vs. ACL.pm
#
# NOTE: usertypes are 'staff' (UM), 'student' (UM), 'external' (non-UM)
#       roles are (currently) 'superuser', 'generalhathi', 'crms', 'orphan', 'digitization', 'quality', 'cataloging'
%gAccessControlList =
  (
   # Shibboleth development e.g. persistent-id=...
   'https://shibboleth.umich.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!vam0hwjoiebxqgt6dfxh65zxsok=' 
   =>
   {
    'displayname' => 'Farber, Phillip Shibboleth development',
    'supervisor'  => 'pfarber',
    'expires'     => $gSuperuserExpireDate,
    'usertype'    => 'staff',
    'role'        => 'superuser',
    'iprestrict'  => [
                      '^141\.211\.43\.195$',
                     ],
   },

   # HathiTrust staff
   'azaytsev'
   => {
       'displayname' => 'Zaytsev, Angelina',
       'supervisor'  => 'jjyork',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'generalhathi',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },

   # Michigan cataloging
   'ekflanag'
   => {
       'displayname' => 'Campbell, Emily',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'cataloging',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'amuro'
   => {
       'displayname' => 'Knott, Martin ',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'cataloging',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'cmcguire'
   => {
       'displayname' => 'McGuire, Connie',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'cataloging',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'emustard'
   => {
       'displayname' => 'Mustard, Liz',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'cataloging',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'ellenkw'
   => {
       'displayname' => 'Wilson, Ellen',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'cataloging',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   
   # === CRMS - see Bobby Glushko <rglushko@umich.edu> ===

   # CRMS World, assorted institutions   
   'keden'
   => {
       'displayname' => 'Eden, Kristina',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^141\.211\.173\.213$',
                        ],
      },
   'morikaw1@illinois.edu'
   => {
       'displayname' => 'Morikawa, Hiromi',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^130\.126\.36\.73$',
                         '^192\.17\.251\.93$',
                        ],
      },
   'ariggio@library.ucla.edu'
   => {
       'displayname' => 'Riggio, Angela',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^164\.67\.17\.137$',
                        ],
      },
   'a-gibbs@northwestern.edu'
   => {
       'displayname' => 'DuncanGibbs, Ann',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.105\.29\.27$',
                        ],
      },
   'betsyk@illinois.edu'
   => {
       'displayname' => 'Kruger, Betsy',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^130\.126\.36\.71$',
                        ],
      },
   'hughes@uci.edu'
   => {
       'displayname' => 'Hughes, Carol',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.195\.145\.101$',
                        ],
      },
   'holobar@psu.edu'
   => {
       'displayname' => 'Holobar, Chris',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.118\.90\.188$',
                        ],
      },
   'ccase2@jhu.edu'
   => {
       'displayname' => 'Case, Christopher',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.220\.8\.213$',
                        ],
      },
   'd-zellner@northwestern.edu'
   => {
       'displayname' => 'Zellner, Dan',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.105\.184\.28$',
                        ],
      },
   'david.macfarland@ucsf.edu'
   => {
       'displayname' => 'MacFarland, David',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.218\.15\.136$',
                        ],
      },
   'denyse_rodgers@baylor.edu'
   => {
       'displayname' => 'Rodgers, Denyse',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.62\.35\.254$',
                        ],
      },
   'gem10@psu.edu'
   => {
       'displayname' => 'Brooks, Grace',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.118\.90\.48$',
                        ],
      },
   'jblock@princeton.edu'
   => {
       'displayname' => 'Block, Jennifer',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.112\.200\.247$',
                        ],
      },
   'j-young2@northwestern.edu'
   => {
       'displayname' => 'Young, Jennifer',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.105\.203\.57$',
                        ],
      },
   'judy.bailey@duke.edu'
   => {
       'displayname' => 'Bailey, Judy',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^152\.3\.116\.242$',
                        ],
      },
   'katiebrown@northwestern.edu'
   => {
       'displayname' => 'Brown, Katie',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.105\.29\.57$',
                        ],
      },
   'kdesous2@jhu.edu'
   => {
       'displayname' => 'DeSousa, Katie',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.220\.8\.217$',
                        ],
      },
   'martinjbrennan@library.ucla.edu'
   => {
       'displayname' => 'Brennan, Martin',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^164\.67\.19\.44$',
                        ],
      },
   'sarah.mcbride@dartmouth.edu'
   => {
       'displayname' => 'McBride, Sarah',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.170\.88\.49$',
                        ],
      },
   's-morrison@northwestern.edu'
   => {
       'displayname' => 'Morrison, Shelley',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.105\.29\.26$',
                        ],
      },
   'towen@umd.edu'
   => {
       'displayname' => 'Owen, Terry',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.2\.18\.73$',
                        ],
      },
   'winston.atkins@duke.edu'
   => {
       'displayname' => 'Atkins, Winston',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^152\.3\.116\.104$',
                        ],
      },
   'zl2114@columbia.edu'
   => {
       'displayname' => 'Lane, Zack',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.59\.154\.21$',
                        ],
      },
   'curtis.lavery@ucop.edu'
   => {
       'displayname' => 'Lavery, Curtis',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.48\.39\.98$',
                        ],
      },
   'virginia.sinclair@ucop.edu'
   => {
       'displayname' => 'Sinclair, Virginia',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.48\.204\.180$',
                        ],
      },
   'nancy.scott-noennig@ucop.edu'
   => {
       'displayname' => 'ScottNoennig, Nancy',
       'supervisor'  => 'glusko',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.48\.39\.107$',
                        ],
      },
   
   # Michigan CRMS   
   'mslevine'
   => {
       'displayname' => 'Levine, Melissa',
       'supervisor'  => 'mslevine',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'rglushko'
   => {
       'displayname' => 'Glushko, Bobby',
       'supervisor'  => 'mslevine',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'rcadler'
   => {
       'displayname' => 'Adler, Rich',
       'supervisor'  => 'mslevine',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'jaheim'
   => {
       'displayname' => 'Ahronheim, Judith R',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'gnichols'
   => {
       'displayname' => 'Nichols, Gregory C ',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'cwilcox'
   => {
       'displayname' => 'Wilcox, Christine R',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'dmcw'
   => {
       'displayname' => 'McWhinnie, Dennis A ',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'hnhampt'
   => {
       'displayname' => 'Hampton, Heather',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },

   # Columbia CRMS
   'zl2114@columbia.edu'
   => {
       'displayname' => 'Lane, Zack',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.59\.154\.122$',
                         '^128\.59\.154\.21$',
                        ],
      },

   # Minnesota CRMS
   'dewey002@umn.edu'
   => {
       'displayname' => 'Urban, Carla Dewey',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^160\.94\.15\.154$',
                         '^160\.94\.15\.188$',
                         '^160\.94\.20\.253$',
                        ],
      },
   's-zuri@umn.edu'
   => {
       'displayname' => 'Zuriff, Sue',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^160\.94\.224\.166$',
                        ],
      },

   # Wisconsin CRMS
   'krattunde@library.wisc.edu'
   => {
       'displayname' => 'Rattunde, Karen',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.104\.61\.15$',
                        ],
      },
   'lnachreiner@library.wisc.edu'
   => {
       'displayname' => 'Nachreiner, Lisa',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.104\.61\.101$',
                        ],
      },
   'rroemer@library.wisc.edu'
   => {
       'displayname' => 'Roemer, Rita',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.104\.61\.41$',
                        ],
      },
   'aseeger@library.wisc.edu'
   => {
       'displayname' => 'Seeger, Al',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^128\.104\.61\.100$',
                        ],
      },

   # Indiana CRMS
   'eringree@indiana.edu'
   => {
       'displayname' => 'Green, Erin',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.79\.35\.87$',
                        ],
      },
   'marlett@indiana.edu'
   => {
       'displayname' => 'Marlett, Kathy',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.79\.35\.84$',
                        ],
      },
   'shmichae@indiana.edu'
   => {
       'displayname' => 'Michaels, Sherri',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.79\.35\.85$',
                         '^129\.79\.35\.89$',
                        ],
      },
   'jmcclamr@indiana.edu'
   => {
       'displayname' => 'McClamroch, Jo',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.79\.35\.88$',
                        ],
      },
   'jamblack@indiana.edu'
   => {
       'displayname' => 'Black, Janet',
       'supervisor'  => 'jaheim',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.79\.35\.86$',
                        ],
      },

   # Orphan works review - see Melissa Levine <mslevine@umich.edu>
   'bentobey'
   => {
       'displayname' => 'Tobey, Benjamin',
       'supervisor'  => 'mslevine',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^141\.211\.173\.203$',
                         '^141\.211\.173\.204$',
                         '^141\.211\.173\.205$',
                         '^141\.211\.173\.212$',
                         '^141\.211\.173\.138$',
                        ],
      },
   'adamsn'
   => {
       'displayname' => 'Adams, Neena',
       'supervisor'  => 'mslevine',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^141\.211\.173\.203$',
                         '^141\.211\.173\.204$',
                         '^141\.211\.173\.205$',
                         '^141\.211\.173\.212$',
                         '^141\.211\.173\.138$',
                        ],
      },
   'bryanbir'
   => {
       'displayname' => 'Birchmeier, Bryan',
       'supervisor'  => 'mslevine',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^141\.211\.173\.203$',
                         '^141\.211\.173\.204$',
                         '^141\.211\.173\.205$',
                         '^141\.211\.173\.212$',
                         '^141\.211\.173\.138$',
                        ],
      },
   'monicats'
   => {
       'displayname' => 'Tsuneishi, Monica',
       'supervisor'  => 'mslevine',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^141\.211\.173\.203$',
                         '^141\.211\.173\.204$',
                         '^141\.211\.173\.205$',
                         '^141\.211\.173\.212$',
                         '^141\.211\.173\.138$',
                        ],
      },
   'kujalak'
   => {
       'displayname' => 'Kujala, Katie',
       'supervisor'  => 'mslevine',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^141\.211\.173\.203$',
                         '^141\.211\.173\.204$',
                         '^141\.211\.173\.205$',
                         '^141\.211\.173\.212$',
                         '^141\.211\.173\.138$',
                        ],
      },

   # Quality Review Access - see
   # https://wush.net/jira/hathitrust/browse/HTS-5432
   # https://wush.net/jira/hathitrust/browse/HTS-9592 Note because
   # email addresses are lower-cased for comparison we also lower-case
   # shib IDs.
   'bronick'
   => {
       'displayname' => 'Bronicki, Jackie',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'quality',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'https://idp.princeton.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!hsqca1zjiq0b2eda6ucqsl5f2pc='
   => {
       'displayname' => 'Wange-Connelly, Marie',
       'supervisor'  => 'jjyork',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'external',
       'role'        => 'quality',
       'iprestrict'  => [
                         '^128\.112\.201\.208$',
                        ],
      },
   'https://idp.princeton.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!/stdct3tahkrxptxv4cgvhbfnok'
   => {
       'displayname' => 'Kaytus, Patricia',
       'supervisor'  => 'jjyork',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'external',
       'role'        => 'quality',
       'iprestrict'  => [
                         '^128\.112\.177\.64$',
                        ],
      },
   'https://idp.princeton.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!to3uuan+njxe9luurm+ys4nzvbg='
   => {
       'displayname' => 'Stroop, Jon',
       'supervisor'  => 'jjyork',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'external',
       'role'        => 'quality',
       'iprestrict'  => [
                         '^173\.61\.191\.73$',
                        ],
      },
   'https://auth.yale.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!cqblrdcxsaov0z5lnvw+lwq54lg='
   => {
       'displayname' => 'Klingenberger, Robert',
       'supervisor'  => 'jjyork',
       'expires'     => '2012-11-30 23:59:59',
       'usertype'    => 'external',
       'role'        => 'quality',
       'iprestrict'  => [
                         '^130\.132\.179\.11$',
                        ],
      },
   'https://auth.yale.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!kbr5pq0qoupxfoqso5vo1loztsa='
   => {
       'displayname' => 'Kennedy, Tara',
       'supervisor'  => 'jjyork',
       'expires'     => '2012-11-30 23:59:59',
       'usertype'    => 'external',
       'role'        => 'quality',
       'iprestrict'  => [
                         '^130\.132\.80\.222$',
                        ],
      },

   # UCLA Team orphan - see Melissa Levine <mslevine@umich.edu>
   'urn:mace:incommon:ucla.edu!http://www.hathitrust.org/shibboleth-sp!6y58l1vyoiieqblvz2obkjunnja='
   => {
       'displayname' => 'Riggio, Angela',
       'supervisor'  => 'mslevine',
       'expires'     => '2012-01-31 23:59:59',
       'usertype'    => 'external',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^164\.67\.19\.54$',
                        ],
      },
   'urn:mace:incommon:ucla.edu!http://www.hathitrust.org/shibboleth-sp!2imw9uc3xmq1emhijfybkpup7ea='
   => {
       'displayname' => 'Gurman, Diane',
       'supervisor'  => 'mslevine',
       'expires'     => '2012-01-31 23:59:59',
       'usertype'    => 'external',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^164\.67\.19\.50$',
                        ],
      },
   'urn:mace:incommon:ucla.edu!http://www.hathitrust.org/shibboleth-sp!oe10hzwiuqbr5f+j+3bxfxl2otk='
   => {
       'displayname' => 'Brennan, Martin J.',
       'supervisor'  => 'mslevine',
       'expires'     => '2012-01-31 23:59:59',
       'usertype'    => 'external',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^164\.67\.19\.49$',
                        ],
      },
   'urn:mace:incommon:ucla.edu!http://www.hathitrust.org/shibboleth-sp!itreozgpcvtgbuhyienp9g+bc/c='
   => {
       'displayname' => 'McMichael, Leslie',
       'supervisor'  => 'mslevine',
       'expires'     => '2012-01-31 23:59:59',
       'usertype'    => 'external',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^164\.67\.17\.18$',
                        ],
      },
   'urn:mace:incommon:ucla.edu!http://www.hathitrust.org/shibboleth-sp!qignq2cds/bk7+p7ma/m7y3fdua='
   => {
       'displayname' => 'Farb, Sharon',
       'supervisor'  => 'mslevine',
       'expires'     => '2012-01-31 23:59:59',
       'usertype'    => 'external',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^164\.67\.17\.19$',
                        ],
      },

   # Digitization - see Kat Hagedorn <khage@umich.edu>
   'lwentzel'
   => {
       'displayname' => 'Wentzel, Lawrence R',
       'supervisor'  => 'pfarber',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'digitization',
       'iprestrict'  => [
                         '^141\.211\.84\.36$',
                        ],
      },
   'ldunger'
   => {
       'displayname' => 'Unger, Lara D',
       'supervisor'  => 'pfarber',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'digitization',
       'iprestrict'  => [
                         '^141\.211\.84\.27$',
                        ],
      },

   # Superusers - see Phillip Farber <pfarber@umich.edu>
   'tburtonw'
   => {
       'displayname' => 'Burton-West, Tom',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'suzchap'
   => {
       'displayname' => 'Chapman, Suzanne',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'pfarber'
   => {
       'displayname' => 'Farber, Phillip',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'roger'
   => {
       'displayname' => 'Espinosa, Roger',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'pulintz'
   => {
       'displayname' => 'Ulintz, Peter',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'khage'
   => {
       'displayname' => 'Hagedorn, Kat',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'moseshll'
   => {
       'displayname' => 'Hall, Brian',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'skorner'
   => {
       'displayname' => 'Korner, Sebastien',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'sooty'
   => {
       'displayname' => 'Powell, Chris',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'timothy'
   => {
       'displayname' => 'Prettyman, Tim',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'csnavely'
   => {
       'displayname' => 'Snavely, Cory',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'jweise'
   => {
       'displayname' => 'Weise, John',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'jpwilkin'
   => {
       'displayname' => 'Wilkin, John',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'jjyork'
   => {
       'displayname' => 'York, Jeremy',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'aelkiss'
   => {
       'displayname' => 'Elkiss, Aaron',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'rrotter'
   => {
       'displayname' => 'Rotter, Ryan',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'trmooney'
   => {
       'displayname' => 'Mooney, Thomas',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'ezbrooks'
   => {
       'displayname' => 'Brooks, Ezra',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'nasirg'
   => {
       'displayname' => 'Grewal, Nasir',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
   'meldett'
   => {
       'displayname' => 'Dettloff, Melissa',
       'supervisor'  => 'pfarber',
       'expires'     => $gSuperuserExpireDate,
       'usertype'    => 'staff',
       'role'        => 'superuser',
       'iprestrict'  => $gSuperuserSubnetRangesRef,
      },
  );

1;
