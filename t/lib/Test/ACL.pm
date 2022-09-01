package Test::ACL;

sub mock_acls {
    my ( $C, $acl_data ) = @_;

    if ( ref($acl_data) eq 'HASH' ) {
        $acl_data = [ $acl_data ];
    }

    my $acl_ref = {};
    foreach my $acl_datum ( @$acl_data ) {
        my $key = join('|', $$acl_datum{userid}, $$acl_datum{identity_provider});
        $$acl_ref{$key} = $acl_datum;
    }

    bless $acl_ref, 'Auth::ACL';
    $C->set_object('Auth::ACL', $acl_ref);
}

1;