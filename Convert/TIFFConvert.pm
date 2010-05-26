package TIFFConvert;

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







sub TifToWebHandler_HOLD
{
    my $self = shift;
    my ($step_hr)=(@_);

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    # value saved in object should already have been determined
    my $rotationInDegrees = $cgi->param('rotate');

    my $preRotationOutputFileName = $$step_hr{'file'};

    my $sheight;
    my $outputRatio=4.0;
    if ( $$efi_hr{sheight} > 0 )
    {
	$outputRatio = $$sfi_hr{height} / $$efi_hr{sheight};
	if ($outputRatio > 16)
	{
	    $outputRatio=16;
	}
    }

    $self->Tif2WebCreateFile( $$sfi_hr{file},
			      $$step_hr{'file'},
			      $outputRatio );
}

# ----------------------------------------------------------------------
# NAME         : Tif2WebCreateFile
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub Tif2WebCreateFile_HOLD
{
    my $self = shift;
    my ( $inFilePath, $outFilePath, $outputRatio ) = @_;

    my $NumGrey = 4;
    my $Gamma   = 1.1;
    my $Tif2WebOutputTypeArg = '-P';

    my $scaleCmd = qq{ -A $outputRatio };
    my $arg = $Tif2WebOutputTypeArg;
    my $commandParams =
        qq{$arg -N $NumGrey -g $Gamma } .
            $scaleCmd .
                qq{ -x -o $outFilePath $inFilePath};

    my $command = qq{/l1/bin/symlinks/tif2web $commandParams};

    qx( $command 2>> /l1/dev/jweise/web/cache/tif2weblog.txt );
}





# ----------------------------------------------------------------------
1;
