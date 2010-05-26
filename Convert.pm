package Convert;

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
    my ($sfi_hr, $efi_hr, $cgi, $binaries_hr, $cache, $cache_file_name_prefix, $cache_cleanup_prefix) = (@_);

    $self->Set('StartingFileInfo', $sfi_hr);
    $self->Set('EndingFileInfo', $efi_hr);
    $self->Set('cgi', $cgi);
    if (! defined $cache) { $cache = '/tmp'; }
    $self->Set('cache', $cache);
    $self->Set('cache_file_name_prefix', $cache_file_name_prefix);
    $self->Set('cache_cleanup_prefix', $cache_cleanup_prefix);
    $self->Set('binaries', $binaries_hr);
    $self->CacheFilePartsList();
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


sub CacheFilePartsList
{
    my $self=shift;

    my %CacheFilePartsList = ( 
			      'extract' => ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight'],
			      'sample'  => ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight'],
			      'rotate'  => ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight', 'rotate'],
			      'final'   => ['width', 'height', 'res', 'x', 'y', 'swidth', 'sheight', 'rotate'],
			     );
    $self->Set('CacheFilePartsList', \%CacheFilePartsList);
}

sub Convert
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    $self->EndingFilenamesForCacheing();

    $self->AdjustForBoundaries();

    my $conversionSteps_ar = $$efi_hr{conversionSteps};
    foreach my $step_hr ( @$conversionSteps_ar )
    {
	if ( ! $$step_hr{cached} )
	{
	    $self->IndividualConversionSteps($step_hr);
	}

	if (! $$step_hr{file})
	{
	    die qq/Error: file not found... $$step_hr{file}\n/;
	}
	else
	{
	    $self->Set('lastfile', $$step_hr{file});
	}
    }

    $self->FinalizeConversionMedia();
}

sub InitializeConversionMedia
{
    my $self=shift;
    my ($fileToRead_r, $density)=(@_);

    if ( defined $self->Get('image') )
    {
	return;
    }

    my $efi_hr = $self->Get('EndingFileInfo');

    my $image = new Image::Magick;
    $self->Set('image', $image);

    $image->Set( units => 'PixelsPerInch' );
    $image->Read( $$fileToRead_r );
    $image->Set( quality =>100 )
	if ( $$efi_hr{'format'} eq 'jpg');

    $self->Grayscale();

}

sub FinalizeConversionMedia
{
    my $self=shift;

    my $image=$self->Get('image');
    # destroy Image::Magick object
    $image = undef;
}

sub IndividualConversionSteps
{
    my $self=shift;
    my ($step_hr)=(@_);

    my $sfi_hr = $self->Get('StartingFileInfo');

    my $file = $self->Get('lastfile') || $$sfi_hr{file};
    if (! -e $file)
    {
	die qq{Error: File not found... $file\n};
    }

    if ( $$step_hr{label} eq 'extract' )
    {
	$self->Extract(@_);
    }
    elsif ( $$step_hr{label} eq 'sample' )
    {
	$self->Sample(@_);
    }
    elsif ( $$step_hr{label} eq 'rotate' )
    {
	$self->Rotate(@_);
    }
    elsif ( $$step_hr{label} eq 'watermark' )
    {
	$self->Watermark(@_);
    }
    elsif ( $$step_hr{label} eq 'final' )
    {
	$self->Final(@_);
    }
    else
    {
	die (qq{unrecognized step } . $$step_hr{label} . qq{\n});
    }
}

