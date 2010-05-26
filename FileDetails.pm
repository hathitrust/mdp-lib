package FileDetails;

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

# 3rd Party
use Image::Magick;

use strict;
use File::Basename;

# ----------------------------------------------------------------------
# NAME      : new
# PURPOSE   : create new object
# CALLED BY :
# CALLS     : $self->_initialize
# INPUT     : 
# RETURNS   : NONE
# NOTES     :
# ----------------------------------------------------------------------
sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}

# ----------------------------------------------------------------------
# NAME      : _initialize
# PURPOSE   : create structure for object
# CALLED BY : new
# CALLS     :
# INPUT     : see new
# RETURNS   :
# NOTES     :
# ----------------------------------------------------------------------
sub _initialize
{
    my $self = shift;

    my ($binaries_hr)=(@_);
    $self->Set('binaries', $binaries_hr);
}

sub Set
{
    my $self = shift;
    my ( $key, $value ) = @_;
    $self->{ $key } = $value;
}

sub Get
{
    my $self = shift;
    my $key = shift;
    return $self->{ $key };
}

sub GetBinary
{
    my $self=shift;
    my $key=shift;
    my $binaries_hr=$self->Get('binaries');
    return( $$binaries_hr{$key} );
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

    my $image = new Image::Magick;

    my ($width, $height, $size, $format) = $image->Ping( $$fileinfo_hr{file} );
    $$fileinfo_hr{width} = $width;
    $$fileinfo_hr{height} = $height;
    $$fileinfo_hr{size} = $size;
    $$fileinfo_hr{format} = $format;
    $$fileinfo_hr{maxwidth} = $width;
    $$fileinfo_hr{maxheight} = $height;


    $self->_ParseFilePath( $fileinfo_hr );

    # it is important to set success
    $self->Set('success', 1);
}



sub _ParseFilePath
{
    my $self = shift;
    my ($fileinfo_hr) = (@_);

    ( $$fileinfo_hr{base}, $$fileinfo_hr{path}, $$fileinfo_hr{ext} )
	= fileparse($$fileinfo_hr{file}, '\.[^.]*');
}


# some file formats don't have "levels" the way jpeg2000 does.
# for the sake of uniform processing, however, we'll assign
# the file a number of levels based on the maximum dimension of the image.
sub FakeNumberOfLevels
{
    my $self=shift;
    my ($fileinfo_hr) = (@_);

    return if ( defined $$fileinfo_hr{levels} );

    my $Tmax;

    if (($$fileinfo_hr{height} - $$fileinfo_hr{width}) >= 0) {
	$Tmax = $$fileinfo_hr{height};
    } else {
	$Tmax = $$fileinfo_hr{width};
    }

    my $nlev;
    if      (($Tmax > 0)    && ($Tmax <= 800)) {
	$nlev = 2;
    } elsif (($Tmax > 800)  && ($Tmax <= 1600)) {
	$nlev = 3;
    } elsif (($Tmax > 1600) && ($Tmax <= 3200)) {
	$nlev = 4;
    } elsif (($Tmax > 3200) && ($Tmax <= 6400)) {
	$nlev = 5;
    } elsif (($Tmax > 6400) && ($Tmax <= 12800)) {
	$nlev = 6;
    } else {
	$nlev = 7;
    }

    $$fileinfo_hr{levels}=$nlev;
    return($nlev);
}


# ----------------------------------------------------------------------
1;
