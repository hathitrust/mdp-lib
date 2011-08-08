package Search::Result::SLIP_Raw;

=head1 NAME

Result::SLIP_Raw (rs)

=head1 DESCRIPTION

This class does encapsulates the raw Solr search response data.

=head1 VERSION

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


use strict;
use base qw(Search::Result);

# ---------------------------------------------------------------------

=item AFTER_Result_initialize

Subclass Initialize Result::SLIP object.

=cut

# ---------------------------------------------------------------------
sub AFTER_Result_initialize {
    my $self = shift;
}

# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

Example Solr result is anything

<response>
  <lst name="responseHeader">
    <int name="status">0</int>
    <int name="QTime">1</int>
  </lst>
  <result name="response" numFound="3" start="0" maxScore="0.02694472">
    <doc>
       [ ... ]
    </doc>

    [...]
  </result>
</response>


=cut

# ---------------------------------------------------------------------
sub AFTER_ingest_Solr_search_response {
    my $self = shift;
    my $Solr_response_ref = shift;

    my @result_docs = ($$Solr_response_ref =~ m,<doc>(.*?)</doc>,gs);
    @result_docs = map { '<doc>' . $_ . '</doc>' } @result_docs;

    $self->__set_result_docs(\@result_docs);
    $self->__set_rows_returned(scalar @result_docs);
}


# ---------------------------------------------------------------------

=item PRIVATE: __set_result_docs

Description

=cut

# ---------------------------------------------------------------------
sub __set_result_docs {
    my $self = shift;
    my $arr_ref = shift;
    $self->{'result_response_docs_arr_ref'} = $arr_ref;
}

# ---------------------------------------------------------------------

=item PRIVATE: __set_rows_returned

Description

=cut

# ---------------------------------------------------------------------
sub __set_rows_returned {
    my $self = shift;
    my $rows = shift;
    $self->{'rows_returned'} = $rows;
}

# ---------------------------------------------------------------------

=item get_result_docs

Description

=cut

# ---------------------------------------------------------------------
sub get_result_docs {
    my $self = shift;
    return $self->{'result_response_docs_arr_ref'};
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
