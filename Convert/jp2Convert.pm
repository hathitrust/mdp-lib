package jp2Convert;

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


sub CacheFilePartsList
{
    my $self=shift;

    my %CacheFilePartsList = ( 
			      'extract' =>   ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight', 'rotate'],
			      'sample'  =>   ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight', 'rotate'],
			      'watermark' => ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight', 'rotate'],
			      'final'   =>   ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight', 'rotate'],
			     );
    $self->Set('CacheFilePartsList', \%CacheFilePartsList);
}


# this method subclassed to avoid typical rotation
sub EndingFilenamesForCacheing
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    my @conversionSteps;
    $$efi_hr{conversionSteps} = \@conversionSteps;


    $self->FilenameForCacheingStep('extract');

    if ( ( $$efi_hr{x} ) && ( $$efi_hr{sheight} ) )
    {
	$self->FilenameForCacheingStep('sample');
    }

    if ( ( $$efi_hr{swidth} ) && ( $$efi_hr{sheight} ) )
    {
	$self->FilenameForCacheingStep('sample');
    }

    # rotation removed

#    $self->FilenameForCacheingStep('watermark');

    $self->FilenameForCacheingStep('final');
}



sub Extract
{
    my $self=shift;
    my ($step_hr)=(@_);


    $self->translateForKakadu();
    $self->JP2Conversion($step_hr);
}

sub Rotate{}

sub JP2Conversion
{
    my $self=shift;
    my ($step_hr)=(@_);

    $self->spacialCompensation($step_hr);

    my $sfi_hr=$self->Get('StartingFileInfo');
    my $efi_hr=$self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    my $width=$$efi_hr{extractWidth};
    my $height=$$efi_hr{extractHeight};
    my $x=$$efi_hr{extractX};
    my $y=$$efi_hr{extractY};
    my $res=$$efi_hr{res};

    my $kdu_expand_jpg=$self->GetBinary('jp2');

    my $rotateDegrees = $cgi->param('rotate');
    my $rotate;
    if ( ($rotateDegrees) && ($rotateDegrees%90 == 0) ) { $rotate=qq{-rotate $rotateDegrees}; }

    my $quality = 100;
    if ( $$efi_hr{format} eq 'pdf')
    {
	$quality=100;
    }
    my $reduce;
    if ($res ne '')
    {
	$reduce = qq{-reduce $res};
    }
    my $kdu2jpeg = "$kdu_expand_jpg -quiet -i $$sfi_hr{file} -o $$step_hr{file} $reduce -region \\{$y,$x\\},\\{$height,$width\\} -quality $quality $rotate\;";

#print $kdu2jpeg . "\n";

    if (-e $$sfi_hr{file}) 
    {
	my $pid = open3('IN', 'OUT', 'ERR', $kdu2jpeg);
	my @stderr = <ERR>;
		
	close(IN);
	close(OUT);
	close(ERR);
    }

    $self->spacialCompensationCleanup($step_hr);
}



## in rare cases the media file path has a space in it.
## the shell script that wraps the kdu (JPEG2000) commands
## chokes on the spaces, and attempts to escape the spaces
## have not been fruitful. This routine creates a symlink
## in the temp dir if the path includes a space.
## the next routine deletes the symlink if it exists.
sub spacialCompensation
{
    my $self=shift;
    my ($step_hr)=(@_);

    my $tmp = $self->Get('cache');

    if ($$step_hr{file} =~ m/[\s]/)
    {
	$$step_hr{fileorig}=$$step_hr{file};
	my $mediaFullPathSymLink = $$step_hr{file};
	$mediaFullPathSymLink =~ s,[\s\/],_,g;
	$mediaFullPathSymLink = qq{$tmp/$mediaFullPathSymLink};
	symlink $$step_hr{file},$mediaFullPathSymLink;
	$$step_hr{file} = $mediaFullPathSymLink;
    }

}

sub spacialCompensationCleanup
{
    my $self=shift;
    my ($step_hr)=(@_);

    my $tmp = $self->Get('cache');
    if ( (-l $$step_hr{file}) && ($$step_hr{file} =~ m,^\Q$tmp\E/,) )
    {
	unlink $$step_hr{file};
	$$step_hr{file}=$$step_hr{file_orig};
    }
}

# ----------------------------------------------------------------------
1;