sub Extract
{
    my $self=shift;
    my ($step_hr)=(@_);


    my $sfi_hr = $self->Get('StartingFileInfo');

    my $file = $self->Get('lastfile') || $$sfi_hr{file};
    $self->InitializeConversionMedia(\$file, undef);

    my $efi_hr = $self->Get('EndingFileInfo');
    my $image = $self->Get('image');

    $self->translateForKakadu();

    my $x = $$efi_hr{extractX};
    my $y = $$efi_hr{extractY};
    my $w = $$efi_hr{extractWidth};
    my $h = $$efi_hr{extractHeight};

    if ( (! defined $x) || (! defined $y) || (! defined $w) || (! defined $h) )
    {
	return;
    }

#    print qq{x: $x y: $y w: $w h: $h\n};
    my $g = $w*100 . q{%x} . $h*100 . q{%+} . $x*$image->Get('columns') . q{+} . $y*$image->Get('rows');
#    print $g . qq{\n};
    my $e = $image->Crop(geometry=>$g);
    warn "$e" if "$e";

    if ( $image->Get('columns') != $$efi_hr{width} )
    {
	$e = $image->Scale( width  => $$efi_hr{width}, height => $$efi_hr{height} );
	warn "$e" if "$e";
    }

    $self->WriteImageMagickObjectToDisk( $image, $$step_hr{file} );

}

sub Sample
{
    my $self=shift;
    my ($step_hr)=(@_);


    my $sfi_hr = $self->Get('StartingFileInfo');

    my $file = $self->Get('lastfile') || $$sfi_hr{file};
    $self->InitializeConversionMedia(\$file, undef);


    my $efi_hr = $self->Get('EndingFileInfo');
    my $image = $self->Get('image');
    $image->Scale( width  => $$efi_hr{swidth}, height => $$efi_hr{sheight} );
    $self->WriteImageMagickObjectToDisk( $image, $$step_hr{file} );
}

sub Final
{
    my $self=shift;
    my ($step_hr)=(@_);

    my $sfi_hr = $self->Get('StartingFileInfo');

    my $file = $self->Get('lastfile') || $$sfi_hr{file};
    $self->Convert::InitializeConversionMedia(\$file, undef);

    my $image = $self->Get('image');

    $image = $self->BlackoutRestricted($image, $sfi_hr);

    $image->Set( density => "72" );
    $self->WriteImageMagickObjectToDisk( $image, $$step_hr{file} );

    $self->Convert::FinalizeConversionMedia();
}

sub Rotate
{
    my $self=shift;
    my ($step_hr)=(@_);


    my $sfi_hr = $self->Get('StartingFileInfo');

    my $file = $self->Get('lastfile') || $$sfi_hr{file};
    $self->InitializeConversionMedia(\$file, undef);


    my $cgi = $self->Get('cgi');
    my $image = $self->Get('image');

    $image->Rotate( degrees => $cgi->param('rotate') );
    $self->WriteImageMagickObjectToDisk( $image, $$step_hr{file} );

}


sub Grayscale
{
    my $self=shift;

    my $image = $self->Get('image');

    if ( $image->Get('compression') =~ m/Group4/i ) 
    {
	$image->Set( type  => 'Grayscale' );
	$image->Quantize( colorspace   => 'gray', colors=> 16 );
    }
}


sub BlackoutRestricted
{
    my $self = shift;
    my ($image, $sfi_hr)=(@_);

    return($image) if (! $$sfi_hr{RESTRICTED} );

    my $mainWidth = $image->Get( 'width' );
    my $mainHeight = $image->Get( 'height' );

    my $size = $mainWidth . 'x' . $mainHeight;
    my $boImage = Image::Magick->new();
    $boImage->Set(size=>$size);
    $boImage->Read('xc:black');

    my $text = 'restricted';

    $boImage->Annotate( antialias=>'true', stroke=>'black', font=>'Helvetica-Bold', text=>$text, gravity=>'Center', pointsize=>'40', fill=>'white');

    return($boImage);
}



