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

# Superusers are not restricted by subnet
$gSuperuserSubnetRangesRef =
  [
   q{.*},
  ];

# Staff, students are restricted to internal subnets. Friend-accounts
# are locked to an exact IP address that should be hardcoded for the
# 'iprestrict' key.
$gStaffSubnetRangesRef =
  [
   q{^141\.211\.(1(7[2-5]))\.([0-9]|[1-9][0-9]|1([0-9][0-9])|2([0-4][0-9]|5[0-5]))$}, # Hatcher/Shapiro/CRMS
   q{^141\.211\.43\.(1(2[8-9]|[3-9][0-9])|2([0-4][0-9]|5[0-5]))$}, # LIT 3rd floor Hatcher
  ];

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
# NOTE: usertypes are 'staff' (UM), 'external' (non-UM)
#       roles are (currently) 'superuser', 'misc', 'crms', 'orphan', 'digitization', 'partneraccess'
%gAccessControlList =
  (
   # Shibboleth development e.g. persistent-id=...
   'https://shibboleth.umich.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!vam0HwjoIEbxQgt6dfXh65ZXSOk=' =>
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

   # Michigan miscellaneous
   'bronick'
   => {
       'displayname' => 'Bronicki, Jackie',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'rglushko'
   => {
       'displayname' => 'Glushko, Bobby',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'mslevine'
   => {
       'displayname' => 'Levine, Melissa',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'bentobey'
   => {
       'displayname' => 'Tobey, Benjamin',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'melamber'
   => {
       'displayname' => 'Whitehead, Melvin',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'chisli'
   => {
       'displayname' => 'Li, Chisheng',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'lhardman'
   => {
       'displayname' => 'lhardman',
       'supervisor'  => 'jpwilkin',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'azaytsev'
   => {
       'displayname' => 'Zaytsev, Angelina',
       'supervisor'  => 'jjyork',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'ekflanag'
   => {
       'displayname' => 'Campbell, Emily',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'amuro'
   => {
       'displayname' => 'Knott, Martin ',
       'supervisor'  => 'amuro',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'cmcguire'
   => {
       'displayname' => 'McGuire, Connie',
       'supervisor'  => 'amuro',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'emustard'
   => {
       'displayname' => 'Mustard, Liz',
       'supervisor'  => 'jaheim',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'ellenkw'
   => {
       'displayname' => 'Wilson, Ellen',
       'supervisor'  => 'layers',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'misc',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },

   # Michigan CRMS - see Bobby Glushko 
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
       'supervisor'  => 'pfarber',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'crms',
       'iprestrict'  => $gStaffSubnetRangesRef,
      },
   'dfulmer'
   => {
       'displayname' => 'Fulmer, David',
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


   # Columbia CRMS
   'zl2114@columbia.edu'
   => {
       'displayname' => 'Lane, Zack',
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
       'expires'     => $gCRMS_ExpireDate,
       'usertype'    => 'external',
       'role'        => 'crms',
       'iprestrict'  => [
                         '^129\.79\.35\.86$',
                        ],
      },
      
   # Orphan works review
   'adamsn'
   => {
       'displayname' => 'Adams, Neena',
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
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
       'supervisor'  => 'pfarber',
       'expires'     => $gStaffExpireDate,
       'usertype'    => 'staff',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^141\.211\.173\.203$',
                         '^141\.211\.173\.204$',
                         '^141\.211\.173\.205$',
                         '^141\.211\.172\.138$',
                         '^141\.211\.173\.212$',
                         '^141\.211\.173\.138$',
                        ],
      },
      
   # Quality Review Access - see https://wush.net/jira/hathitrust/browse/HTS-5432
   'https://auth.yale.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!cqblrdcxsaov0z5lnvw+lwq54lg='
   => {
       'displayname' => 'Klingenberger, Robert',
       'supervisor'  => 'jjyork',
       'expires'     => '2012-04-30 23:59:59',
       'usertype'    => 'external',
       'role'        => 'partneraccess',
       'iprestrict'  => [
                         '^130\.132\.179\.11$',
                        ],
      },

   'https://auth.yale.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!kbr5pq0qoupxfoqso5vo1loztsa='
   => {
       'displayname' => 'Kennedy, Tara',
       'supervisor'  => 'jjyork',
       'expires'     => '2012-04-30 23:59:59',
       'usertype'    => 'external',
       'role'        => 'partneraccess',
       'iprestrict'  => [
                         '^130\.132\.80\.222$',
                        ],
      },
      
   # UCLA Team orphan - see Julia Lovett <jalovett@umich.edu>
   'urn:mace:incommon:ucla.edu!http://www.hathitrust.org/shibboleth-sp!6y58l1vyoiieqblvz2obkjunnja='
   => {
       'displayname' => 'Riggio, Angela',
       'supervisor'  => 'jalovett',
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
       'supervisor'  => 'jalovett',
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
       'supervisor'  => 'jalovett',
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
       'supervisor'  => 'jalovett',
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
       'supervisor'  => 'jalovett',
       'expires'     => '2012-01-31 23:59:59',
       'usertype'    => 'external',
       'role'        => 'orphan',
       'iprestrict'  => [
                         '^164\.67\.17\.19$',
                        ],
      },

   # Digitization
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

   # Superusers
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
   'jalovett'
   => {
       'displayname' => 'Lovett, Julia',
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
  );

1;
