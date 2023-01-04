#!/usr/bin/perl

use feature qw(say);

use strict;
use warnings;
use Test::More;
use File::Spec;

use Identifier;
use Utils;
use Auth::Auth;

use File::Basename qw(dirname);
use FindBin;

my $C = new Context;
my $cgi = new CGI;
$C->set_object('CGI', $cgi);
my $config = new MdpConfig(File::Spec->catdir($ENV{SDRROOT}, 'mdp-lib/Config/uber.conf'),
                           File::Spec->catdir($ENV{SDRROOT}, 'slip-lib/Config/common.conf'));                           
$C->set_object('MdpConfig', $config);


my $auth = Auth::Auth->new($C);
$C->set_object( 'Auth', $auth );

local %ENV = %ENV;

# simple test
$ENV{REMOTE_USER} = q{urn:test.edu:user:alpha};
is(Utils::Get_Remote_User(), $ENV{REMOTE_USER}, "matches REMOTE_USER");

$ENV{REMOTE_USER} = q{urn:test.edu:user:BETA};
is(Utils::Get_Remote_User(), lc $ENV{REMOTE_USER}, "matches lc REMOTE_USER");

$ENV{REMOTE_USER} = q{urn:test.edu:user:gamma};
$ENV{eppn} = q{gamma@test.edu};
my $user_names_1 = [ lc $ENV{REMOTE_USER}, 'gamma@test.edu' ];
is_deeply([ Utils::Get_Remote_User_Names() ], $user_names_1, "returns all user names");

$ENV{REMOTE_USER} = q{urn:test.edu:user:delta};
$ENV{eppn} = q{delta@test.edu;delta@test.edu;delta@lib.test.edu};
my $user_names_2 = [ lc $ENV{REMOTE_USER}, 'delta@test.edu', 'delta@lib.test.edu' ];
is_deeply([ Utils::Get_Remote_User_Names() ], $user_names_2, "returns all unique user names");

done_testing();