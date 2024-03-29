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

local *Auth::Auth::auth_sys_is_SHIBBOLETH = sub {
    return 1;
};

local *Auth::Auth::affiliation_has_emergency_access = sub {
    return 0;
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

sub setup_us_institution {
    $ENV{REMOTE_USER} = 'user@umich.edu';
    $ENV{eppn} = q{user@umich.edu};
    $ENV{umichCosignFactor} = q{UMICH.EDU};
    $ENV{Shib_Identity_Provider} = Auth::Auth::get_umich_IdP_entity_id();    
    $ENV{affiliation} = q{};
}

sub setup_nonus_institution {
    $ENV{REMOTE_USER} = 'user@ox.ac.edu';
    $ENV{eppn} = q{user@ox.ac.edu};
    delete $ENV{umichCosignFactor};
    $ENV{Shib_Identity_Provider} = q{https://registry.shibboleth.ox.ac.uk/idp};
    $ENV{affiliation} = q{};
}

sub setup_non_member_institution {
    $ENV{REMOTE_USER} = 'user@gmail.com';
    $ENV{eppn} = q{user@gmail.com};
    $ENV{Shib_Identity_Provider} = q{gmail.com};
    delete $ENV{umichCosignFactor};
    $ENV{affiliation} = '';
}

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

sub test_download_volume {
    my ( $attr, $access_profile, $location ) = @_;
    my $id = "test.$attr\_$access_profile";
    $ENV{TEST_GEO_IP_COUNTRY_CODE} = $location || 'US';

    unless ( $attr ) {
        print STDERR caller();
    }

    my $ar = Access::Rights->new($C, $id);
    my $status = $ar->check_final_access_status($C, $id);
    if ( $status eq 'allow' ) {
        $status = $ar->get_full_PDF_access_status($C, $id);
    }
    return $status;
}

my $num_tests = 0;

my $member_tests = Test::File::load_data("$FindBin::Bin/data/access/ht_affiliate.tsv");
my $ordinary_user_tests = Test::File::load_data("$FindBin::Bin/data/access/ordinary_user.tsv");

mock_institutions($C);
Test::ACL::mock_acls($C, { userid => 'bjensen@umich.edu', identity_provider => Auth::Auth::get_umich_IdP_entity_id() });


local %ENV = %ENV;
$ENV{HTTP_HOST} = q{babel.hathitrust.org};
$ENV{SERVER_ADDR} = q{141.213.128.185};
$ENV{SERVER_PORT} = q{443};
$ENV{AUTH_TYPE} = q{shibboleth};
$ENV{entitlement} = $Auth::Auth::ENTITLEMENT_COMMON_LIB_TERMS;

# test get_eduPersonEntitlement
setup_non_member_institution();
is(
    $auth->get_eduPersonEntitlement($C)->has_entitlement($Auth::Auth::ENTITLEMENT_COMMON_LIB_TERMS), 
    0, 
    "non-member insitution does not recognize common-lib-terms entitlement"
);
$num_tests += 1;


setup_us_institution();
my $FAKE_ENTITLEMENT = q{urn:mace:dir:entitlement:uncommon-common-lib-terms};
$ENV{entitlement} .= qq{;$FAKE_ENTITLEMENT};
is(
    $auth->get_eduPersonEntitlement($C)->to_s, 
    $ENV{entitlement}, 
    "member institution parsed all entitlements"
);
$num_tests += 1;

is(
    $auth->get_eduPersonEntitlement($C)->has_entitlement($Auth::Auth::ENTITLEMENT_COMMON_LIB_TERMS), 
    1, 
    "member institution recognizes common-lib-terms entitlement"
);
$num_tests += 1;

$ENV{entitlement} = $FAKE_ENTITLEMENT;
is(
    $auth->get_eduPersonEntitlement($C)->has_entitlement($FAKE_ENTITLEMENT), 
    1, 
    "member institution has uncommon-common-lib-terms entitlement"
);
$num_tests += 1;

is(
    $auth->get_eduPersonEntitlement($C)->has_entitlement($Auth::Auth::ENTITLEMENT_COMMON_LIB_TERMS), 
    0, 
    "member institution does not have common-lib-terms entitlement"
);
$num_tests += 1;

$ENV{entitlement} = $Auth::Auth::ENTITLEMENT_COMMON_LIB_TERMS;
# urn:mace:dir:entitlement:common-lib-terms from member institution
foreach my $test ( @$member_tests ) {
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

    my $location = $access_type =~ m,NONUS, ? 'NONUS' : 'US';
    if ( $location eq 'US' ) { setup_us_institution(); }
    else { setup_nonus_institution(); }

    if ( $expected_volume eq 'allow_by_us_geo_ipaddr' ) {
        $expected_volume = ( $location eq 'NONUS' ) ? 'deny' : 'allow';
    } elsif ( $expected_volume eq 'allow_nonus_aff_by_ipaddr' ) {
        $expected_volume = ( $location eq 'NONUS' ) ? 'allow' : 'deny';
    }
    is(test_attr($attr, $access_profile, $location), $expected_volume, "common-lib-terms + member institution + attr=$attr + location=$location + profile=$access_profile");
    $num_tests += 1;
    is(test_download_volume($attr, $access_profile, $location), $expected_download_volume, "common-lib-terms + member institution + attr=$attr + location=$location + profile=$access_profile + download volume");
    $num_tests += 1;
}

# urn:mace:dir:entitlement:common-lib-terms from non-member institution
foreach my $test ( @$ordinary_user_tests ) {
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

    setup_non_member_institution();

    my $location = $access_type =~ m,NONUS, ? 'NONUS' : 'US';

    if ( $expected_volume eq 'allow_by_us_geo_ipaddr' ) {
        $expected_volume = ( $location eq 'NONUS' ) ? 'deny' : 'allow';
    } elsif ( $expected_volume eq 'allow_by_nonus_geo_ipaddr' ) {
        $expected_volume = ( $location eq 'NONUS' ) ? 'allow' : 'deny';
    }
    is(test_attr($attr, $access_profile, $location), $expected_volume, "common-lib-terms + non-member institution + attr=$attr + location=$location + profile=$access_profile");
    $num_tests += 1;
    is(test_download_volume($attr, $access_profile, $location), $expected_download_volume, "common-lib-terms + non-member institution + attr=$attr + location=$location + profile=$access_profile + download volume");
    $num_tests += 1;
}

done_testing($num_tests);

#---- UTILITY
sub mock_institutions {
    my ( $C, $is_member ) = @_;

    my $inst_ref = { entityIDs => {} };
    $$inst_ref{entityIDs}{Auth::Auth::get_umich_IdP_entity_id()} = {
        sdrinst => 'uom',
        inst_id => 'umich',
        entityID => Auth::Auth::get_umich_IdP_entity_id(),
        enabled => 1,
        allowed_affiliations => q{^(alum|member)@umich.edu},
        us => 1,
    };
    $$inst_ref{entityIDs}{q{https://registry.shibboleth.ox.ac.uk/idp}} = {
        sdrinst => 'ox',
        inst_id => 'ox',
        entityID => q{https://registry.shibboleth.ox.ac.uk/idp},
        enabled => 1,
        allowed_affiliations => q{^(alum|member)@ox.ac.uk},
        us => 0,
    };
    $$inst_ref{entityIDs}{q{gmail.com}} = {
    };
    bless $inst_ref, 'Institutions';
    $C->set_object('Institutions', $inst_ref);
}
