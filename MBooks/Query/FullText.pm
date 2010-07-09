package MBooks::Query::FullText;


=head1 NAME

MBooks::Query::FullText (Q)

=head1 DESCRIPTION

This class subclasses Search::Query

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use Utils;
use Debug::DUtils;
use Collection;
use base qw(Search::Query);


# ---------------------------------------------------------------------

=item AFTER_Query_initialize

Initialize MBooks::Query::FullText after base class.  Use Template
Design Pattern.

=cut

# ---------------------------------------------------------------------
sub AFTER_Query_initialize
{
    my $self = shift;
    my $C = shift;
    my $internal = shift;

    if (! $internal)
    {
        $self->get_ids_f_standard_user_query($C);
    }
}

# ---------------------------------------------------------------------

=item get_ids_f_standard_user_query

Construct filter query id array for the normal case (as opposed to
internal queries)

=cut

# ---------------------------------------------------------------------
sub get_ids_f_standard_user_query
{
    my $self = shift;
    my $C = shift;

    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');

    my $id_arr_ref;

    my $config = $C->get_object('MdpConfig');
    my $style = $config->get('mbooks_filter_query_style');

    if ($style eq 'coll_id')
    {
        $id_arr_ref = [$coll_id];
    }
    elsif ($style eq 'item_id')
    {
        my $co = $C->get_object('Collection');
        $id_arr_ref = $co->get_item_ids_for_coll($coll_id);
    }
    else
    {
        ASSERT(0, qq{Invalid style="$style"});
    }

    $self->{'id_arr_ref'} = $id_arr_ref;
}

# ---------------------------------------------------------------------

=item get_id_arr_ref

Description

=cut

# ---------------------------------------------------------------------
sub get_id_arr_ref
{
    my $self = shift;
    return $self->{'id_arr_ref'};
}

# ---------------------------------------------------------------------

=item get_Solr_query_string

Description

=cut

# ---------------------------------------------------------------------
sub get_Solr_query_string
{
    my $self = shift;
    my $C = shift;

    # Massage the raw query string from the user
    my $user_query_string = $self->get_processed_user_query_string();

    # The common Solr query parameters
    my $USER_Q = qq{q=$user_query_string};
    my $FL = qq{&fl=id,score};
    my $VERSION = qq{&version=} . $self->get_Solr_XmlResponseWriter_version();
    my $START_ROWS = qq{&start=0&rows=1000000};
    my $INDENT = qq{&indent=off};

    # a Solr Filter Query to limit to the collections containing the
    # ids requested or to limit to the collection field itself
    my $config = $C->get_object('MdpConfig');
    my $style = $config->get('mbooks_filter_query_style');

    my $FQ;
    if ($style eq 'coll_id')
    {
        $FQ = $self->get_coll_id_FQ();
    }
    elsif ($style eq 'item_id')
    {
        $FQ = $self->get_id_FQ();
    }

    # q=dog*&fl=id,score&fq=coll_id:(276+42)&$version=2.2,&start=0&rows=1000000&indent=off
    # q=dog*&fl=id,score&fq=id:(1+334334+234576+4346752)&$version=2.2,&start=0&rows=1000000&indent=off
    my $solr_query_string =
        $USER_Q . $FL . $FQ . $VERSION . $START_ROWS . $INDENT;

    DEBUG('all,query', qq{Solr query="$solr_query_string"});

    return $solr_query_string;
}


# ---------------------------------------------------------------------

=item get_id_FQ

Description

=cut

# ---------------------------------------------------------------------
sub get_id_FQ
{
    my $self = shift;

    # a Solr Filter Query to limit to the collections containing the ids requested
    my $id_arr_ref = $self->get_id_arr_ref();
    ASSERT((scalar(@$id_arr_ref) > 0),
           qq{Missing id values for id filter query (fq) construction});

    my $fq_args = join('+', @$id_arr_ref);
    my $FQ = qq{&fq=id:($fq_args)};

    return $FQ;
}

# ---------------------------------------------------------------------

=item get_coll_id_FQ

Description

=cut

# ---------------------------------------------------------------------
sub get_coll_id_FQ
{
    my $self = shift;

    # a Solr Filter Query to limit to the collections containing the ids requested
    my $coll_id_arr_ref = $self->get_id_arr_ref();
    ASSERT((scalar(@$coll_id_arr_ref) > 0),
           qq{Missing coll_id values for coll_id filter query construction});

    my $fq_args = join('+', @$coll_id_arr_ref);
    my $FQ = qq{&fq=coll_id:($fq_args)};

    return $FQ;
}

# ---------------------------------------------------------------------

=item get_Solr_internal_query_string

Expects a well-formed Lucene query from the calling code

=cut

# ---------------------------------------------------------------------
sub get_Solr_internal_query_string
{
    my $self = shift;

    # Solr right stemmed query strings have to be lowercase
    my $query_string = lc($self->get_query_string());

    my $INTERN_Q = qq{q=$query_string};
    my $FL = qq{&fl=*,score};
    my $VERSION = qq{&version=} . $self->get_Solr_XmlResponseWriter_version();
    my $START_ROWS = qq{&start=0&rows=1000000};
    my $INDENT = qq{&indent=off};

    # q=id:123&fl=*,score&$version=2.2,&start=0&rows=1000000&indent=off
    my $solr_query_string =
        $INTERN_Q . $FL . $VERSION . $START_ROWS . $INDENT;

    return $solr_query_string;
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
