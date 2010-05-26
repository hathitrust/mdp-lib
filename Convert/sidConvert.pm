package sidConvert;

# Copyright 2008, The Regents of The University of Michigan, All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

use Convert;


use vars qw( @ISA );
@ISA = qw( Convert );


use strict;
use IPC::Open3;


sub Extract
{
    my $self=shift;
    my ($step_hr)=(@_);

    $self->SIDConversion($step_hr);
}

sub SIDConversion
{
    my $self=shift;
    my ($step_hr)=(@_);

    my $sfi_hr=$self->Get('StartingFileInfo');
    my $efi_hr=$self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    my $width=$$efi_hr{extractWidth};
    my $height=$$efi_hr{extractHeight};
    my $x=$$efi_hr{extractX};
    my $y=$$efi_hr{extractY};
    my $res=$$efi_hr{res};


    my $reduce;
    if ($res ne '')
    {
	$reduce = qq{-s $res};
    }


    my $sid2jpeg = $self->GetBinary('sid') . " -jpeg -i $$sfi_hr{file} -x $x -y $y $reduce -w $width -h $height -o $$step_hr{file}";

    if (-e $$sfi_hr{file})
    {
	my $pid = open3('IN', 'OUT', 'ERR', $sid2jpeg);
	my @stderr = <ERR>;
	close(IN);
	close(OUT);
	close(ERR);
    }

#    print $sid2jpeg . "\n";

}




# ----------------------------------------------------------------------
1;
