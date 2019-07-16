package CollectionUser;
use overload '""' => 'get_user_name';

sub new
{
    my $class = shift;
    my ( $user ) = @_;
    if ( ref($user) eq 'Auth::Auth' ) { return $user; }
    if ( ref($user) eq $class ) { return $user; }
    my $self = {};
    bless $self, $class;
    $$self{user_id} = $user;
    return $self;
}

sub get_user_names {
    my $self = shift;
    return ( $$self{user_id} );
}

sub get_user_name {
    my $self = shift;
    return $$self{user_id};
}

1;