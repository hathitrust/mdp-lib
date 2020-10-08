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

use Data::Dumper;
use feature qw(say);

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
$ENV{AUTH_TYPE} = q{shibboleth};
$ENV{affiliation} = q{member@umich.edu};

sub setup_us_institution {
    $ENV{REMOTE_USER} = 'user';
    $ENV{eppn} = q{user@umich.edu};
    $ENV{umichCosignFactor} = q{UMICH.EDU};
    $ENV{Shib_Identity_Provider} = Auth::Auth::get_umich_IdP_entity_id();    
}

sub setup_nonus_instition {
    $ENV{REMOTE_USER} = 'user';
    $ENV{eppn} = q{user@ox.ac.edu};
    delete $ENV{umichCosignFactor};
    $ENV{Shib_Identity_Provider} = q{https://registry.shibboleth.ox.ac.uk/idp};
    $ENV{affiliation} = q{member@ox.ac.edu};
}

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
my $profiles = \%RightsGlobals::g_access_profiles;

my $tests = [];
while ( my $line = <DATA> ) {
    chomp $line;
    next unless ( $line );
    push @$tests, [ split(/\|/, $line) ];
}

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

    my $location = $access_type =~ m,NONUS, ? 'NONUS' : 'US';
    if ( $location eq 'US' ) { setup_us_institution(); }
    else { setup_nonus_instition(); }

    if ( $expected_volume eq 'allow_by_us_geo_ipaddr' ) {
        $expected_volume = ( $location eq 'NONUS' ) ? 'deny' : 'allow';
    } elsif ( $expected_volume eq 'allow_nonus_aff_by_ipaddr' ) {
        $expected_volume = ( $location eq 'NONUS' ) ? 'allow' : 'deny';
    }
    is(test_attr($code, $$profiles{$access_profile}, $location), $expected_volume, "ht_affiliate + attr=$attr + location=$location + proflie=$access_profile");
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
<<<<<<< HEAD
=======

__DATA__
1|pd|open|ht_affiliate|allow|allow|allow|allow
1|pd|google|ht_affiliate|allow|allow|allow|allow
1|pd|page|ht_affiliate|allow|allow|deny|allow
2|ic|open|ht_affiliate|deny|deny|deny|deny
2|ic|google|ht_affiliate|deny|deny|deny|deny
2|ic|page|ht_affiliate|deny|deny|deny|deny
3|op|open|ht_affiliate|deny|deny|deny|deny
3|op|google|ht_affiliate|deny|deny|deny|deny
5|und|open|ht_affiliate|deny|deny|deny|deny
5|und|google|ht_affiliate|deny|deny|deny|deny
5|und|page|ht_affiliate|deny|deny|deny|deny
7|ic-world|open|ht_affiliate|allow|allow|allow|allow
7|ic-world|google|ht_affiliate|allow|allow|allow|allow
7|ic-world|page|ht_affiliate|allow|allow|deny|allow
8|nobody|open|ht_affiliate|deny|deny|deny|deny
8|nobody|google|ht_affiliate|deny|deny|deny|deny
8|nobody|page|ht_affiliate|deny|deny|deny|deny
9|pdus|open|ht_affiliate - NONUS|deny|deny|deny|deny
9|pdus|google|ht_affiliate - NONUS|deny|deny|deny|deny
9|pdus|page|ht_affiliate - NONUS|deny|deny|deny|deny
9|pdus|open|ht_affiliate - US|allow_by_us_geo_ipaddr|allow|allow|allow
9|pdus|google|ht_affiliate - US|allow_by_us_geo_ipaddr|allow|allow|allow
9|pdus|page|ht_affiliate - US|allow_by_us_geo_ipaddr|allow|deny|allow
10|cc-by-3.0|open|ht_affiliate|allow|allow|allow|deny
10|cc-by-3.0|google|ht_affiliate|allow|allow|allow|deny
11|cc-by-nd-3.0|open|ht_affiliate|allow|allow|allow|deny
11|cc-by-nd-3.0|google|ht_affiliate|allow|allow|allow|deny
12|cc-by-nc-nd-3.0|open|ht_affiliate|allow|allow|allow|deny
12|cc-by-nc-nd-3.0|google|ht_affiliate|allow|allow|allow|deny
12|cc-by-nc-nd-3.0|page|ht_affiliate|allow|allow|allow|deny
13|cc-by-nc-3.0|open|ht_affiliate|allow|allow|allow|deny
13|cc-by-nc-3.0|google|ht_affiliate|allow|allow|allow|deny
13|cc-by-nc-3.0|page|ht_affiliate|allow|allow|allow|deny
14|cc-by-nc-sa-3.0|open|ht_affiliate|allow|allow|allow|deny
14|cc-by-nc-sa-3.0|google|ht_affiliate|allow|allow|allow|deny
15|cc-by-sa-3.0|google|ht_affiliate|allow|allow|allow|deny
17|cc-zero|open|ht_affiliate|allow|allow|allow|deny
17|cc-zero|google|ht_affiliate|allow|allow|allow|deny
17|cc-zero|page|ht_affiliate|allow|allow|allow|deny
18|und-world|page+lowres|ht_affiliate|allow|allow|deny|allow
19|icus|open|ht_affiliate - NONUS|allow_nonus_aff_by_ipaddr|allow|allow|allow
19|icus|google|ht_affiliate - NONUS|allow_nonus_aff_by_ipaddr|allow|allow|allow
19|icus|open|ht_affiliate - US|deny|deny|deny|deny
19|icus|google|ht_affiliate - US|deny|deny|deny|deny
20|cc-by-4.0|open|ht_affiliate|allow|allow|allow|deny
20|cc-by-4.0|google|ht_affiliate|allow|allow|allow|deny
21|cc-by-nd-4.0|open|ht_affiliate|allow|allow|allow|deny
21|cc-by-nd-4.0|google|ht_affiliate|allow|allow|allow|deny
22|cc-by-nc-nd-4.0|open|ht_affiliate|allow|allow|allow|deny
22|cc-by-nc-nd-4.0|google|ht_affiliate|allow|allow|allow|deny
22|cc-by-nc-nd-4.0|page|ht_affiliate|allow|allow|allow|deny
23|cc-by-nc-4.0|open|ht_affiliate|allow|allow|allow|deny
23|cc-by-nc-4.0|google|ht_affiliate|allow|allow|allow|deny
24|cc-by-nc-sa-4.0|open|ht_affiliate|allow|allow|allow|deny
24|cc-by-nc-sa-4.0|google|ht_affiliate|allow|allow|allow|deny
25|cc-by-sa-4.0|open|ht_affiliate|allow|allow|allow|deny
25|cc-by-sa-4.0|google|ht_affiliate|allow|allow|allow|deny
26|pd-pvt|open|ht_affiliate|deny|deny|deny|deny
26|pd-pvt|google|ht_affiliate|deny|deny|deny|deny
27|supp|open|ht_affiliate|deny|deny|deny|deny
27|supp|google|ht_affiliate|deny|deny|deny|deny
>>>>>>> 49e00dc... wut?
