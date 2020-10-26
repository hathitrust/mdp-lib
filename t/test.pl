#!/usr/bin/perl -w

use strict;
use Test::Harness;
use FindBin;
use lib "$FindBin::Bin/..";
use lib "$FindBin::Bin/../../slip-lib";
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

BEGIN {
    $ENV{HT_DEV} = 'test';
}

system("mkdir /ram") unless ( -d "/ram" );

# Colorization is for Mac Docker app which makes it difficult to distinguish
# test runs in the logs.
my @colors = qw(BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE
                BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW
                BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE);
my $col1 = splice(@colors, rand @colors, 1);
my $col2 = splice(@colors, rand @colors, 1);
foreach my $i (0 .. 9)
{
  print Term::ANSIColor::colored('====', $col1);
  print Term::ANSIColor::colored('====', $col2);
}
print "\n";

#my @test_files = ('mdp-lib/t/namespace.t',
#                  'mdp-lib/t/rights.t',
#                 );
#runtests map { File::Spec->catdir($ENV{SDRROOT}, $_); } @test_files;
my @test_files = glob("$FindBin::Bin/../t/*.t");
runtests @test_files;

foreach my $i (0 .. 9)
{
  print Term::ANSIColor::colored('====', $col1);
  print Term::ANSIColor::colored('====', $col2);
}
print "\n";
