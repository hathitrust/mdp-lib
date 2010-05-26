package Utils::Serial;


=head1 NAME

Utils::Serial

=head1 DESCRIPTION

This non OO package contains routines to process serial data in MARC
<varfield id="MDP" ...>

=head1 VERSION

$Id: Serial.pm,v 1.2 2009/01/13 21:11:53 pfarber Exp $

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

=item item_is_serial

Wrapper to parse <fixfield
id="LDR">^^^^^nam^^22002651^^4500</fixfield> bytes and call
get_bib_fmt.  Below rec_type is LDR/byte6, bib_level is LDR/byte7
(0-offset)

All we need to know is whether to use the date in the 008 fixed field
or to parse the <varfield id="MDP"><subfield label="z">date</subfield>
for the date.

=cut

# ---------------------------------------------------------------------
sub item_is_serial
{
    my $marc_metadata_ref = shift;

    my ($LDR) = ($$marc_metadata_ref =~ m,<fixfield id="LDR">(.*?)</fixfield>,s);

    # Occasionally, mainly during internal testing, the MARC metadata
    # is not available for the item.  This is reported elsewhere.  In
    # these cases, there is no LDR. so just return False.
    if (! $LDR)
    {
        return 0;
    }

    my $rec_type = substr($LDR, 6, 1);
    my $bib_level = substr($LDR, 7, 1);

    my $format = __get_bib_fmt($rec_type, $bib_level);

    return ($format eq 'SE');
}

# ---------------------------------------------------------------------

=item get_volume_data

Description

<varfield id="MDP" i1=" " i2=" ">
   <subfield label="u">mdp.39015055275872</subfield> (always unless serios error)
   <subfield label="z">v.2 1901</subfield> (optional -> serial or multi-vol work)
   <subfield label="h">N 1 .M42</subfield> (optional call no -> shelf location, UM specific)
   <subfield label="b">BUHR</subfield> (sublibrary code -> which library -> SDR for wu)
   <subfield label="c">GRAD</subfield> (collection code -> wu for wu)
</varfield>

=cut

# ---------------------------------------------------------------------
sub get_volume_data
{
    my $marc_metadata_ref = shift;

    my ($varfield) = ($$marc_metadata_ref =~ m,<varfield id="MDP"[^>]*>(.*?)</varfield>,s);

    my ($id)     = ($varfield =~ m,<subfield label="u">(.*?)</subfield>,g);
    my ($vol)    = ($varfield =~ m,<subfield label="z">(.*?)</subfield>,g);
    my ($callno) = ($varfield =~ m,<subfield label="h">(.*?)</subfield>,g);
    my ($b)      = ($varfield =~ m,<subfield label="b">(.*?)</subfield>,g);
    my ($c)      = ($varfield =~ m,<subfield label="c">(.*?)</subfield>,g);

    my $marc_For_id_hashref = {
                               'id'     => $id,
                               'vol'    => $vol,
                               'callno' => $callno,
                               'b'      => $b,
                               'c'      => $c,
                              };

    return $marc_For_id_hashref;
}




# ---------------------------------------------------------------------

=item __get_bib_fmt

Description

=cut

# ---------------------------------------------------------------------
sub __get_bib_fmt
{
    # rec_type is LDR/byte6, bib_level is LDR/byte7 (0-offset)
    my $rec_type = shift;
    my $bib_level = shift;

    $rec_type =~ /[abcdefgijkmoprt]/
        or do
        {
            soft_ASSERT(0, qq{Invalid rec_type: $rec_type});
            return '';
        };

    $bib_level =~ /[abcdms]/
        or do
        {
            soft_ASSERT(0, qq{invalid bib_level: $bib_level});
            return '';
        };

    $rec_type =~ /[at]/   and $bib_level =~ /[acdm]/   and return "BK";
    $rec_type =~ /[m]/    and $bib_level =~ /[abcdms]/ and return "CF";
    $rec_type =~ /[gkor]/ and $bib_level =~ /[abcdms]/ and return "VM";
    $rec_type =~ /[cdij]/ and $bib_level =~ /[abcdms]/ and return "MU";
    $rec_type =~ /[ef]/   and $bib_level =~ /[abcdms]/ and return "MP";
    $rec_type =~ /[a]/    and $bib_level =~ /[bs]/     and return "SE";
    $rec_type =~ /[bp]/   and $bib_level =~ /[abcdms]/ and return "MX";
    # no match  --error

    return '';
}




1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008 ©, The Regents of The University of Michigan, All Rights Reserved

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
