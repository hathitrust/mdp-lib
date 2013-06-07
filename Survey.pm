package Survey;


=head1 NAME

Survey

=head1 DESCRIPTION

This package implements an interface to the ht_survey database to
support a UI element in Collection Builder when the user is in a
collection that has a survey and when the user is in pageturner and
the item being viewed is in a collection that has a survey.

=head1 SYNOPSIS

my $mb_survey_text = Survey::get_survey_by_collid($C, $dbh, $collid);
my $pt_survey_text = Survey::get_survey_by_itemid($C, $dbh, $itemid);

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use Context;
use Database;
use DbUtils;
use Debug::DUtils;


# ---------------------------------------------------------------------

=item get_survey_by_itemid

Description

=cut

# ---------------------------------------------------------------------
sub get_survey_by_itemid {
    my ($C, $dbh, $itemid) = @_;
    
    my $always_show = DEBUG('survey');    
    my $date_clause = $always_show ? '' : qq{ AND ht_survey.effective_date >= NOW() AND ht_survey.expires_date < NOW()};
                       
    my $statement = qq{SELECT ht_survey.* FROM ht_survey, mb_coll_item
                       WHERE mb_coll_item.extern_item_id = ? 
                       AND ht_survey.MColl_ID = mb_coll_item.MColl_ID} . $date_clause;

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $itemid);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}


# ---------------------------------------------------------------------

=item get_survey_by_collid

Description

=cut

# ---------------------------------------------------------------------
sub get_survey_by_collid {
    my ($C, $dbh, $collid) = @_;

    my $always_show = DEBUG('survey');    
    my $date_clause = $always_show ? '' : qq{ AND ht_survey.effective_date >= NOW() AND ht_survey.expires_date < NOW()};
                       
    my $statement = qq{SELECT ht_survey.* FROM ht_survey
                       WHERE ht_survey.MColl_ID = ?} . $date_clause;

    my $sth = DbUtils::prep_n_execute($dbh, $statement, $collid);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}



1;

__END__

=back

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2013 ©, The Regents of The University of Michigan, All Rights Reserved

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
