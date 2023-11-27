#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Utils;

local %ENV = %ENV;

subtest "Get_Remote_User_Names" => sub {
  my $save_remote_user = $ENV{REMOTE_USER};
  my $save_eppn = $ENV{eppn};

  subtest "with logged-in user" => sub {
    $ENV{eppn} = 'EPPN@default.invalid';
    $ENV{REMOTE_USER} = 'REMOTE_USER@default.invalid';
    my @names = Utils::Get_Remote_User_Names();
    ok(1 <= scalar grep(/remote_user/, @names), "contains lowercase REMOTE_USER");
    ok(1 <= scalar grep(/REMOTE_USER/, @names), "contains case-preserved REMOTE_USER");
    ok(1 <= scalar grep(/eppn/, @names), "contains lowercase EPPN");
    ok(1 <= scalar grep(/EPPN/, @names), "contains case-preserved EPPN");
  };

  subtest "with logged-out user" => sub {
    delete $ENV{REMOTE_USER};
    delete $ENV{eppn};
    my @names = Utils::Get_Remote_User_Names();
    ok(1 == scalar @names, "there is one name");
    ok('' eq $names[0], "name is empty string");
  };

  $ENV{REMOTE_USER} = $save_remote_user;
  $ENV{eppn} = $save_eppn;
};

done_testing();
