package Search::XPat::ResultSet;

=head1 NAME

Search::XPat::ResultSet

=head1 DESCRIPTION

This class is a simplified version of DLXS XPatResultSet.pm

=head1 VERSION

$Id: ResultSet.pm,v 1.1 2007/12/10 20:55:38 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

BEGIN
{
    if ($ENV{'HT_DEV'})
    {
        require "strict.pm";
        strict::import();
    }
}



use Search::XPat::Result;
use Search::XPat::Simple;

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize Search::XPat::ResultSet

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my $name = shift;

    $self->{'name'} = $name;

    $self->set_iterator_indx_to(0);

    $self->{'iterator'} = undef;
    $self->{'stats'} = undef;
    $self->{'setsearches'}= undef;
}


# ---------------------------------------------------------------------

=item add_result_object

Add an xro

=cut

# ---------------------------------------------------------------------
sub add_result_object
{
    my $self = shift;
    my $xro = shift;

    # type is SSize, PSet or RSet
    # result is result from XPat
    # $label is same label as was sent by AddSearchSet
    my ($type, $label, $xpat) = (
                                   $xro->get_type(),
                                   $xro->get_label(),
                                   $xro->get_xpat_object()
                                 );

    my $dd = $xpat->get_data_dict_name('t');

    if ($type eq 'SSize')
    {
        # SSize type results:
        # size searches are sorted by dd file name
        my $num = $xro->get_SSize_result();

        if ($label =~ m,hitssearch,)
        {
            # keep track of number of hits by index
            $self->__add_hits($num, $dd);
        }
        elsif ($label =~ m,recordssearch,)
        {
            # keep track of number of records by index
            $self->__add_records($num, $dd);
        }
        elsif ($label =~ m,detailhitsinitemsearch,)
        {

            # This is the count of hits in a single item either for
            # terms in a boolean region search or of hits in a simple
            # search
            $self->__add_item_hits($num, $dd);
        }
    }
    elsif ($type eq 'Error')
    {    }
    else
    {
        # RSet or PSet possibly in byte mode
        my $hit_info_array_ref = $xro->get_results_as_array_ref();

        $self->__add_result_count(scalar(@$hit_info_array_ref), $dd);

        for (my $i=0; $i < scalar(@$hit_info_array_ref); $i++)
        {
            my ($start, $raw, $rawsize) =
                (
                 $$hit_info_array_ref[$i][0],
                 $$hit_info_array_ref[$i][1],
                 $$hit_info_array_ref[$i][2],
                );

            $self->{'setsearches'}{$start} =
            {
             'start'   => $start,
             'raw'     => $raw,
             'rawsize' => $rawsize,
             'label'   => $label,
             'type'    => qq{$type Raw},
             'xpat'    => $xpat,
            };
        }

    }
}

# ---------------------------------------------------------------------

=item init_iterator

Description

=cut

# ---------------------------------------------------------------------
sub init_iterator
{
    my $self = shift;

    $self->set_iterator_indx_to(0);

    # Make init_iterator idempotent so that several calls to
    # init_iterator will not redo the following computationally
    # intensive code
    return if ($self->{'iteratorinitialized'});

    # otherwise, loop by label, push all byte/label pairs into an
    # array then sort numeric by byte:
    my @item_array = ();

    foreach my $start (keys % {$self->{'setsearches'}})
    {
        push (@item_array, [
                            $self->{'setsearches'}{$start}{'label'},
                            $self->{'setsearches'}{$start}{'raw'},
                            $start,
                            $self->{'setsearches'}{$start}{'xpat'},
                           ]
            );
    }

    # sort the items by byte offset if indicated
    @item_array = sort {$$a[2] <=> $$b[2]} @item_array;

    $self->{'iteratorinitialized'} = 1;

    $self->{'iterator'} = \@item_array;
}


# ---------------------------------------------------------------------

=item get_results_as_array_ref

Description

=cut

