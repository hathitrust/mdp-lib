package Geo::IP;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub country_code_by_addr {
  return $ENV{TEST_GEO_IP_COUNTRY_CODE} || 'US';
}

# This seems to be used only by Auth::Logger so just return an identifiable value.
sub country_name_by_addr {
  my $self = shift;
  return 'Geo::IP_stub_' . $self->country_code_by_addr;
}

1;
