package Access::Orphans;

=head1 NAME

Access::Orphans

=head1 DESCRIPTION

This package provides an interface to the Orphans Agreement Database table (mdp.orph_agree)

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use Context;
use Utils;
use DbUtils;

my %agreement_cache = ();

# ---------------------------------------------------------------------

=item institution_agreement

Description

=cut

# ---------------------------------------------------------------------
sub institution_agreement {
    my ($C, $inst) = @_;

    if (defined $agreement_cache{$inst}) {
        return  $agreement_cache{$inst};
    }
    
    my $dbh = $C->get_object('Database')->get_DBH($C);

    my $SELECT_clause = 
      qq{(SELECT count(*) FROM orph_agree where inst='$inst'};
    my $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause);
    my $count = $sth->fetchrow_array();
    my $held = ($count > 0);
    
    $agreement_cache{$inst} = $held;  

    return $held;
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
