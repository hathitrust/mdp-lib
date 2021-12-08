#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use Geo::IP;

my $geoip = Geo::IP->new();

$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'US';
is('US', $geoip->country_code_by_addr());
is('Geo::IP_stub_US', $geoip->country_name_by_addr());

$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'UK';
is('UK', $geoip->country_code_by_addr());
is('Geo::IP_stub_UK', $geoip->country_name_by_addr());

done_testing();


