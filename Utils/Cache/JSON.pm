package Utils::Cache::JSON;

=head1 NAME

Utils::Cache::JSON

=head1 DESCRIPTION

Backing for L<Utils::Cache>.

=head1 SYNOPSIS

$cache = Utils::Cache::JSON->new($cache_dir);
$cache->Set($id, $key, $data);

$data2 = $cache->Get($id, $key);

=head1 METHODS

=over 8

=cut

use JSON::XS;
use Carp;

use Utils::Cache;
use base qw(Utils::Cache);

sub suffix {
    my $self = shift;
    return '.json';
}

sub serialize
{
    my $self = shift;
    my $value = shift;
    my $tmpfilename = shift;
    
    my $data = encode_json($value);

    my $fh = IO::File->new($tmpfilename, ">", ":utf8") or die "Could not open $tmpfilename - $!";
    binmode($fh);
    $fh->write($data);
    $fh->close;

}

sub instantiate
{
    my $self = shift;
    my $keyFileName = shift;
    
    my $data;
    {
        local $/ = undef;
        my $fh;
        croak "Cannot open $keyFileName" if not open($fh, '<:utf8', $keyFileName);
        $data = <$fh>;
        croak "Cannot close $keyFileName" if not close($fh);
    }
    
    if($data) {
        return decode_json($data);
    }
    
    return undef;
    
}

1;
