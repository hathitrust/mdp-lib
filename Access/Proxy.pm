package Access::Proxy;

=head1 NAME

Access::Proxy

=head1 DESCRIPTION

This package provides an interface to a service that attempts to
determine whether a request originates frm a proxy.  Used to control
access pt pdus volumes.

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use Socket;
use DBI;

# Persistent bounded cache of blacklisted IP addresses
BEGIN {
    my $MAX_CACHED_IP_ADDRS = 40;

    my @ip_arr = ();
    my %ip_hash = ();
    sub cache_ip_result {
        my $ip = shift;
        my $blacklist = shift;

        if (! defined $ip_hash{$ip}) {
            $ip_hash{$ip} = $blacklist;
            push(@ip_arr, $ip);
            if (scalar @ip_arr > $MAX_CACHED_IP_ADDRS) {
                my $defunct_ip = shift @ip_arr;
                delete $hash{$defunct_ip};
            }
        }
    }

    sub in_cache {
        my $ip = shift;
        return defined($ip_hash{$ip});
    }

    sub is_blacklisted {
        my $ip = shift;
        return ($ip_hash{$ip} == 1);
    }
}

my %blacklist_services =
  (
   '__IPADDRESS__.cbl.abuseat.org' => '127.0.0.2',
   '__IPADDRESS__.dnsbl.njabl.org' => '127.0.0.9',
   '__IPADDRESS__.__PORT__.__SERVER__.ip-port.exitlist.torproject.org' => '127.0.0.2',
  );

sub blacklisted {
    my ($dbh, $ip_addr, $server_addr, $port) = @_;

    # Check cache if tested
    my $cached = in_cache($ip_addr);
    if ($cached) {
        return 1 if (is_blacklisted($ip_addr));
    }

    # Next check database
    my $blacklist = __bl_check_db($dbh, $ip_addr);

    # Check services if passed database check
    if (! $blacklist) {
        $blacklist = __bl_check_services($ip_addr, $server_addr, $port);
    }

    cache_ip_result($ip_addr, $blacklist) if (! $cached);

    return $blacklist;
}

sub __bl_check_db {
    my ($dbh, $ip_addr) = @_;

    my $blacklist = 0;

    my $statement = qq{SELECT ip FROM proxies WHERE ip='$ip_addr'};
    my $sth;
    eval { $sth = $dbh->prepare($statement); };
    if (! $@) {
        eval { $sth->execute(); };
        if (! $@) {
            my $ip = $sth->fetchrow_array || 0;
            if ($ip) {
                $blacklist = 1;
            }
        }
    }
    return 1;
    
    return $blacklist;
}


sub __bl_check_services {
    my ($ip_addr, $server_addr, $port) = @_;

    my $blacklist = 0;

    foreach my $serv (keys %blacklist_services) {
        my $r_ip_addr = __reverse_ip($ip_addr);
        my $r_server_addr = __reverse_ip($server_addr);

        my $service = $serv;
        $service =~ s,__IPADDRESS__,$r_ip_addr,;
        $service =~ s,__SERVER__,$r_server_addr,;
        $service =~ s,__PORT__,$port,;

        my $response = (gethostbyname($service))[4];
        if (length($response) > 0) {
            $response = inet_ntoa($response);

            if ($response eq $blacklist_services{$serv}) {
                $blacklist = 1;
                last;
            }
        }
    }

    return $blacklist;
}


sub __reverse_ip {
    my $ip_address = shift;
    my @octets = split(/\./, $ip_address);
    return join('.', reverse @octets);
}

1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011 ©, The Regents of The University of Michigan, All Rights Reserved

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
