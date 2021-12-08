#!/usr/bin/perl

use feature qw(say);

use strict;
use warnings;
use Test::More;
use File::Spec;

use Identifier;
use Utils;
use Utils::Extract;
use Utils::Logger;
$Utils::Logger::logging_enabled = 0;

use File::Basename qw(dirname);
use FindBin;

my $C = new Context;
my $cgi = new CGI;
$C->set_object('CGI', $cgi);
my $config = new MdpConfig(File::Spec->catdir($ENV{SDRROOT}, 'mdp-lib/Config/uber.conf'),
                           File::Spec->catdir($ENV{SDRROOT}, 'slip-lib/Config/common.conf'));                           
$C->set_object('MdpConfig', $config);

$ENV{SDRDATAROOT} = join('/', $FindBin::Bin, 'data');
my $htid = q{test.9999}; my $barcode = q{9999};
my $filesystem_location = Identifier::get_item_location($htid);
my $local_filesystem_location = Identifier::id_to_mdp_path($htid);

my $filename = '00000001.txt';
my $file_path;
$file_path =
    Utils::Extract::extract_file_to_temp_cache
        (
            $htid,
            $filesystem_location,
            $filename
        );

my $local_file_path = join("/", $ENV{SDRDATAROOT}, "obj", $local_filesystem_location, $barcode, $filename);
my $file_1 = Utils::read_file($local_file_path);
my $file_2 = Utils::read_file($file_path);
is($$file_1, $$file_2);

done_testing();