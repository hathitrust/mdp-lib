package Vendors;

use CGI;
use FindBin qw($Bin);
use File::Basename;

my @my_inc = ();
our $__loaded = 0;

sub import {
    my ( $pkg, $filepath ) = @_;
    my $binpath;
    if ( $filepath ) {
        $binpath = dirname($filepath);
    } else {
        $binpath = $Bin;
    }
    init($binpath);
}

sub init {
    my ( $Bin ) = @_;

    return if ( $__loaded );
    $__loaded = 1;

    if ( -d "$Bin/../lib" ) {
        push(@my_inc, "$Bin/../lib");
    }

    my $local_switch = 0;
    if ( -f "$Bin/../lib/Config/local.conf" ) {
        local $/;
        open(my $IN, "$Bin/../lib/Config/local.conf");
        my $tmp = <$IN>;
        close($IN);
        $local_switch = $tmp =~ m/^debug_local\s+=\s+1/gsm;
    }
    $local_switch = $local_switch || $ENV{DEBUG_LOCAL} || ($ENV{REQUEST_METHOD} ne 'POST' && CGI::param('debug') && (CGI::param('debug') =~ m,local,));
    if ($local_switch) {
        push(@my_inc, "$ENV{SDRROOT}/mdp-lib");
        $ENV{DEBUG_LOCAL} = 1;
        $ENV{DEBUG} .= ',' if ( $ENV{DEBUG} );
        $ENV{DEBUG} .= 'local';
    }

    if ( -d "$Bin/../vendor" ) {
        opendir(VENDOR, "$Bin/../vendor");
        foreach my $repo ( grep(! /^(\.|\.\.)$/, readdir(VENDOR)) ) {
            if ( -d "$Bin/../vendor/$repo/lib" ) {
                if ($local_switch){
                    if ( -d "$Bin/../../$repo") {
                        push(@my_inc, "$Bin/../../$repo");
                    }
                }
                else {
                    push(@my_inc, "$Bin/../vendor/$repo/lib");
                }
            }
        }
    }

    unshift(@INC, @my_inc);
}

1;

__END__

=head1 NAME

Vendors

=head1 DESCRIPTION

This package encapsulates code using FindBin to build a list of paths
containing 'lib/' so the calling script can find libraries,
Rails-style.

It essentially adds the following for each dir* to @INC

qw( lib vendor/dir1/lib vendor/dir2/lib vendor/dir3/foo/lib ... )

for as many subdirectories of vendor as exist containing lib plus the
lib sibling of cgi in the HTDE directory hierarchy scheme.

NOTE: it is possible to insert the entire directory tree for app1 as a
submodule in $SDRROOT/app2/vendor/"app1"/lib. In that case
the $SDRROOT/app1/lib would be added to the @INC for app2, in effect, sharing
some of app1's lib code with app2.

DEVELOPMENT NOTE: If the development of app1 involves development of
mdp-lib code, it is cumbersome to get the mdp-lib code changes into
the $SDRROOT/app1/vendor/common-lib/lib directory, e.g. for foo.pm:

1) stage and commit foo.pm to local mdp-lib local repo
2) push local change to repos/mdp-lib.git central repo
3) cd app1/vendor/common-lib/lib && pull

This forces commits just to run app1 for unit testing.

Vendors.pm has a debug switch to short-cut this process. If
debug=local is set, $SDRROOT/mdp-lib is added to @INC before the
vendor libs.  The app code will see code in $SDRROOT/mdp-lib before it
sees the app/vendor submodule code.

=head1 SYNOPSIS

BEGIN {
    use lib "$ENV{SDRROOT}/mdp-lib/Utils";
    use Vendors;
}

=head1 AUTHORS

Phillip Farber, University of Michigan, pfarber@umich.edu
based on work by Roger Espinoza, University of Michigan, roger@umich.edu

=head1 COPYRIGHT

Copyright 2010 ©, The Regents of The University of Michigan, All Rights Reserved

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
