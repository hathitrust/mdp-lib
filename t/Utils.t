#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use Utils;

local %ENV = %ENV;

subtest "Get_Remote_User_Names" => sub {
  my $save_remote_user = $ENV{REMOTE_USER};
  my $save_eppn = $ENV{eppn};
  $ENV{eppn} = 'EPPN@default.invalid';
  $ENV{REMOTE_USER} = 'REMOTE_USER@default.invalid';
  subtest "contains lowercase REMOTE_USER" => sub {
    ok(1 <= scalar grep(/remote_user/, Utils::Get_Remote_User_Names()));
  };
  subtest "contains case-preserved REMOTE_USER" => sub {
    ok(1 <= scalar grep(/REMOTE_USER/, Utils::Get_Remote_User_Names()));
  };
  subtest "contains lowercase EPPN" => sub {
    ok(1 <= scalar grep(/eppn/, Utils::Get_Remote_User_Names()));
  };
  subtest "contains case-preserved EPPN" => sub {
    ok(1 <= scalar grep(/EPPN/, Utils::Get_Remote_User_Names()));
  };
  $ENV{REMOTE_USER} = $save_remote_user;
  $ENV{eppn} = $save_eppn;
};

done_testing();
