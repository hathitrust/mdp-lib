#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/lib";
use IP::Geolocation::MMDB;

my $geoip = IP::Geolocation::MMDB->new( file => '/pretend/GeoIP2-Country.mmdb' );

$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'US';
is('US', $geoip->getcc('0.0.0.0'));

$ENV{TEST_GEO_IP_COUNTRY_CODE} = 'UK';
is('UK', $geoip->getcc('0.0.0.0'));

done_testing();


