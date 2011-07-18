=head1 NAME

PUB_COLL_LINK.pm

=head1 DESCRIPTION

This a single PI package which consists of "packageless" shared
methods that become methods in the package into which they are
"require"d.

=head1 SYNOPSIS

BEGIN
{
    require "PIFiller/Common/PUB_COLL_LINK.pm";
}

see also package with the naming convention Group_*.pm

=head1 METHODS

=over 8

=cut



# ---------------------------------------------------------------------

=item handle_PUB_COLL_LINK_PI : PI_handler(PUB_COLL_LINK)

Handler for PUB_COLL_LINK

=cut

# ---------------------------------------------------------------------
sub handle_PUB_COLL_LINK_PI
    : PI_handler(PUB_COLL_LINK)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $debug = $C->get_object('CGI')->param('debug');
    my $params = $C->get_object('MdpConfig')->get('list_colls_base_params');
    $params .= ";colltype=all;debug=$debug";

    my $pub_coll_url;
    my $auth = $C->get_object('Auth');
    if ($auth->auth_sys_is_SHIBBOLETH($C)) {
        $pub_coll_url = qq{/shcgi/mb?$params};
    }
    else {
        $pub_coll_url = qq{/cgi/mb?$params};
    }

    return $pub_coll_url;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007 ©, The Regents of The University of Michigan, All Rights Reserved

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
