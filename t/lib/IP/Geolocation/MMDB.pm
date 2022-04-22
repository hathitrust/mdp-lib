package IP::Geolocation::MMDB;

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return $self;
}

sub getcc {
    return $ENV{TEST_GEO_IP_COUNTRY_CODE} || 'US';
}

1;
