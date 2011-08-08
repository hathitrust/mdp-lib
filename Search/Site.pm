package Search::Site;


=head1 NAME

Search::Site;

=head1 DESCRIPTION

This non-OO package privides and API to get site information.

=head1 VERSION

$Id: Site.pm,v 1.6 2009/03/13 17:47:01 pfarber Exp $

=head1 SYNOPSIS

use Search:SIte;

=head1 METHODS

=over 8

=cut

BEGIN
{
    if ($ENV{'HT_DEV'})
    {
        require "strict.pm";
        strict::import();
    }
}

use MdpConfig;

my $SITE_ADDR = `hostname -i`;
my $DEFAULT_SITE = 'macc';

# Class B IP address <-> site name map.  These are the addresses of
# servers running cronjobs to sniff the m_index_queue table.
my %ipaddr_2_site_names =
    (
     '141.211' => 'macc',
     '141.213' => 'macc',
     '134.68'  => 'ictc',
    );

# ---------------------------------------------------------------------

=item get_server_site_name

Description

=cut

# ---------------------------------------------------------------------
sub get_server_site_name
{
    my ($server_class_B_addr) = ($SITE_ADDR =~ m,(\d+\.\d+).+,);
    my $site = $ipaddr_2_site_names{$server_class_B_addr};
    $site = $site ? $site : 'none';
    
    return $site;
}

# ---------------------------------------------------------------------

=item get_site_names

Description

=cut

# ---------------------------------------------------------------------
sub get_site_names {
    if ($ENV{HT_DEV}) {
        return $DEFAULT_SITE;
    }
    
    # Unique
    my %saw;
    @saw{values(%ipaddr_2_site_names)} = ();
    return keys %saw; 
}





1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2009 ©, The Regents of The University of Michigan, All Rights Reserved

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
