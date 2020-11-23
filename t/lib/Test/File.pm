package Test::File;

sub load_data {
    my ( $filename ) = @_;

    my $tests = [];

    open ( my $IN, "<", $filename ) || die "could not open $filename - $!";
    while ( my $line = <$IN> ) {
        chomp $line;
        next unless ( $line );
        push @$tests, [ split(/\t/, $line) ];
    }

    shift @$tests; # the first line

    return $tests;
}


1;