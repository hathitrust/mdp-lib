#!/usr/bin/perl

use strict;
use warnings;

use feature qw(say);

use FindBin;
use lib "$FindBin::Bin/..";

use RightsGlobals;

use MdpConfig;
use Database;
use Session;
use Auth::Auth;
use Access::Rights;
use CGI;

use IO::File;
autoflush STDOUT 1;

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

$test::location = 'US';
local *Access::Rights::_resolve_access_by_GeoIP = sub {
    my $C = shift;
    my $required_location = shift;
    return ( $required_location eq $test::location ) ? 'allow' : 'deny';
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

# configuration
my $config = new MdpConfig(
                            "$FindBin::Bin/../Config/uber.conf",
                          );

my $C = new Context;
$C->set_object('MdpConfig', $config);

my $auth = Auth::Auth->new($C);
$C->set_object('Auth', $auth);

# Database connection
# NEEDED: for Auth::ACL and Institutions
my $db = new Database('ht_maintenance');
our $dbh = $db->get_DBH();
$C->set_object('Database', $db);

sub test_attr {
    my ( $attr, $source, $expected, $location ) = @_;
    my $id = "test.$attr.$source";
    $location = 'US' unless ( $location );
    $test::location = $location;

    my $ar = Access::Rights->new($C, $id);
    my $status = $ar->check_final_access_status($C, $id);
    say "attr=$attr : source=$source : $expected == $status : " . ( ( $status eq $expected ) ? 'PASS' : 'FAILED' );
}

{
    local %ENV = %ENV;
    $ENV{HTTP_HOST} = q{babel.hathitrust.org};
    $ENV{SERVER_ADDR} = q{141.213.128.185};
    $ENV{SERVER_PORT} = q{443};
    $ENV{REMOTE_USER} = 'user';
    $ENV{eppn} = q{user@umich.edu};
    $ENV{Shib_Identity_Provider} = Auth::Auth::get_umich_IdP_entity_id();
    $ENV{AUTH_TYPE} = q{shibboleth};
    $ENV{affiliation} = q{member@umich.edu};

    test_attr(1, 1, 'allow');
    test_attr(2, 1, 'deny');
    test_attr(3, 1, 'deny');

    # attr=4 -- requires database lock
    # test_attr(4, 1, 'allow');

    test_attr(5, 1, 'deny');
    test_attr(6, 1, 'allow');
    test_attr(7, 1, 'allow');
    test_attr(8, 1, 'deny');
    test_attr(9, 1, 'allow');

    {
        local %ENV = %ENV;
        $ENV{Shib_Identity_Provider} = q{https://registry.shibboleth.ox.ac.uk/idp};
        test_attr(9, 1, 'deny', 'NONUS');
    }

    test_attr(10, 1, 'allow');

    test_attr(11, 1, 'allow');
    test_attr(12, 1, 'allow');
    test_attr(13, 1, 'allow');
    test_attr(14, 1, 'allow');
    test_attr(15, 1, 'allow');
    test_attr(16, 1, 'deny');
    test_attr(17, 1, 'allow');
    test_attr(18, 1, 'allow');

    test_attr(19, 1, 'deny');
    test_attr(19, 1, 'allow', 'NONUS');

    test_attr(20, 1, 'allow');
    test_attr(21, 1, 'allow');
    test_attr(22, 1, 'allow');
    test_attr(23, 1, 'allow');
    test_attr(24, 1, 'allow');
    test_attr(25, 1, 'allow');
    test_attr(26, 1, 'deny');
    test_attr(27, 1, 'deny');





}
