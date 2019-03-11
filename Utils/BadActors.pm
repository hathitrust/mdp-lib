package Utils::BadActors;

use CGI;

sub heal_and_redirect_requests
{
    my $redirect_url;
    my $incoming_qs = $ENV{QUERY_STRING};
    if ( $ENV{QUERY_STRING} =~ m,\%3[BD],  ) {
        # bad google/facebook encoding
        # strip any trailing %3Ds first
        $ENV{QUERY_STRING} =~ s{%3Bview$}{};
        $ENV{QUERY_STRING} =~ s{\%3D$}{};
        $ENV{QUERY_STRING} =~ s{\%3B$}{;};
        $ENV{QUERY_STRING} =~ s{\%3D}{=}g;
        $ENV{QUERY_STRING} =~ s{\%3B([a-z0-9]+)=}{;$1=}gs;
        $redirect_url = qq{$ENV{SCRIPT_URI}?$ENV{QUERY_STRING}};
    }

    if ( $redirect_url && $redirect_url ne qq{$ENV{SCRIPT_URI}?$incoming_qs} ) {
        my $cgi = new CGI;
        print $cgi->redirect(-uri => $redirect_url, -status => 301);
        exit;
    }
}

BEGIN {
	heal_and_redirect_requests();
}

1;