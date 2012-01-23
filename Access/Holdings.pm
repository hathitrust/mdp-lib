package Access::Holdings;

=head1 NAME

Access::Holdings;

=head1 DESCRIPTION

This package provides an interface to the Holdings Database tables (mdp-holdings.)

=head1 SYNOPSIS

=head1 METHODS

=over 8

=cut

use Context;
use Utils;
use DbUtils;
use Debug::DUtils;

# ---------------------------------------------------------------------

=item id_is_held

Description

=cut

# ---------------------------------------------------------------------
sub id_is_held {
    my ($C, $id, $inst) = @_;

    my $held = 0;

    if (DEBUG('held')) {
        $held = 1;
    }
    elsif (DEBUG('notheld')) {
        $held = 0;
    }
    else {
        my $dbh = $C->get_object('Database')->get_DBH($C);

        my $SELECT_clause = 
          qq{SELECT copy_count FROM mdp_holdings.htitem_htmember_jn WHERE volume_id=? AND member_id=?};
        my $sth = DbUtils::prep_n_execute($dbh, $SELECT_clause, $id, $inst);
        $held = $sth->fetchrow_array();
    }
    DEBUG('auth,all,held,notheld', qq{<h4>Holdings for inst=$inst id="$id": held=$held</h4>});
    
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
