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
$gSuperuserExpireDate = '2011-12-31 23:59:59';
# Staff, student,friend access expires on date:
$gStaffExpireDate = '2011-12-31 23:59:59';

# Send warnings of inpending expiration to supervisors this many days
# from the end
@gAccessExpireWarningDays = (30, 15);

# New users should be configured with the same inception date as all
# the other staff of the given supervisor.
%gAccessControlList =
    (
     # Shibboleth development e.g. persistent-id=...
     'https://shibboleth.umich.edu/idp/shibboleth!http://www.hathitrust.org/shibboleth-sp!vam0HwjoIEbxQgt6dfXh65ZXSOk=' =>
     {
      'displayname' => 'Farber, Phillip Shibboleth development',
      'supervisor'  => 'pfarber',
      'expires'     => $gSuperuserExpireDate,
      'usertype'    => 'superuser',
      'iprestrict'  => [
                        '^141\.211\.43\.195$',
                       ],
     },

     # One time
     'a2greg@gmail.com' => {
                    'displayname' => 'Greg',
                    'supervisor'  => 'pfarber',
                    'expires'     => '2010-06-08 23:59:59',
                    'usertype'    => 'onetime',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },

     # Michigan CRMS - Anne Karle-Zenith
     'jaheim' =>   {
                    'displayname' => 'Ahronheim, Judith R',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'gnichols' => {
                    'displayname' => 'Nichols, Gregory C ',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'cwilcox' =>  {
                    'displayname' => 'Wilcox, Christine R',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'dfulmer' =>  {
                    'displayname' => 'Fulmer, David',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'sgueva' =>   {
                    'displayname' => 'Guevara, Senovia',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'dmcw' =>     {
                    'displayname' => 'McWhinnie, Dennis A ',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },

     # Other Staff
     'ekflanag' => {
                    'displayname' => 'Campbell, Emily',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'amuro' =>    {
                    'displayname' => 'Knott, Martin ',
                    'supervisor'  => 'amuro',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'cmcguire' => {
                    'displayname' => 'McGuire, Connie',
                    'supervisor'  => 'amuro',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'emustard' => {
                    'displayname' => 'Mustard, Liz',
                    'supervisor'  => 'jaheim',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },
     'ellenkw' =>  {
                    'displayname' => 'Wilson, Ellen',
                    'supervisor'  => 'layers',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => $gStaffSubnetRangesRef,
                   },

     # Indiana CRMS
     'shmichae@indiana.edu' => {
                    'displayname' => 'Michaels, Sherri',
                    'supervisor'  => 'pfarber',
                    'expires'     => '2011-05-25 23:59:59',
                    'usertype'    => 'onetime',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                               },
 
     'jmcclamr@indiana.edu' => {
                    'displayname' => 'McClamroch, Jo',
                    'supervisor'  => 'pfarber',
                    'expires'     => '2011-05-25 23:59:59',
                    'usertype'    => 'onetime',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                               },
     'jamblack@indiana.edu' => {
                    'displayname' => 'Black, Janet',
                    'supervisor'  => 'pfarber',
                    'expires'     => '2011-05-25 23:59:59',
                    'usertype'    => 'onetime',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                               },
     'hansone@indiana.edu' => {
                    'displayname' => 'Hanson, Elizabeth',
                    'supervisor'  => 'pfarber',
                    'expires'     => '2011-05-25 23:59:59',
                    'usertype'    => 'onetime',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                              },
     'cameron3@indiana.edu' => {
                    'displayname' => 'Cameron, Lisa',
                    'supervisor'  => 'pfarber',
                    'expires'     => '2011-05-25 23:59:59',
                    'usertype'    => 'onetime',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                               },

     # Digitization
     'lwentzel' => {
                    'displayname' => 'Wentzel, Lawrence R',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => [
                                      '^141\.211\.84\.36$',
                                     ],
                   },
     'ldunger' =>  {
                    'displayname' => 'Unger, Lara D',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gStaffExpireDate,
                    'usertype'    => 'staff',
                    'iprestrict'  => [
                                      '^141\.211\.84\.100$',
                                     ],
                   },

     # Superusers
     'tburtonw' => {
                    'displayname' => 'Burton-West, Tom',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'suzchap' =>  {
                    'displayname' => 'Chapman, Suzanne',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'pfarber' =>  {
                    'displayname' => 'Farber, Phillip',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'roger' =>    {
                    'displayname' => 'Espinoza, Roger',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'pulintz' =>  {
                    'displayname' => 'Ulintz, Peter',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'khage' =>    {
                    'displayname' => 'Hagedorn, Kat',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'moseshll' => {
                    'displayname' => 'Hall, Brian',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'annekz' =>   {
                    'displayname' => 'Karle-Zenith, Anne',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'annekz@puddlemedia.com' =>   {
                    'displayname' => 'Karle-Zenith, Anne - friend',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'skorner' =>  {
                    'displayname' => 'Korner, Sebastien',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'jalovett' => {
                    'displayname' => 'Lovett, Julia',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'sooty' =>    {
                    'displayname' => 'Powell, Chris',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'timothy' =>  {
                    'displayname' => 'Prettyman, Tim',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'csnavely' => {
                    'displayname' => 'Snavely, Cory',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'jweise' =>   {
                    'displayname' => 'Weise, John',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'jpwilkin' => {
                    'displayname' => 'Wilkin, John',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
     'jjyork' =>   {
                    'displayname' => 'York, Jeremy',
                    'supervisor'  => 'pfarber',
                    'expires'     => $gSuperuserExpireDate,
                    'usertype'    => 'superuser',
                    'iprestrict'  => $gSuperuserSubnetRangesRef,
                   },
    );


1;
