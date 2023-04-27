#!/usr/bin/env perl

use feature qw(say);
use Config::Tiny;
use Data::Dumper;
use Getopt::Long;

my @ALL_APPS = qw/ls mb ping ssd pt imgsrv/;

sub usage {
    say "# enable/disable debug=local/enabled;\n# by default all installed apps will be configured.";
    say "$0 --enable [app app+]";
    say "$0 --disable [app app+]";
    exit;
}

my $enabled;
GetOptions(
    'enable!' => \$enabled,
    'disable' => sub { $enabled = 0 }
);

unless ( defined $enabled ) {
    usage();
    exit;
}

my @apps = scalar @ARGV ?  @ARGV : @ALL_APPS;

foreach my $app ( @apps ) {
    my $app_dir = qq{$ENV{SDRROOT}/$app};
    next unless ( -d $app_dir );
    my $local_filename = qq{$app_dir/lib/Config/local.conf};
    my $config = ( -f $local_filename ) ?
        Config::Tiny->read($local_filename) : 
        Config::Tiny->new;
    $$config{_}{debug_local} = $enabled;
    $$config{_}{debug_enabled} = $enabled;

    # this is dumb, but internally mdp-lib
    # depends on "key = value" to have that whitespace
    my @output = ();
    foreach my $line ( split(/\n/, $config->write_string()) ) {
        my ( $key, $value ) = split(/=/, $line, 2);
        push @output, qq{$key = $value};
    }
    open(my $fh, ">", $local_filename) || die "could not open $local_filename - $!";
    print $fh join("\n", @output);
    close($fh);
    say "updated $app: debug=$enabled";
}