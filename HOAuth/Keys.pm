package HOAuth::Keys;

=head1 NAME

HOAuth::Keys

=head1 DESCRIPTION

This package contains the KGS Key Generation routines.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;
use OAuth::Lite::Util qw(gen_random_key);
use OAuth::Lite::Token;

my $DEBUG = 0;

use constant ACCESS_KEY_NUM_BYTES => 5;
use constant SECRET_KEY_NUM_BYTES => 14;


# ---------------------------------------------------------------------

=item make_random_key_pair

Description

=cut

# ---------------------------------------------------------------------
sub make_random_key_pair {
    my $token = new OAuth::Lite::Token;
    $token->token(gen_random_key(ACCESS_KEY_NUM_BYTES));
    $token->secret(gen_random_key(SECRET_KEY_NUM_BYTES));

    return $token;
}

# ---------------------------------------------------------------------

=item make_key_pair_from

Description

=cut

# ---------------------------------------------------------------------
sub make_key_pair_from {
    my ($access_key, $secret_key) = @_;

    my $token = new OAuth::Lite::Token;
    $token->token($access_key);
    $token->secret($secret_key);
    
    return $token;
}

sub __x_debug {
    if ($DEBUG) { print STDERR shift }
}


1;

__END__

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

=cut