# ---------------------------------------------------------------------
sub get_results_as_array_ref
{
    my $self = shift;
    ASSERT($self->{'iteratorinitialized'}, qq{Result iterator not initialized});
    return $self->{'iterator'};
}


# ---------------------------------------------------------------------

=item get_Next_result

Description

=cut

# ---------------------------------------------------------------------
sub get_Next_result
{
    my $self = shift;

    my $itemArrayRef = $self->{'iterator'};
    my $index = $self->get_iterator_indx();

    my @returnArray;

    # see if we are out of bounds
    if ($index >= scalar(@{$itemArrayRef}))
    {
        @returnArray = (undef, undef, undef, undef);
    }
    else
    {
        # otherwise, all is okay return next item's information this
        # should return a label and a byte offset it is a
        # dereferencing of the anonymous array in each element of the
        # @itemArray array
        my ($label, $raw, $start, $xpat) = @{$$itemArrayRef[$index]};

        @returnArray = ($label, $raw, $start, $xpat);

        # increment for next time
        $self->{'iteratorIndex'} += 1;
    }

    return @returnArray;
}


# ---------------------------------------------------------------------

=item get_result_at_indx

Description

=cut

# ---------------------------------------------------------------------
sub get_result_at_indx
{
    my $self = shift;
    my $index = shift;

    my $item_array_ref = $self->{'iterator'};

    my @return_array;

    # see if we are out of bounds
    if ($index >= scalar(@{ $item_array_ref }))
    {
        @return_array = (undef, undef, undef, undef);
    }
    # otherwise, all is okay return next item's information
    else
    {
        # this should return a label and a byte offset
        # it is a dereferencing of the anonymous array in each
        # element of the @item_array
        my ($label, $raw, $start, $xpat) = @{ $$item_array_ref[$index] };

        @return_array = ($label, $raw, $start, $xpat);
    }

    return @return_array;
}


# ---------------------------------------------------------------------

=item sniff_next_result

Description

=cut

# ---------------------------------------------------------------------
sub sniff_Next_result
{
    my $self = shift;

    my $item_array_ref = $self->{'iterator'};
    my $index = $self->get_iterator_indx();

    # see if we are out of bounds
    if ($index >= scalar(@{$item_array_ref}))
    {
        return (undef);
    }
    else
    {
        # all is okay return next item's label without incrementing
        # the index
        my ($label) = @{$$item_array_ref[$index]};

        return $label;
    }
}


# ---------------------------------------------------------------------

=item get_Next_labeled_result

Description

=cut

# ---------------------------------------------------------------------
sub get_Next_labeled_result
{
    my $self = shift;
    my $label = shift;

    my $item_array_ref;
    ASSERT($item_array_ref = $self->{'iterator'},
            qq{Error: RSET not initilalized});

    my $index = $self->get_iterator_indx();

    my $limit = scalar(@{$item_array_ref});

    # see if we are out of bounds
    ASSERT(($index < $limit),
            qq{iterator limit (} . ($limit-1) . qq{) exceeded.  This often means that an XPAT query produced no results.  Try debug=results to analyze the failed query.});

    # make copy of index
    for (my $i = $index; $i < $limit; $i++)
    {
        my ($label_at, $text_ref, $byte, $xpat) = $self->get_result_at_indx($i);
        if ($label_at =~ m,$label,)
        {
	    return ($text_ref, $byte, $xpat);
        }
    }

    # if here, never found label
    ASSERT(0, qq{Label="$label" not found});
}


# ----------------------------------------------------------------------
# NAME         : __add_hits
# PURPOSE      : keep track of number of hits per index (useful in slicing)
#
# CALLED BY    :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------

# ---------------------------------------------------------------------

=item __add_hits

keep track of number of hits per index (useful in slicing)

=cut

# ---------------------------------------------------------------------
sub __add_hits
{
    my $self = shift;
    my ($results, $dd) = @_;

    $self->{'stats'}{'dds'}{$dd}{'hits'} = $results;
    $self->{'stats'}{'totalhits'} += $results;
}


