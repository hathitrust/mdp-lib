package Utils::GeoIP;

sub get_addr_info {
    my ( $C, $ip_addr ) = @_;

    if ( $ip_addr eq '0' ) {
        return Utils::GeoIP::Info::Null->new;
    }

    my $session = $C->get_object( 'Session', 1 );
    if ( $session && $session->get_persistent_subkey( 'addr_info', $ip_addr ) ) {
        return $session->get_persistent_subkey( 'addr_info', $ip_addr );
    }

    my $db = get_db($C);

    my $info = Utils::GeoIP::Info->new($db, $ip_addr);
    $session->set_persistent_subkey('addr_info', $ip_addr, $info) if ( $session );

    return $info;
}

sub get_db {
    my ( $C ) = @_;
    my $db;
    unless ( $db = $C->get_object('IP::Geolocation::MMDB', 1) ) {
        $db = IP::Geolocation::MMDB->new(
            file => q{/htapps/babel/geoip/GeoIP2-Country.mmdb} );
        $C->set_object('IP::Geolocation::MMDB', $db);
    }

    return $db;
}

package Utils::GeoIP::Info;

use IP::Geolocation::MMDB;

use RightsGlobals;

sub new {
    my $class = shift;
    my ( $db, $ip_addr ) = @_;

    my $self = { ip_addr => $ip_addr };

    $$self{country_code} = $db->getcc($ip_addr);

    bless $self, $class;
}

sub country_code {
    my $self = shift;
    return $$self{country_code};
}

sub is_US {
    my $self = shift;
    return ( grep(/^$$self{country_code}$/, @RightsGlobals::g_pdus_country_codes) )  
}

package Utils::GeoIP::Info::Null;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
}

sub country_code {
    return "";
}

sub is_US {
    return 0;
}


1;