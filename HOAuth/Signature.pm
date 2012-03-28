package HOAuth::Signature;

=head1 NAME

HOAuth::Signature

=head1 DESCRIPTION

This package contains an interface to 2-legged oauth signing and
signature validation logic required to secure a resource request from
the HathiTrust Data API and the like.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use URI;
use CGI;

use OAuth::Lite::Consumer;
use OAuth::Lite::ServerUtil;

use HOAuth::Keys;

# ---------------------------------------------------------------------

=item S_get_signed_request_URL

Instantiate a consumer that can sign our request for us.

unsigned_url = everthing before the query string
extra = hash ref to query string

=cut

# ---------------------------------------------------------------------
sub S_get_signed_request_URL {
    my ($unsigned_url, $access_key, $secret_key, $request_method, $extra) = @_;

    my $key_pair = HOAuth::Keys::make_key_pair_from($access_key, $secret_key);

    my %args = (
                consumer_key    => $key_pair->token,
                consumer_secret => $key_pair->secret,
                auth_method     => OAuth::Lite::AuthMethod::URL_QUERY,
               );

    my $signing_agent = OAuth::Lite::Consumer->new(%args);
        
    my $query = $signing_agent->gen_auth_query($request_method, $unsigned_url, undef, $extra);
    my $signed_url = $unsigned_url . '?' . $query;
    
    return $signed_url;
}

# ---------------------------------------------------------------------

=item S_validate

Validate a signed URL

=cut

# ---------------------------------------------------------------------
sub S_validate {
    my ($signed_url, $access_key, $secret_key, $request_method, $extra) = @_;

    my $uri = URI->new($signed_url);
    my %params = CGI->new($uri->query)->Vars;

    my $util = OAuth::Lite::ServerUtil->new;
    $util->support_signature_method('HMAC-SHA1');
    
    $util->allow_extra_params(keys %$extra);

    unless ($util->validate_params(\%params)) {
        return (0, $util->errstr);
    }

    my $key_pair = HOAuth::Keys::make_key_pair_from($access_key, $secret_key);

    if (! $util->verify_signature(
                                  method          => $request_method,
                                  params          => \%params,
                                  url             => $signed_url,
                                  consumer_secret => $key_pair->secret,
                                 )) {
        return (0, $util->errstr);
    }
    
    return (1, undef);
}

1;

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012 ©, The Regents of The University of Michigan, All Rights Reserved

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

Copyright 2009 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file
except in compliance with the License. A copy of the License is located at

      http://aws.amazon.com/apache2.0/

or in the "LICENSE.txt" file accompanying this file. This file is distributed on an "AS IS"
BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations under the License.

=cut

