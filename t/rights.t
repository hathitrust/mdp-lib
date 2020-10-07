#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/lib";

use Access::Rights;
use Auth::Auth;
use Context;
use Database;
use Utils;

my $C = new Context;
my $cgi = new CGI;
$C->set_object('CGI', $cgi);
my $config = new MdpConfig(File::Spec->catdir($ENV{SDRROOT}, 'mdp-lib/Config/uber.conf'),
                           File::Spec->catdir($ENV{SDRROOT}, 'slip-lib/Config/common.conf'));
$C->set_object('MdpConfig', $config);
my $db_user = $ENV{'MARIADB_USER'};
my $db = new Database($db_user);
$C->set_object('Database', $db);
my $auth = new Auth::Auth($C);
$C->set_object('Auth', $auth);

# pd/bib volume in sql/002_ht_rights_current.sql fixture
my $ar = Access::Rights->new($C, 'test.pd_open');
my $resp = $ar->check_final_access_status($C, 'test.pd_open');
is($resp, 'allow');

# pdus/bib volume in sql/002_ht_rights_current.sql fixture
$ar = Access::Rights->new($C, 'test.pdus_open');
$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'US';
$resp = $ar->check_final_access_status($C, 'test.pdus_open');
is($resp, 'allow');

$ar = Access::Rights->new($C, 'test.pdus_open');
$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'GB';
$resp = $ar->check_final_access_status($C, 'test.pdus_open');
is($resp, 'deny');

done_testing();

