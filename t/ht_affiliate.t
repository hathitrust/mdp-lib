#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use File::Spec;

use RightsGlobals;

use MdpConfig;
use Auth::Auth;
use Auth::ACL;
use Access::Rights;
use Institutions;
use CGI;
use Utils;

#---- MONEKYPATCHES
no warnings 'redefine';
local *Access::Rights::get_rights_attribute = sub {
    my $self = shift;
    my ($C, $id) = @_;

    return ( split(/\./, $id) )[-2];    
};

local *Access::Rights::get_source_attribute = sub {
    my $self = shift;
    my ($C, $id) = @_;

    return ( split(/\./, $id) )[-1];    
};

$Access::Rights::current_location = 'US';
local *Access::Rights::_resolve_access_by_GeoIP = sub {
    my $C = shift;
    my $required_location = shift;
    return ( $required_location eq $Access::Rights::current_location ) ? 'allow' : 'deny';
};

local *Auth::Auth::affiliation_is_hathitrust = sub {
    return 1;
};

local *Auth::Auth::auth_sys_is_SHIBBOLETH = sub {
    return 1;
};

local *Auth::Auth::affiliation_has_emergency_access = sub {
    return 0;
};

local *Auth::Auth::affiliation_is_umich = sub {
    return 0;
};
#---- MONEKYPATCHES


my $C = new Context;
my $cgi = new CGI;
$C->set_object('CGI', $cgi);
my $config = new MdpConfig(File::Spec->catdir($ENV{SDRROOT}, 'mdp-lib/Config/uber.conf'),
                           File::Spec->catdir($ENV{SDRROOT}, 'slip-lib/Config/common.conf'));
$C->set_object('MdpConfig', $config);

my $auth = Auth::Auth->new($C);
$C->set_object('Auth', $auth);

mock_institutions($C);
mock_acls($C);

local %ENV = %ENV;
$ENV{HTTP_HOST} = q{babel.hathitrust.org};
$ENV{SERVER_ADDR} = q{141.213.128.185};
$ENV{SERVER_PORT} = q{443};
$ENV{REMOTE_USER} = 'user';
$ENV{eppn} = q{user@umich.edu};
$ENV{umichCosignFactor} = q{UMICH.EDU};
$ENV{Shib_Identity_Provider} = Auth::Auth::get_umich_IdP_entity_id();
$ENV{AUTH_TYPE} = q{shibboleth};
$ENV{affiliation} = q{member@umich.edu};

sub test_attr {
    my ( $attr, $source, $location ) = @_;
    my $id = "test.$attr.$source";
    $Access::Rights::current_location = $location || 'US';

    my $ar = Access::Rights->new($C, $id);
    my $status = $ar->check_final_access_status($C, $id);
    return $status;
}

my $num_tests = 0;

# US institution
is(test_attr(1, 1), 'allow', 'ht_affiliate + attr=1 + source=1'); $num_tests += 1;
is(test_attr(2, 1), 'deny', 'ht_affiliate + attr=2'); $num_tests += 1;
is(test_attr(3, 1), 'deny', 'ht_affiliate + attr=3'); $num_tests += 1;

# attr=4 -- requires database lock

is(test_attr(5, 1), 'deny', "ht_affiliate + attr=5"); $num_tests += 1;
is(test_attr(6, 1), 'allow', "ht_affiliate + attr=6"); $num_tests += 1;
is(test_attr(7, 1), 'allow', "ht_affiliate + attr=7"); $num_tests += 1;
is(test_attr(8, 1), 'deny', "ht_affiliate + attr=8"); $num_tests += 1;
is(test_attr(9, 1), 'allow', "ht_affiliate + attr=9 + user US"); $num_tests += 1;
is(test_attr(9, 1, 'NONUS'), 'deny', "ht_affiliate + attr=9 + user NONUS"); $num_tests += 1;
is(test_attr(10, 1), 'allow', "ht_affiliate + attr=10"); $num_tests += 1;
is(test_attr(11, 1), 'allow', "ht_affiliate + attr=11"); $num_tests += 1;
is(test_attr(12, 1), 'allow', "ht_affiliate + attr=12"); $num_tests += 1;
is(test_attr(13, 1), 'allow', "ht_affiliate + attr=13"); $num_tests += 1;
is(test_attr(14, 1), 'allow', "ht_affiliate + attr=14"); $num_tests += 1;
is(test_attr(15, 1), 'allow', "ht_affiliate + attr=15"); $num_tests += 1;
is(test_attr(16, 1), 'deny', "ht_affiliate + attr=16"); $num_tests += 1;
is(test_attr(17, 1), 'allow', "ht_affiliate + attr=17"); $num_tests += 1;
is(test_attr(18, 1), 'allow', "ht_affiliate + attr=18"); $num_tests += 1;
is(test_attr(19, 1), 'deny', "ht_affiliate + attr=19"); $num_tests += 1;
is(test_attr(19, 1, 'NONUS'), 'allow', "ht_affiliate + attr=19 + user NONUS"); $num_tests += 1;
is(test_attr(20, 1), 'allow', "ht_affiliate + attr=20"); $num_tests += 1;
is(test_attr(21, 1), 'allow', "ht_affiliate + attr=21"); $num_tests += 1;
is(test_attr(22, 1), 'allow', "ht_affiliate + attr=22"); $num_tests += 1;
is(test_attr(23, 1), 'allow', "ht_affiliate + attr=23"); $num_tests += 1;
is(test_attr(24, 1), 'allow', "ht_affiliate + attr=24"); $num_tests += 1;
is(test_attr(25, 1), 'allow', "ht_affiliate + attr=25"); $num_tests += 1;
is(test_attr(26, 1), 'deny', "ht_affiliate + attr=26"); $num_tests += 1;
is(test_attr(27, 1), 'deny', "ht_affiliate + attr=27"); $num_tests += 1;

# NONUS institution
$ENV{REMOTE_USER} = 'user';
$ENV{eppn} = q{user@ox.ac.edu};
delete $ENV{umichCosignFactor};
$ENV{Shib_Identity_Provider} = q{https://registry.shibboleth.ox.ac.uk/idp};
$ENV{affiliation} = q{member@ox.ac.edu};
is(test_attr(9, 1, 'US'), 'allow', "NON US ht_affiliate + attr=9 + user US"); $num_tests += 1;
is(test_attr(9, 1, 'NONUS'), 'deny', "NON US ht_affiliate + attr=9 + user NONUS"); $num_tests += 1;

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
    $$inst_ref{entityIDs}{q{https://registry.shibboleth.ox.ac.uk/idp}} = {
        sdrinst => 'ox',
        inst_id => 'ox',
        entityID => q{https://registry.shibboleth.ox.ac.uk/idp},
        enabled => 1,
        allowed_affiliations => q{^(alum|member)@ox.ac.uk},
        us => 0,
    };
    bless $inst_ref, 'Institutions';
    $C->set_object('Institutions', $inst_ref);
}

sub mock_acls {
    my ( $C ) = @_;

    my $acl_ref = {};
    $$acl_ref{'bjensen'} = { userid => 'bjensen' };
    bless $acl_ref, 'Auth::ACL';
    $C->set_object('Auth::ACL', $acl_ref);
}