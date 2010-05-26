package MediaItem;

# Copyright 2003-2008, The Regents of The University of Michigan, All Rights Reserved
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



# params
# zoom: all-> x y width height res

# scale to specific size: maxdim or sheight or swidth

# examples:
# http://jweise.dev.umdl.umich.edu/cgi/i/image/getmedia?x=1427;y=1536;width=390;height=391;res=1

use strict;
use CGI;
use IPC::Open3;



sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}


sub _initialize
{
    my $self = shift;
    my ($InitAttr_hr) = (@_);

    $self->Set('InitAttr', $InitAttr_hr);

    my $cgi = new CGI;
    $self->Set('cgi', $cgi);

    my %Metadata;
    $self->Set('Metadata', \%Metadata);

    my %StartingFileInfo;
    $self->Set('StartingFileInfo', \%StartingFileInfo);

    my %EndingFileInfo;
    $self->Set('EndingFileInfo', \%EndingFileInfo);

    $self->ASSERT( -d $$InitAttr_hr{cache}, qq{cache directory does not exist: } . $$InitAttr_hr{cache} );
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

sub ASSERT
{
    my $self=shift;
    my ($condition, $message) = (@_);

    if ( ! $condition )
    {
	die (qq{ASSERTION FAILURE:\n$message\n$condition\n});
    }
}

sub Main
{
    my $self=shift;
    $self->ValidateInputParams();
    $self->StartingFileInfo();
    $self->NailDownSizingParams();
    $self->EndingFileInfo();
    $self->Convert();
    my $file = $self->Output();
    $self->CacheCleanup();
    return( $file );
}


sub ValidateInputParams{}

sub Metadata{}

sub StartingFileInfo
{
    my $self=shift;

    my @InitAttr = $self->Get('InitAttr');
    my ($file_hr) = (@InitAttr);

    $self->Set('outputformat', $$file_hr{outputformat});
    $self->Set('no_output', $$file_hr{no_output});

    my $sfi_hr = $self->Get('StartingFileInfo');

    $$sfi_hr{file} = $$file_hr{startfile};
    ($$sfi_hr{format}) = lc( $$sfi_hr{file} ) =~ m/\.([^.]*)$/i;

#    $$sfi_hr{format}='jp2';
#    $$sfi_hr{file}='/n4/img/b/bhl/200712/bhl-071128_0812-7522-20071129T135917_DONE/jp2/bl001001.jp2';

#    $$sfi_hr{format}='jpg';
#    $$sfi_hr{file}='/n4/img/h/hart/Alinari/master/AL00356.JPG';

#    $$sfi_hr{format}='tif';
#    $$sfi_hr{file}='/n4/obj/0/5/2/0521004.0061.101/00000008.tif';

    $self->ASSERT( -e $$sfi_hr{file} );

    $self->FileDetails();
}

sub EndingFileInfo
{
    my $self=shift;
    my ($no_output) = (@_);


    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');

    $$efi_hr{middleformat}='jpg';

    my %ct = ('jpg' => 'image/jpeg',
	      'pdf' => 'document/pdf',
	      'png' => 'image/png',
	      'gif' => 'image/gif',
	      'mpg' => 'video/mpeg',
	      'mp3' => 'audio/mp3',
	     );

    my $outputformat=lc($self->Get('outputformat'));

    $$efi_hr{format}=$outputformat;
    $$efi_hr{contenttype}=$ct{$outputformat};

    my $cgi=$self->Get('cgi');

    if ( defined $cgi->param('rotate') )
    {
	$$efi_hr{rotate} = $cgi->param('rotate');
    }

}

sub NailDownSizingParams
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');

    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi=$self->Get('cgi');

    if ( $cgi->param('maxdim') > 0)
    {
	$$efi_hr{ $$sfi_hr{bigparam} } = $cgi->param('maxdim');
	$$efi_hr{ $$sfi_hr{smallparam} } = $cgi->param('maxdim') * $$sfi_hr{small2big_ratio};
    }
    elsif ( ( $cgi->param('swidth') > 0 ) && ( ! defined $cgi->param('sheight') ) )
    {
	$$efi_hr{sheight} = $cgi->param('swidth') * $$sfi_hr{height2width_ratio};
    }
    elsif ( ( $cgi->param('sheight') > 0 ) && ( ! defined $cgi->param('swidth') ) )
    {
	$$efi_hr{sheight} = $cgi->param('sheight') * $$sfi_hr{width2height_ratio};
    }

    $self->ResLevel();

    $$efi_hr{width} = ( $cgi->param('width') ) || $$efi_hr{swidth};
    $$efi_hr{height} = ( $cgi->param('height') ) || $$efi_hr{sheight};

    $$efi_hr{x} = ( $cgi->param('mainimage.x') ) || ( $cgi->param('x') ) || $$efi_hr{swidth}/2;
    $$efi_hr{y} = ( $cgi->param('mainimage.y') ) || ( $cgi->param('y') ) || $$efi_hr{sheight}/2;

    $$efi_hr{extractX} = ( $cgi->param('mainimage.x') ) || ( $cgi->param('x') ) || $$efi_hr{extractWidth}/2;
    $$efi_hr{extractY} = ( $cgi->param('mainimage.y') ) || ( $cgi->param('y') ) || $$efi_hr{extractHeight}/2;

    $$efi_hr{AttachmentWidth} = $$efi_hr{extractWidth};
    $$efi_hr{AttachmentHeight} = $$efi_hr{extractHeight};

    $self->ImageSizeMax();
}

sub ImageSizeMax{}