sub Watermark
{
    my $self = shift;
    my ($step_hr)=(@_);

    my $sfi_hr = $self->Get('StartingFileInfo');

    my $file = $self->Get('lastfile') || $$sfi_hr{file};
    $self->Convert::InitializeConversionMedia(\$file, undef);

    my $image = $self->Get('image');

    my $GraphicsHtmlDir = '/l1/web/m/mdp/graphics/';

    my %gWatermarkImages  = (
			  '1' => $GraphicsHtmlDir . q{Watermarks.png},
			  '2' => $GraphicsHtmlDir . q{Watermark_MLibrary.png},
			 );


    my $source_attribute = 1;
    my $watermarkFileName = $gWatermarkImages{$source_attribute};

    exit if (! -e $watermarkFileName);



    if (0)
    {
	my $wmImage = new Image::Magick;
	$wmImage->Read( $watermarkFileName );

	my $wmWidth  = $wmImage->Get( 'width' );
	my $wmHeight = $wmImage->Get( 'height' );

	my $mainWidth = $image->Get( 'width' );
	my $mainHeight = $image->Get( 'height' );

	my $cornerOffset = 5;
	my $x = ($mainWidth - $wmWidth) / 2;
	my $y = $mainHeight - $wmHeight - $cornerOffset;
	my $geometry = $wmWidth . "x" . $wmHeight . "+" . $x . "+" . $y;
	
	$image->Composite(
			  compose  => 'Over',
			  image    => $wmImage,
			  geometry => $geometry,
			 );

	# destroy watermark ImageMagick object
	$wmImage   = undef;
	
    }
    else
    {
	my $wm_background = 'black';
	my $wm_text = 'restricted';
	my $wm_opacity = '93%';
	if (! $$sfi_hr{RESTRICTED} )
	{
	    $wm_background = 'transparent';
	    $wm_text = 'watermark';
	    $wm_opacity = '25%';
	}

	my $mainWidth = $image->Get( 'width' );
	my $mainHeight = $image->Get( 'height' );

	my $size = $mainWidth . 'x' . $mainHeight;
	my $wmImage = Image::Magick->new();
	$wmImage->Set(size=>$size);
	$wmImage->Read('xc:' . $wm_background);
	$wmImage->Annotate( antialias=>'true', stroke=>'black', font=>'Helvetica-Bold', text=>$wm_text, gravity=>'Center', pointsize=>'40', fill=>'white');

	my $geometry = $image->Get('width') . "x" . $image->Get('height') . "+" . '0+0';


	$image->Composite(
			  compose  => 'Dissolve',
			  image    => $wmImage,
			  geometry => $geometry,
			  opacity  =>$wm_opacity,
			 );


	# destroy watermark ImageMagick object
	$wmImage   = undef;


    }




    $self->WriteImageMagickObjectToDisk( $image, $$step_hr{file} );
    $self->Convert::FinalizeConversionMedia();
}



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

    if ( $cgi->param('rotate') != 0 )
    {
	$self->FilenameForCacheingStep('rotate');
    }

# watermarking works, mostly, but needs a way to be off by default and to work with colls
#    $self->FilenameForCacheingStep('watermark');

    $self->FilenameForCacheingStep('final');
}

sub FilenameForCacheingStep
{
    my $self=shift;
    my ($label)=(@_);

    my $efi_hr = $self->Get('EndingFileInfo');
    my $sfi_hr = $self->Get('StartingFileInfo');
    my $cgi = $self->Get('cgi');

    my %step = ('label' => $label);

    $step{format}=$$efi_hr{middleformat} || 'png';
    if ( $step{label} eq 'final' )
    {
	$step{format} = $$efi_hr{format};
    }

    my $conversionSteps_ar=$$efi_hr{conversionSteps};

    push @$conversionSteps_ar, \%step;
    $self->JoinFilenameParts( \%step );

    if ( $step{label} eq 'final' )
    {
	$$efi_hr{contentdispositionfilename} = $step{contentdispositionfilename};
    }

    $step{cached} = ( -e $step{file} );

    if ( $step{cached} )
    {
	$self->TouchFile( $step{file} );
    }
}

# extend life of cached file by updating time stamp
sub TouchFile
{
    my $self=shift;
    my ($file)=(@_);

    if ( -e $file )
    {
        my $now = time;
        utime $now, $now, ($file);	
    }
}

