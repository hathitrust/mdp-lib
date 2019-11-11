package Utils::Settings;

use JSON::XS;
use Carp;

sub load {
    my ( $app, $specific ) = @_;

    my $settings_base = $app;
    $settings_base .= "/$specific" if ( $specific );
    $settings_base .= ".json";

    my @settings_paths = ();
    my $_prod_root = q{/htapps/babel/etc/settings/};
    my $_test_root = q{/htapps/test.babel/etc/settings/};

    push @settings_paths, "$ENV{SDRROOT}/etc/settings" if ( $ENV{HT_DEV} );
    push @settings_paths, $_test_root if ( -e $_test_root );
    push @settings_paths, $_prod_root if ( -e $_prod_root );

    foreach my $settings_path ( @settings_paths ) {
        my $settings_filename = "$settings_path/$settings_base";
        if ( -f $settings_filename ) {
            my $data;
            {
                local $/;
                my $fh;
                croak "Cannot open $settings_filename" if not open($fh, '<:utf8', "$settings_filename");
                $data = <$fh>;
                croak "Cannot close $settings_filename" if not close($fh);
            }
            return JSON::XS::decode_json($data) if ( $data );
        }
    }

    # NOOP
    return {};
}

1;