sub ResLevel
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');
    my $cgi=$self->Get('cgi');

    if ( defined $cgi->param('res') )
    {
	$$efi_hr{res} = $cgi->param('res');
	$$efi_hr{extractWidth} = ( $cgi->param('width') ) || int( $$sfi_hr{maxwidth} / ( 2**$$efi_hr{res} ) );
	$$efi_hr{extractHeight} = ( $cgi->param('height') ) || int( $$sfi_hr{maxheight} / ( 2**$$efi_hr{res} ) );
    }
    else
    {
	# Find the resolution level that has the closest width greater
	# than the requested output width so we can scale downward to the
	# exact width. 0 is the level with highest resolution
	my @levels =  ( 0 .. $$sfi_hr{levels} );
	foreach my $nl ( reverse @levels )
	{
	    # Calculate the width of the input file at the current
	    # resolution
	    my $extractWidth  = int( $$sfi_hr{maxwidth} / ( 2**$nl ) );
	    my $extractHeight  = int( $$sfi_hr{maxheight} / ( 2**$nl ) );

	    if ( $extractWidth >= $$efi_hr{swidth} )
	    {
		$$efi_hr{res}=$nl;
		$$efi_hr{extractWidth} = $extractWidth;		
		$$efi_hr{extractHeight} = $extractHeight;

		last;
	    }
	}
    }
}


sub FileDetails
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');

    my $package = $$sfi_hr{format} . 'FileDetails';
    my $packagePath = q{../../../lib/App/FileDetails/} . $package . '.pm';
    if (! -e $packagePath)
    {
	$package = 'FileDetails';
	$packagePath = q{../../../lib/App/FileDetails.pm};
    }

    require("$packagePath");

    my $InitAttr_hr=$self->Get('InitAttr');
    my $fd = $package->new( $$InitAttr_hr{binaries} );

    $fd->GetFileDetails($sfi_hr);

    $fd->FakeNumberOfLevels($sfi_hr);
    $self->CompareDimensions();

}


sub Convert
{
    my $self=shift;

    my $sfi_hr = $self->Get('StartingFileInfo');
    my $efi_hr = $self->Get('EndingFileInfo');

    my $pn = 'Convert';

    my $package = lc($$sfi_hr{format}) . $pn;
    my $packagePath = q{../../../lib/App/Convert/} . $package . '.pm';
    if (! -e $packagePath)
    {
	$package = $pn;
	$packagePath = qq{../../../lib/App/$pn.pm};
    }

    require("$packagePath");

    my $cgi=$self->Get('cgi');
    my $InitAttr_hr=$self->Get('InitAttr');
    my $c = $package->new($sfi_hr, $efi_hr, $cgi, $$InitAttr_hr{'binaries'}, $$InitAttr_hr{'cache'}, $$InitAttr_hr{'cache_file_name_prefix'} );

    $c->Convert();

}

sub Output
{
    my $self=shift;

    my $efi_hr = $self->Get('EndingFileInfo');

    my $conversionSteps_ar = $$efi_hr{conversionSteps};
    my $finalStep_hr=pop(@$conversionSteps_ar);
    my $file = $$finalStep_hr{file};

    $self->ContentDispositionFilename($finalStep_hr);

    return($file) if ( $self->Get('no_output') );

    my $cgi=$self->Get('cgi');

    open(IMAGE, "<$file") or die "Error: unable to open file $file";
    my @fstats = stat IMAGE;
    my $size = $fstats[7];
    my $blksize = $fstats[11];

    my $outputCgi = new CGI("");

    # the goal is for the downloaded file to have a proper name in all cases.
    # unfortunately, it seems nearly impossible, and the best we can do for
    # now is to give it a proper name in almost all cases.
    my $contentdisposition = 'filename='  . $$finalStep_hr{contentdispositionfilename};
    if ( $cgi->param('attachment') eq '1' )
    {
	$contentdisposition = 'attachment; ' . $contentdisposition;
    }

    print $outputCgi->header(-type=>$$efi_hr{contenttype},
			     -Content_Disposition=> $contentdisposition,
			     -length=>$size);

    print while (<IMAGE>);

    return($file);
}

sub ContentDispositionFilename
{
    my $self=shift;
    my ($step_hr) = (@_);

    $$step_hr{contentdispositionfilename} = $$step_hr{base} . '.' . $$step_hr{format};
}


sub CacheCleanup
{
    my $self=shift;

    my $InitAttr_hr=$self->Get('InitAttr');

    return if (! $$InitAttr_hr{'cache_cleanup_prefix'} );

    die unless opendir DIR, $$InitAttr_hr{'cache'};
    foreach my $file ( readdir DIR )
    {
	if ( $file =~ m/^$$InitAttr_hr{'cache_cleanup_prefix'}/ )
	{
	    my $path = $$InitAttr_hr{'cache'} . '/' . $file;
	    # if older than about 15 minutes, delete
	    if ( (-f $path) && ( -M $path > .01) )
	    {
		unlink $path;
	    }
	}
    }
    closedir DIR;

}


sub CompareDimensions
{
    my $self=shift;
    my $sfi_hr = $self->Get('StartingFileInfo');

    my ($big, $small);

    if ( $$sfi_hr{width} > $$sfi_hr{height} )
    {
	$$sfi_hr{bigparam}='swidth';
	$$sfi_hr{smallparam}='sheight';
	$big=$$sfi_hr{width};
	$small=$$sfi_hr{height};
    }
    else
    {
	$$sfi_hr{bigparam}='sheight';
	$$sfi_hr{smallparam}='swidth';
	$big=$$sfi_hr{height};
	$small=$$sfi_hr{width};
    }

    $$sfi_hr{small2big_ratio}=$small/$big;
    $$sfi_hr{width2height_ratio}=$$sfi_hr{width}/$$sfi_hr{height};
    $$sfi_hr{height2width_ratio}=$$sfi_hr{height}/$$sfi_hr{width};

}





# ----------------------------------------------------------------------
1;