# ---------------------------------------------------------------------

=item __add_records

keep track of number of records per index (useful in slicing)

=cut

# ---------------------------------------------------------------------
sub __add_records
{
    my $self = shift;
    my ($results, $dd) = @_;

    $self->{'stats'}{'dds'}{$dd}{'records'} = $results;
    $self->{'stats'}{'totalrecords'} += $results;
}

# ---------------------------------------------------------------------

=item __add_result_count

keep track of number of results for any PSet or RSet type search

=cut

# ---------------------------------------------------------------------
sub __add_result_count
{
    my $self = shift;
    my ($resultCount, $dd) = @_;

    $self->{'stats'}{'dds'}{$dd}{'resultcount'} = $resultCount;
}

# ---------------------------------------------------------------------

=item __add_item_hits

keep track of number of hits in boolean region or in a simple search
(useful for slicing)

=cut

# ---------------------------------------------------------------------
sub __add_item_hits
{
    my $self = shift;
    my $results = shift;

    $self->{'stats'}{'itemhits'} = $results;
}



# ---------------------------------------------------------------------

=item get_hits

Description

=cut

# ---------------------------------------------------------------------
sub get_hits
{
    my $self = shift;
    my $dd = shift;

    return $self->{'stats'}{'dds'}{$dd}{'hits'};
}


# ---------------------------------------------------------------------

=item get_item_hits

Description

=cut

# ---------------------------------------------------------------------
sub get_item_hits
{
    my $self = shift;
    return $self->{'stats'}{'itemhits'};
}



# ---------------------------------------------------------------------

=item get_records

Description

=cut

# ---------------------------------------------------------------------
sub get_records
{
    my $self = shift;
    my $dd = shift;

    my $records = undef;

    if (! exists($self->{'stats'}) ||
        ! exists($self->{'stats'}{'dds'}) ||
        ! exists($self->{'stats'}{'dds'}{$dd}) ||
        ! exists($self->{'stats'}{'dds'}{$dd}{'records'})
       )
    {
    }
    else
    {         
        $records = $self->{'stats'}{'dds'}{$dd}{'records'};            
    }

    ASSERT(defined($records), qq{no records not defined});

    return $records;
}


# ---------------------------------------------------------------------

=item get_result_count

return the previously saved number of results for an RSet or PSet
result

=cut

# ---------------------------------------------------------------------
sub GetResultCount
{
    my $self = shift;
    my $dd = shift;

    my $result_count = undef;

    if (! exists($self->{'stats'}) ||
        ! exists($self->{'stats'}{'dds'}) ||
        ! exists($self->{'stats'}{'dds'}{$dd}) ||
        ! exists($self->{'stats'}{'dds'}{$dd}{'resultcount'})
       )
    {}
    else
    { 
        $result_count = $self->{'stats'}{'dds'}{$dd}{'resultcount'}; 
    }

    ASSERT(defined($result_count), qq{result count not defined});

    return $result_count;
}


# ---------------------------------------------------------------------

=item get_hits_total

Description

=cut

# ---------------------------------------------------------------------
sub get_hits_total
{
    my $self = shift;
    return $self->{'stats'}{'totalhits'};
}

# ---------------------------------------------------------------------

=item get_records_total

Description

=cut

# ---------------------------------------------------------------------
sub get_records_total
{
    my $self = shift;
    return $self->{'stats'}{'totalrecords'};
}


sub get_name
{
    my $self = shift;
    return $self->{'name'};
}

# ---------------------------------------------------------------------

=item set_iterator_indx_to

Description

=cut

# ---------------------------------------------------------------------

sub set_iterator_indx_to
{
    my $self = shift;
    my $index = shift;
    $self->{'iteratorIndex'} = $index;
}

# ---------------------------------------------------------------------

=item get_iterator_indx

Description

=cut

# ---------------------------------------------------------------------
sub get_iterator_indx
{
    my $self = shift;
    return $self->{'iteratorIndex'};
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
