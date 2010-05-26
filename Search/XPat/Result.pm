package Search::XPat::Result;

=head1 NAME

Search::XPat::Result (xro)

=head1 DESCRIPTION

This class is a simplified version if DLXS XPatResult.pm

=head1 VERSION

$Id: Result.pm,v 1.2 2007/12/14 20:02:44 pfarber Exp $

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


use Utils;
use Debug::DUtils;


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

Initialize Search::XPat::Result.

=cut

# ---------------------------------------------------------------------
sub _initialize 
{
    my $self = shift;

    my ($result_string_ref, $label, $xpat) = @_;

    my $hits_array_ref;

    # results can be in any of the forms:
    #   <Error>xpat error ...</Error>
    #   <SSize>-1</SSize><Error>...</Error>...
    #   <SSize>123</SSize>
    #   <PSet>raw text returned from xpat</PSet>
    #   <RSet>raw text returned from xpat</RSet>

    my $type;
    my $result_ok = 1;

    if ($$result_string_ref =~ m,<Error>,s)
    {
        my @clean_results = $$result_string_ref =~ m,<Error>(.*?)</Error>,sg ;
        $type = 'Error';
        $result_ok = 0;
        $hits_array_ref = \@clean_results;
    }
    else
    {
        ($type) = ($$result_string_ref =~ m,<([^>]+?)>,s);
        # store array of actual hits
        $hits_array_ref = 
            $self->parse_result_text($result_string_ref,
                                     $type,
                                     $xpat->get_pset_offset());
    }

    $self->{'results'} = $hits_array_ref;

    # store other object info
    $self->{'type'}  = $type;
    $self->{'label'} = $label;
    $self->{'xpat'}  = $xpat;

    if ($result_ok)
    {
        DEBUG('results,all',
              sub
              {
                  my $s;
                  my ($raw, $ct, $dd);
                  $dd = $xpat->get_data_dict_name('t');
                  foreach my $ref (@$hits_array_ref)
                  {
                      ++$ct;
                      $raw = ($type eq 'SSize') ? $$ref[1] : ${$$ref[1]};
                      Utils::map_chars_to_cers(\$raw);
                      $s .= qq{<br/><font color="green"><b>$type cleanResult($ct) [ $dd ]:</b><br/>$raw</font><br/>\n};
                  }
                  return $s;
              });
    }
}



# ---------------------------------------------------------------------

=item get_results_as_array_ref

Optimize access to large results arrays by returning the array
directly instead of requiring InitIterator() and GetNextResult() calls

=cut

# ---------------------------------------------------------------------
sub get_results_as_array_ref
{
    my $self = shift;
    return $self->{'results'};
}

sub get_label
{
    my $self = shift;
    return $self->{'label'};
}

sub get_type
{
    my $self = shift;
    return $self->{'type'};
}

sub get_xpat_object
{
    my $self = shift;
    return $self->{'xpat'};
}

sub get_SSize_result
{
    my $self = shift;
    my $return = undef;

    if ($self->get_type() eq 'SSize')
    {
        my $results_array_ref = $self->get_results_as_array_ref();
        $return = $$results_array_ref[0][1];
    }

    return $return;
}


# ---------------------------------------------------------------------

=item parse_result_text

Array returned is an array of anonymous arrays, each with 4 elements:

   [0]: byte offset of start of hit

   [1]: actual raw text of hit

   [2]: size in bytes of raw text

=cut

# ---------------------------------------------------------------------
sub parse_result_text
{
    my $self = shift;

    my ($s_ref, $type, $pset_offset) = @_;

    my @hit_array = ();
    my $return_arr_ref = \@hit_array;

    if ($type eq 'SSize')
    {
        my ($ssize) = ($$s_ref =~ m,<SSize>(.*?)</SSize>,g);
        @hit_array = [ undef, $ssize, undef, ];
    }
    else
    {
        my @arr = ($$s_ref =~ m,<Start>(.*?)</Start>.*?<Raw><Size>(.*?)</Size>(.*?)</Raw>,gs);

        my $pset_offset_adj = ($type eq 'PSet') ? int($pset_offset / 2) : 0;
        for (my $i=0; $i < scalar(@arr) / 3;  $i++)
        {
            my $idx_of_start = ($i * 3);
            my $idx_of_size = $idx_of_start + 1;
            my $idx_of_raw = $idx_of_start + 2;
            my $start_offset = $arr[$idx_of_start];
            my $start = $start_offset + $pset_offset_adj;
            # If start byte is negative pad with spaces up to offset 0
            if ($start_offset < 0)
            {
                my $amt_to_pad = 0 - $start_offset;
                substr($arr[$idx_of_raw], 0, $amt_to_pad) = ' ' x $amt_to_pad;
            }
            
            push(@hit_array, [$start, \$arr[$idx_of_raw], $arr[$idx_of_size],]);
        }
    }

    return $return_arr_ref;
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
