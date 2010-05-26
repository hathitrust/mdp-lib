package PI;


=head1 NAME

PI (pio)

=head1 DESCRIPTION

This class packages code references and parameters for filtering XML
processing instructions <?...?> in XML templates in a generic way.

=head1 VERSION

$Id: PI.pm,v 1.6 2008/06/26 16:40:00 pfarber Exp $

=head1 SYNOPSIS

my $pio = new PI;

$pio->add_PI('SOME_PI', $PI_handler_coderef, [$param_1, $param_2]);

$pio->process_PIs($xml_template_data_ref);


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

use Debug::DUtils;

# Regular expression used to match any processing instruction within
# an html page template, of the form: <?Instruction?> or
# <?Instruction parm1="this" parm2="that"?>

my $PI_reg_exp = '<\?(\w+)(-\w+)?((\s+\w+=".*?")*)\s*\?>';
my $comp_PI_reg_exp = qr/$PI_reg_exp/;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;

    return $self;
}


# ---------------------------------------------------------------------

=item add_PI

Description

=cut

# ---------------------------------------------------------------------
sub add_PI
{
    my $self = shift;
    my ($ins, $sub_ref, $parm_list_ref) = @_;

    $self->{$ins}{'sub'}   = $sub_ref;
    $self->{$ins}{'parms'} = $parm_list_ref;
}

# ---------------------------------------------------------------------

=item get_PIs

Description

=cut

# ---------------------------------------------------------------------
sub get_PIs
{
    my $self = shift;
    my $s_ref = shift;

    my @PI_arr = ();

    while ($$s_ref =~ m,$comp_PI_reg_exp,gs)
    {
        my $pi_name = $1;
        push(@PI_arr, $pi_name);
    }

    return \@PI_arr;
}

# ---------------------------------------------------------------------

=item PI_DEBUG_trap

Description

=cut

# ---------------------------------------------------------------------
sub PI_DEBUG_trap
{
    return;
}

# ---------------------------------------------------------------------

=item process_PIs

Run through a string of XML and farm out the handling of any
processing instructions it encounters to the handlers

First, make a working copy of the input string, and a new string.

Then, running through the string matching for PIs, grab $` (the text
before the match) and concat it to the new string.  Then, process the
PI if a subroutine was supplied to handle it, and concat that to the
new string. Then make the working string equal to the post match
string and repeat.

=cut

# ---------------------------------------------------------------------
sub process_PIs
{
    my $self = shift;
    my $s_ref = shift;

    # working copy of input text
    my $s = $$s_ref;
    # new string to gather up processed text
    my $new_s = '';

    while ($s =~ m,(.*?)($comp_PI_reg_exp)(.*),gs)
    {
        my $pre = $1;
        my $pi = $2;
        my $instruction = $3 . $4;
        my $pi_params = $5;
        my $post = $7;

        $pi_params =~ s,^\s*,,;

        # remove trailing spaces, if any
        $instruction =~ s,\s*$,,;

        # the following splits up the p1=val1 p2=val2 into a hash,
        # properly indexed by p's

        # my %pi_params = split (/=|\s+/, $pi_params);
        # Superseded below by suggestion from Sakaama Heesakkers to
        # allow spaces in the parameter value
        my %pi_params = split(/="|"[\s>]/, $pi_params);

        # remove quotes from values and downcase all keys and values
        # so that PI atribute names (not values) can be case
        # insensitive
        my %lc_params = ();

        foreach my $p (keys (%pi_params))
        {
            my $temp_param = $pi_params{$p};
            $temp_param =~ s,\",,g; #"

            my $lc_p = lc ($p);
            $lc_params{$lc_p} = $temp_param;
        }

        # grab routine to run for this instruction
        my $sub   = $self->__get_codref($instruction);
        my $parms = $self->__get_parms($instruction);

        # add pre-match text to output string
        $new_s .= $pre;

        DEBUG('pis', qq{Handling PI="<b>$instruction</b>"});

        # if there is no subroutine defined, return Processing
        # Instruction to the text
        if (! (defined ($sub)))
        {
            $new_s .= $pi;
        }
        else
        {
            if (DEBUG($instruction))
            {
                PI_DEBUG_trap();
            }

            # if there is a subroutine CODE ref defined, run it and
            # tack on results to the new string.  If subroutine is a
            # method name the first element in the parameter array is
            # the object holding the method.  Invoke as an method.
            my $return_val;

            if (ref($sub) eq 'CODE')
            {
                $return_val = &$sub(@$parms, \%lc_params);
            }
            else
            {
                # The param is a string to be bound symbolically to
                # current object (which is the first element of the
                # paramter array supplied by the caller to add_PI()
                my $object = shift @$parms;
                $return_val = $object->$sub(@$parms, \%lc_params);
            }

            if (ref($return_val) eq 'SCALAR')
            {   $new_s .= $$return_val;   }
            else
            {   $new_s .= $return_val;   }
        }

        # finally, replace $s so that match starts from here on
        $s = $post;
    }
    # grab last part of incoming text, after the last match.
    $new_s .= $s;

    $$s_ref = $new_s;
}


# ---------------------------------------------------------------------

=item __get_codref

Description

=cut

# ---------------------------------------------------------------------
sub __get_codref
{
    my $self = shift;
    my $ins  = shift;

    if (exists (${ $self}{$ins}))
    {
        if (defined ($self->{$ins}{'sub'}))
        {
            return ($self->{$ins}{'sub'});
        }
        else
        {
            return \&__simple_substitution;   # reference to anon. subroutine
        }
    }
    else
    {
        return undef;
    }
}


# ---------------------------------------------------------------------

=item __simple_substitution

acts as a default subroutine to be called by process_PI

=cut

# ---------------------------------------------------------------------
sub __simple_substitution
{
    my $s = shift;

    if (ref($s) eq 'SCALAR')
    {   return $$s;  }
    else
    {   return $s;   }
}


# ---------------------------------------------------------------------

=item __get_parms

Description

=cut

# ---------------------------------------------------------------------
sub __get_parms
{
    my $self = shift;
    my $ins  = shift;

    if ((exists ($ {$self}{$ins})) &&
         (defined($self->{$ins}{'parms'})))
    {
        # Note: this is a reference to an anonymous array of
        # parameters for this instruction.  Return a writable copy of
        # this read-only value so we can have our way with the array
        # if we encounter more of the same PI in this run of
        # process_PIs().
        my @return_parms = @{$self->{$ins}{'parms'}};

        return \@return_parms;
    }
    else
    {
        return undef;
    }
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
