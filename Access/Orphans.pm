package Access::Orphans;

=head1 NAME

Access::Orphans

=head1 DESCRIPTION

This package provides an interface to the list of institutions with Orphans Agreements

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use Context;
use Utils;
use RightsGlobals;
use Debug::DUtils;

my @ORPHAN_AGREEMENT_INSTITUTIONS = ();

# ---------------------------------------------------------------------

=item institution_agreement

Description

=cut

# ---------------------------------------------------------------------
sub institution_agreement {
    my ($C, $inst) = @_;
    
    my $agreed = 0;
    
    if (DEBUG('agree')) {
        $agreed = 1;
    }
    elsif (DEBUG('notagree')) {
        $agreed = 0;
    }
    else {
        # lazy
        if (! scalar(@ORPHAN_AGREEMENT_INSTITUTIONS)) {
            __load_agreed_institutions($C);
        }
        
        $agreed = grep(/^$inst$/, @ORPHAN_AGREEMENT_INSTITUTIONS);
    }
    DEBUG('auth,all,agree,notagree', qq{<h4>Orphan agreement for inst=$inst: agreed=$agreed</h4>});

    return $agreed;
}

sub __load_agreed_institutions {
    my $C = shift;

    my $ag_institution_file = qq{$ENV{SDRROOT}/common/web/orphan-agreement-inst-list.txt};
    my $txt_ref = Utils::read_file($ag_institution_file);
    @ORPHAN_AGREEMENT_INSTITUTIONS = split(/\n/, $$txt_ref);
    @ORPHAN_AGREEMENT_INSTITUTIONS = grep(! /^\s*$/, @ORPHAN_AGREEMENT_INSTITUTIONS)
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
