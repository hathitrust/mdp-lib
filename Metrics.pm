package Metrics;

use Prometheus::Tiny::Shared;

my $singleton = undef;

sub new {
  # Re-use singleton if defined.
  if (!defined $singleton) {
    my $class = shift;
    my $self  = {};

    $self->{prom} = Prometheus::Tiny::Shared->new(
      #filename => $self->{file}
    );
    $self->{declared_metrics} = {};
    $singleton = bless($self, $class);
  }
  return $singleton;
}

sub declare {
  my $self   = shift;
  my $metric = shift;

  $self->{declared_metrics}->{$metric} = 1;
  $self->{prom}->declare($metric, @_);
}

sub is_declared {
  my $self   = shift;
  my $metric = shift;

  defined $self->{declared_metrics}->{$metric};
}

sub observe {
  my $self   = shift;
  my $metric = shift;

  return unless $self->is_declared($metric);
  $self->{prom}->histogram_observe($metric, @_);
}

sub add {
  my $self = shift;
  my $metric = shift;

  return unless $self->is_declared($metric);
  $self->{prom}->add($metric, @_);
}

sub format {
  my $self = shift;

  $self->{prom}->format;
}

1;
