package MBooks::Searcher::FullText;

=head1 NAME

MBooks::Searcher::FullText (searcher)

=head1 DESCRIPTION

This class does X.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use Search::Searcher;
use base qw(Search::Searcher);

use MBooks::Result::FullText;
use MBooks::Query::FullText;


# ---------------------------------------------------------------------

=item PUBLIC: get_populated_Solr_query_result

Description

=cut

# ---------------------------------------------------------------------
sub get_populated_Solr_query_result
{
    my $self = shift;
    my ($C, $Q, $rs) = @_;

    my $query_string = $Q->get_Solr_query_string($C);

    return $self->__Solr_result($C, $query_string, $rs);
}

# ---------------------------------------------------------------------

=item get_Solr_internal_query_result

Description

=cut

# ---------------------------------------------------------------------
sub get_Solr_internal_query_result
{
    my $self = shift;
    my ($C, $Q, $rs) = @_;    

    my $query_string = $Q->get_Solr_internal_query_string();
    return $self->__Solr_result($C, $query_string, $rs);
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
