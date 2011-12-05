package Utils::Cache::Storable;

=head1 NAME

Utils::Cache::Storable

=head1 DESCRIPTION

Backing for L<Utils::Cache>.

=head1 SYNOPSIS

$cache = Utils::Cache::Storable->new($cache_dir);
$cache->Set($id, $key, $data);

$data2 = $cache->Get($id, $key);

=head1 METHODS

=over 8

=cut

use Storable qw(freeze retrieve nstore);
use Carp;

use Utils::Cache;
use base qw(Utils::Cache);

sub suffix {
    my $self = shift;
    return '.bin';
}

sub serialize
{
    my $self = shift;
    my $value = shift;
    my $tmpfilename = shift;
    
    # return freeze($value);
    nstore($value, $tmpfilename);
}

sub instantiate
{
    my $self = shift;
    my $keyFileName = shift;
    
    my $data = retrieve($keyFileName) or die "Could not retrieve $keyFileName: $!";
    if (ref($data)) {
        return $data;
    }
    
    return undef;
    
}

1;