sub JoinFilenameParts
{
    my $self = shift;
    my ($step_hr) = (@_);

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    my $cfpl_hr = $self->Get('CacheFilePartsList');
    my $cfpl_ar = $$cfpl_hr{ $$step_hr{label} };

    my @parts;
    push @parts, $$sfi_hr{'base'} . $$sfi_hr{'ext'};
    foreach my $p (@$cfpl_ar)
    {
	if ( ( defined $$efi_hr{$p} ) && ( $$efi_hr{$p} ) )
	{
	    push @parts, substr($p, 0, 2) . $$efi_hr{$p};
	}
    }
    push @parts, $$step_hr{label};

    $$step_hr{base} = join('-', @parts);
    shift (@parts);

    my $cache = $self->Get('cache');
    my $cache_file_name_prefix = $self->Get('cache_file_name_prefix');
    my $format='jpg';



    my $restricted;
    if ( $$step_hr{label} eq 'final' )
    {
	$restricted = 'RESTRICTED_';
	if ( ! $$sfi_hr{RESTRICTED} )
	{
	    undef $restricted;
	}
    }

    $$step_hr{file} =  $cache . '/' . $cache_file_name_prefix . $restricted . $$step_hr{base} . '.' . $$step_hr{format};
}


sub WriteImageMagickObjectToDisk
{
    my $self = shift;
    my ( $image, $outFilePath ) = @_;

#    my $q=90;
#    $image->Set( quality =>$q );
#    print qq{setting quality to $q for $outFilePath\n};

    open( IMAGE, ">$outFilePath" );
    my $status=$image->Write( file => \*IMAGE, filename => $outFilePath );
    warn "Write failed: $status" if $status;
    close(IMAGE);
}


# MrSID uses x, y, w, h in order to do image extractions
# where x and y are pixel coords for the center of the
# portion to extract and w, h are pixel dims centered
# around x,y. 
# Kakadu uses top, left, height, width for JPEG2000
# Kakadu also uses percentages rather than pixels.
# this routine converts MrSID params to Kakadu params
#  -region {<top>,<left>},{<height>,<width>}
sub translateForKakadu
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi = $self->Get('cgi');

    my $x = $$efi_hr{extractX};
    my $y = $$efi_hr{extractY};
    my $w = $$efi_hr{extractWidth};
    my $h = $$efi_hr{extractHeight};
    my $res = $$efi_hr{res};
    my $maxwidth = $$sfi_hr{maxwidth};
    my $maxheight = $$sfi_hr{maxheight};

    $w = int( $w * ( 2 ** $res ) );
    $h = int( $h * ( 2 ** $res ) );

    my $kdu_x = ( ( $x - ( $w / 2 ) ) / $maxwidth );
    my $kdu_y = ( ( $y - ( $h / 2 ) ) / $maxheight );
    my $kdu_w = ( $w / $maxwidth );
    my $kdu_h = ( $h / $maxheight );

    if ( $kdu_x > 1 ) { $kdu_x = 1 };
    if ( $kdu_x < 0 ) { $kdu_x = 0 };

    if ( $kdu_y > 1 ) { $kdu_y = 1 };
    if ( $kdu_y < 0 ) { $kdu_y = 0 };

    $$efi_hr{extractX}=$kdu_x;
    $$efi_hr{extractY}=$kdu_y;
    $$efi_hr{extractWidth}=$kdu_w;
    $$efi_hr{extractHeight}=$kdu_h;

}


# this eliminates black padding on MrSID images, but is also needed for JPEG2000
sub AdjustForBoundaries
{
    my $self=shift;

    my $sfi_hr=$self->Get('StartingFileInfo');
    my $efi_hr=$self->Get('EndingFileInfo');

    my $width=$$efi_hr{extractWidth};
    my $height=$$efi_hr{extractHeight};
    my $x=$$efi_hr{extractX};
    my $y=$$efi_hr{extractY};
    my $res=$$efi_hr{res};

    if ($x >= $$sfi_hr{maxwidth}-($width*(2**$res)*.5) )
    {
	$x = $$sfi_hr{maxwidth}-($width*(2**$res)*.5);
    }
    elsif ( $x < ($width*(2**$res)*.5))
    {
	$x = ($width*(2**$res)*.5);
    }
    $$efi_hr{extractX}=$x;

    if ($y >= $$sfi_hr{maxheight}-($height*(2**$res)*.5) )
    {
	$y = $$sfi_hr{maxheight}-($height*(2**$res)*.5);
    }
    elsif ( $y < ($height*(2**$res)*.5))
    {
	$y = ($height*(2**$res)*.5);
    }
    $$efi_hr{extractY}=$y;

}


# ----------------------------------------------------------------------
1;
