#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Spec;

use Context;
use Database;
use Namespaces;
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

my $inst = Namespaces::get_institution_by_namespace($C, 'mdp.001');
is($inst, 'University of Michigan');

done_testing();

