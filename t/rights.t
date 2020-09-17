#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

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
my $ar = Access::Rights->new($C, 'inu.30000000079024');
my $resp = $ar->check_final_access_status($C, 'inu.30000000079024');
is($resp, 'allow');

# pdus/bib volume in sql/002_ht_rights_current.sql fixture
$ar = Access::Rights->new($C, 'inu.30000000124697');
$resp = $ar->check_final_access_status($C, 'inu.30000000124697');
is($resp, 'deny');

done_testing();

