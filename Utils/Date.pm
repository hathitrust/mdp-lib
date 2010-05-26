package Utils::Date;


=head1 NAME

Utils::Date

=head1 DESCRIPTION

This non OO package contains routines originated by Tim Prettyman
timothy@umich.edu to munge the contents of the

<varfield id="MDP" ...><subfield label="z">date stuff</subfield>

to try to derive a useful date for serial volumess mainly for sorting
purposes.

=head1 VERSION

$Id: Date.pm,v 1.4 2008/10/17 20:38:31 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 SUBROUTINES

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


# ---------------------------------------------------------------------

=item get_volume_date

Description

=cut

# ---------------------------------------------------------------------
sub get_volume_date 
{
    my $item_desc = lc(shift);

    $item_desc or return '';

    my @vol_date = ();
    my $orig_desc = $item_desc;
    my ($low, $high, $date);

    # strip confusing page/part data:
    #39015022710779: Title 7 1965 pt.1090-end
    #39015022735396: v.23 no.5-8 1984 pp.939-1830
    #39015022735701: v.77 1983 no.7-12 p.673-1328
    #39015022735750: v.75 1981 no.7-12 p.673-1324
    $item_desc =~ s/(v\.\d+\-\d+)//g;
    $item_desc =~ s/(v\.\d+)//g;
    $item_desc =~ s/(no\.\d+\-\d+)//g;
    $item_desc =~ s/(no\.\d+)//g;
    $item_desc =~ s/(p{1,2}\.\d+\-\d+)//g;
    $item_desc =~ s/(pt\.\d+\-\d+)//g;
    $item_desc =~ s/(pt\.\d+)//g;
    
    # check for date ranges: yyyy-yy
    ($low, $high) = ( $item_desc =~ /\b(\d{4})\-(\d{2})\b/ ) 
        and do 
        {
            $high = substr($low, 0, 2) . $high;
            push(@vol_date, $high);
        };

    # check for date ranges: yyyy-y
    ($low, $high) = ( $item_desc =~ /\b(\d{4})\-(\d)\b/ ) 
        and do 
        {
            $high = substr($low, 0, 3) . $high;
            push(@vol_date, $high);
        };

    # look for 4-digit strings
    $item_desc =~ tr/0-9/ /cs;            # xlate non-digits to blank
    push(@vol_date, $item_desc =~ /\b(\d{4})\b/g);
    @vol_date = sort(@vol_date);

    # return the maximum year
    return pop(@vol_date);
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
