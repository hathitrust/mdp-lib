#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Spec;

use FindBin;
use lib "$FindBin::Bin/lib";

use RightsGlobals;

use MdpConfig;
use Auth::Auth;
use Auth::ACL;
use Access::Rights;
use Database;
use Institutions;
use CGI;
use Utils;

use Test::File;
use Test::ACL;

use Data::Dumper;
use feature qw(say);

#---- MONEKYPATCHES
no warnings 'redefine';
local *Auth::Auth::affiliation_is_hathitrust = sub {
    return 1;
};

local *Auth::Auth::auth_sys_is_SHIBBOLETH = sub {
    return 1;
};

local *Auth::Auth::is_in_library = sub {
    return 1;
};

local *Auth::Auth::is_logged_in = sub {
    return 0;
};

local *Auth::Auth::affiliation_has_emergency_access = sub {
    return 0;
};

local *Access::Rights::_assert_access_exclusivity = sub {
    return 'allow';
};

local *Access::Rights::_check_access_exclusivity = sub {
    return 'allow';
};
#---- MONEKYPATCHES


my $C = new Context;
my $cgi = new CGI;
$C->set_object('CGI', $cgi);
my $config = new MdpConfig(File::Spec->catdir($ENV{SDRROOT}, 'mdp-lib/Config/uber.conf'),
                           File::Spec->catdir($ENV{SDRROOT}, 'slip-lib/Config/common.conf'));
$C->set_object('MdpConfig', $config);

my $db_user = $ENV{'MARIADB_USER'} || 'ht_testing';
my $db = new Database($db_user);
$C->set_object('Database', $db);

my $auth = Auth::Auth->new($C);
$C->set_object('Auth', $auth);

mock_institutions($C);
Test::ACL::mock_acls($C, { userid => 'user@umich.edu', role => 'corrections', usertype => 'staff', access => 'total', expires => '2040-12-31 23:59:59', identity_provider => Auth::Auth::get_umich_IdP_entity_id() });

local %ENV = %ENV;
$ENV{HTTP_HOST} = q{babel.hathitrust.org};
$ENV{SERVER_ADDR} = q{141.213.128.185};
$ENV{SERVER_PORT} = q{443};
$ENV{AUTH_TYPE} = q{shibboleth};

sub test_attr {
    my ( $attr, $access_profile, $location ) = @_;
    my $id = "test.$attr\_$access_profile";
    $ENV{TEST_GEO_IP_COUNTRY_CODE} = $location || 'US';

    unless ( $attr ) {
        print STDERR caller();
    }

    my $ar = Access::Rights->new($C, $id);
    my $status = $ar->check_final_access_status($C, $id);
    return $status;
}

my $num_tests = 0;

my $tests = Test::File::load_data("$FindBin::Bin/data/access/library_ipaddr_user.tsv");

foreach my $test ( @$tests ) {
    my ( 
        $code, 
        $attr, 
        $access_profile, 
        $access_type, 
        $expected_volume,
        $expected_download_page,
        $expected_download_volume,
        $expected_download_plaintext
    ) = @$test;

    my $location = 'US';

    if ( $expected_volume eq 'allow_by_held_BRLM' ) {
        $expected_volume = 'allow';
    }
    
    is(test_attr($attr, $access_profile, $location), $expected_volume, "library_ipaddr_user + attr=$attr + location=$location + profile=$access_profile");
    $num_tests += 1;
}

done_testing($num_tests);

#---- UTILITY
sub mock_institutions {
    my ( $C ) = @_;

    my $inst_ref = { entityIDs => {} };
    $$inst_ref{entityIDs}{Auth::Auth::get_umich_IdP_entity_id()} = {
        sdrinst => 'uom',
        inst_id => 'umich',
        entityID => Auth::Auth::get_umich_IdP_entity_id(),
        enabled => 1,
        allowed_affiliations => q{^(alum|member)@umich.edu},
        us => 1,
    };
    bless $inst_ref, 'Institutions';
    $C->set_object('Institutions', $inst_ref);
}
