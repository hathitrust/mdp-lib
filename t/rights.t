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

local %ENV = %ENV;
$ENV{HTTP_HOST} = q{babel.hathitrust.org};
$ENV{SERVER_ADDR} = q{141.213.128.185};
$ENV{SERVER_PORT} = q{443};
$ENV{REMOTE_ADDR} = q{127.0.0.1};

my $C = new Context;
my $cgi = new CGI;
$C->set_object('CGI', $cgi);
my $config = new MdpConfig(File::Spec->catdir($ENV{SDRROOT}, 'mdp-lib/Config/uber.conf'),
                           File::Spec->catdir($ENV{SDRROOT}, 'slip-lib/Config/common.conf'));
$C->set_object('MdpConfig', $config);
my $db_user = $ENV{'MARIADB_USER'} || 'ht_testing';
my $db = new Database($db_user);
$C->set_object('Database', $db);
my $auth = new Auth::Auth($C);
$C->set_object('Auth', $auth);

# pd/bib volume in sql/002_ht_rights_current.sql fixture
my $ar = Access::Rights->new($C, 'test.pd_bib_google_google');
my $resp = $ar->check_final_access_status($C, 'test.pd_bib_google_google');
is($resp, 'allow');

# pdus/bib volume in sql/002_ht_rights_current.sql fixture
$ar = Access::Rights->new($C, 'test.pdus_bib_google_google');
$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'US';
$resp = $ar->check_final_access_status($C, 'test.pdus_bib_google_google');
is($resp, 'allow');

$ar = Access::Rights->new($C, 'test.pdus_bib_google_google');
$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'GB';
$resp = $ar->check_final_access_status($C, 'test.pdus_bib_google_google');
is($resp, 'deny');

done_testing();

