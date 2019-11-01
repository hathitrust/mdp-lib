package Access::Proxy;

=head1 NAME

Access::Proxy

=head1 DESCRIPTION

This package provides an interface to a service that attempts to
determine whether a request originates frm a proxy.  Used to control
access pt pdus volumes.

Depends on DNS caching and time-to-live to manage repeated requests on
the same IP address.

Depends on Net::DNS::tcp_timeout to set a timeout

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use DBI;
use Net::DNS;
use Debug::DUtils;

my $resolver = new Net::DNS::Resolver;

# Default send() is UDP (datagram) unless $resolver->usevc(1). However
# there seem to be codepaths that will forct TCP so set tcp_timeout
# too
$resolver->udp_timeout(1);
$resolver->tcp_timeout(1);
$resolver->retrans(0);
$resolver->retry(0);

my %blacklist_services =
  (
#   '__IPADDRESS__.cbl.abuseat.org' => '127.0.0.2',
#   '__IPADDRESS__.dnsbl.njabl.org' => '127.0.0.9',
   '__IPADDRESS__.__PORT__.__SERVER__.ip-port.exitlist.torproject.org' => '127.0.0.2',
  );

# Eliminate some calls out to DNS
my %ip_address_cache = ();

sub blacklisted {
    my ($dbh, $ip_addr, $server_addr, $port) = @_;

    # Check cache
    if (defined $ip_address_cache{$ip_addr}) {
        DEBUG('proxy', qq{<pre>return cached blacklist=$blacklist</pre>});
        return $ip_address_cache{$ip_addr};
    }
    
    # Check database
    my $blacklist = __bl_check_db($dbh, $ip_addr);

    # Check services if passed database check
    if (! $blacklist) {
        $blacklist = __bl_check_services($ip_addr, $server_addr, $port);
    }

    # Cache
    $ip_address_cache{$ip_addr} = $blacklist;
    DEBUG('proxy', qq{<pre>set cache blacklist=$blacklist</pre>});
    
    return $blacklist;
}

sub __bl_check_db {
    my ($dbh, $ip_addr) = @_;

    my $blacklist = 0;

    my $statement = qq{SELECT ip FROM ht_proxies WHERE ip='$ip_addr'};
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
    return 1 if (defined $ENV{TEST_BLACKLIST});

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

        my $query = $resolver->query($service);
        DEBUG('proxy',
              sub {
                  require Data::Dumper;
                  my $d = Data::Dumper::Dumper($query);
                  my $retry = $resolver->retry;
                  my $retrans = $resolver->retrans;
                  "<pre>Service: $service ::: " . $d . " retries=$retry retrans=$retrans</pre>";
              });

        eval {
            if (defined $query) {
                my $answer = $query->{answer}[0];
                if (defined $answer) {
                    my $address = $answer->address;
                    if ($address eq $blacklist_services{$serv}) {
                        $blacklist = 1;
                        last;
                    }
                }
            }
        };

# Previously:
#         my $response = (gethostbyname($service))[4];
#         if (length($response) > 0) {
#             $response = inet_ntoa($response);
#
#             if ($response eq $blacklist_services{$serv}) {
#                 $blacklist = 1;
#                 last;
#             }
#         }
    }
    return 1 if (defined $ENV{TEST_BLACKLIST});

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

Copyright 2011-12 ©, The Regents of The University of Michigan, All Rights Reserved

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
