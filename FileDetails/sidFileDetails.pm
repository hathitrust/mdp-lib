package sidFileDetails;

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

use FileDetails;
use IPC::Open3;


use vars qw( @ISA );
@ISA = qw( FileDetails );



use strict;


sub _initialize
{
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $self->Set('SidInfoCommand', $self->GetBinary('sidinfo') . q{ -info -i __INPUT_SID__} );
}


sub GetFileDetails
  {
    my $self=shift;
    my ($fileinfo_hr) = (@_);

    $self->Set('success', 0);

    if (! -e $$fileinfo_hr{file})
    {
	$self->Set('errormsg', qq{no file } . $$fileinfo_hr{file} . qq{\n});
	return;
    }

    # Get maximum dimensions and number of levels in stored jp2 image
    my $SidInfoCommand = $self->Get('SidInfoCommand');
    $SidInfoCommand =~ s,__INPUT_SID__,$$fileinfo_hr{file},;

    my $prevRecordSeparator = $/;
    $/ = "\n";

    $| = 1;		## flush stdio

    ## ----- find maximum dimensions and number of levels in stored Sid image
    my $cmd2 = open3('IN', 'OUT', 'ERR', "$SidInfoCommand");
    my @stdin = <IN>;
    my @stdout = <OUT>;
    my @stderr = <ERR>;

    ## ----- $maxheight and $maxwidth are h and w of full stored Sid image
    ## ----- $levels is the number of stored levels of resolution. 0 refers to full resolution of full image

    my ($filename, $blank, $maxwidth, $maxheight, $samples, $levels) = @stdout;

    if ($maxwidth =~ m/(\d{1,})/) {
	$maxwidth = $1;
     }
    if ($maxheight =~ m/(\d{1,})/) {
	$maxheight = $1;
     }
    if ($levels =~ m/(\d{1,})/) {
	$levels = $1;
     }
    $/ = $prevRecordSeparator;

    $$fileinfo_hr{levels}=$levels;
    $$fileinfo_hr{maxwidth}=$maxwidth;
    $$fileinfo_hr{maxheight}=$maxheight;

    $self->_ParseFilePath( $fileinfo_hr );

    $$fileinfo_hr{width} = $$fileinfo_hr{maxwidth};
    $$fileinfo_hr{height} = $$fileinfo_hr{maxheight};

    $self->Set('success', 1);

}





# ----------------------------------------------------------------------
1;
