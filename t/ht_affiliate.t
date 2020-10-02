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

local *Auth::Auth::affiliation_is_hathitrust = sub {
    return 1;
};

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
    $ENV{TEST_GEO_IP_COUNTRY_CODE} = $location || 'US';

    unless ( $attr ) {
        print STDERR caller();
    }

    my $ar = Access::Rights->new($C, $id);
    my $status = $ar->check_final_access_status($C, $id);
    return $status;
}

my $num_tests = 0;

my $attrs = \%RightsGlobals::g_attributes;
my $sources = \%RightsGlobals::g_sources;

# US institution
is(test_attr($$attrs{'pd'}, $$sources{'google'}), 'allow', 'ht_affiliate + attr=pd + source=1'); $num_tests += 1;
is(test_attr($$attrs{'ic'}, $$sources{'google'}), 'deny', 'ht_affiliate + attr=ic'); $num_tests += 1;
is(test_attr($$attrs{'op'}, $$sources{'google'}), 'deny', 'ht_affiliate + attr=op'); $num_tests += 1;

# attr=4 -- requires database lock

is(test_attr($$attrs{'und'}, $$sources{'google'}), 'deny', "ht_affiliate + attr=und"); $num_tests += 1;
is(test_attr($$attrs{'umall'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=umall"); $num_tests += 1;
is(test_attr($$attrs{'ic-world'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=ic-world"); $num_tests += 1;
is(test_attr($$attrs{'nobody'}, $$sources{'google'}), 'deny', "ht_affiliate + attr=nobody"); $num_tests += 1;
is(test_attr($$attrs{'pdus'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=pdus + user US"); $num_tests += 1;
is(test_attr($$attrs{'pdus'}, 1, 'NONUS'), 'deny', "ht_affiliate + attr=pdus + user NONUS"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-3.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-3.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nd-3.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nd-3.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nc-nd-3.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nc-nd-3.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nc-3.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nc-3.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nc-sa-3.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nc-sa-3.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-sa-3.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-sa-3.0"); $num_tests += 1;
is(test_attr($$attrs{'orphcand'}, $$sources{'google'}), 'deny', "ht_affiliate + attr=orphcand"); $num_tests += 1;
is(test_attr($$attrs{'cc-zero'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-zero"); $num_tests += 1;
is(test_attr($$attrs{'und-world'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=und-world"); $num_tests += 1;
is(test_attr($$attrs{'icus'}, $$sources{'google'}), 'deny', "ht_affiliate + attr=icus"); $num_tests += 1;
is(test_attr($$attrs{'icus'}, $$sources{'google'}, 'NONUS'), 'allow', "ht_affiliate + attr=icus + user NONUS"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-4.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-4.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nd-4.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nd-4.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nc-nd-4.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nc-nd-4.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nc-4.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nc-4.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-nc-sa-4.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-nc-sa-4.0"); $num_tests += 1;
is(test_attr($$attrs{'cc-by-sa-4.0'}, $$sources{'google'}), 'allow', "ht_affiliate + attr=cc-by-sa-4.0"); $num_tests += 1;
is(test_attr($$attrs{'pd-pvt'}, $$sources{'google'}), 'deny', "ht_affiliate + attr=pd-pvt"); $num_tests += 1;
is(test_attr($$attrs{'supp'}, $$sources{'google'}), 'deny', "ht_affiliate + attr=supp"); $num_tests += 1;

# NONUS institution
$ENV{REMOTE_USER} = 'user';
$ENV{eppn} = q{user@ox.ac.edu};
delete $ENV{umichCosignFactor};
$ENV{Shib_Identity_Provider} = q{https://registry.shibboleth.ox.ac.uk/idp};
$ENV{affiliation} = q{member@ox.ac.edu};
is(test_attr($$attrs{'pdus'}, $$sources{'google'}, 'US'), 'allow', "NON US ht_affiliate + attr=9 + user US"); $num_tests += 1;
is(test_attr($$attrs{'pdus'}, $$sources{'google'}, 'NONUS'), 'deny', "NON US ht_affiliate + attr=9 + user NONUS"); $num_tests += 1;

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
