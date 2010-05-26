package jp2FileDetails;

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


use vars qw( @ISA );
@ISA = qw( FileDetails );

use strict;
use IPC::Open3;

sub _initialize
{
    my $self = shift;
    $self->SUPER::_initialize(@_);
    $self->Set('KduInfoCommand', $self->GetBinary('jp2info') . q{ -i __INPUT_JP2__ -reduce 10 -record __RECORD_TXT__ ; cat __RECORD_TXT__; rm __RECORD_TXT__  } );
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
    my $jp2InfoCommand = $self->Get('KduInfoCommand');
    my $file = $$fileinfo_hr{file};

    my @fnParts = split(/\//, $file);
    my $fnOnly = $fnParts[$#fnParts];
    my ($caller) = caller;
    my $temp = q{/tmp/} . $caller . qq{_$fnOnly\.txt};

    $jp2InfoCommand =~ s,__INPUT_JP2__,'$file',;
    $jp2InfoCommand =~ s,__RECORD_TXT__,'$temp',g;

#    print $jp2InfoCommand . qq{\n};

    my $pid = open3('IN', 'OUT', 'ERR', $jp2InfoCommand);
    my @stdin = <IN>;
    my @stdout = <OUT>;
    my @stderr = <ERR>;
    waitpid $pid, 0;

    my $jp2Info = join('', @stdout);
    my $jp2Error = join('', @stderr);

#    print $jp2Info;

#    if ($? != 0) { exit(qq{GetJp2FileParameters: command="$jp2InfoCommand" failed with code="$?"} ) };

    if ( ( $jp2Error !~ m/non-existent resolution/i ) || ( ! $jp2Info) || ( $jp2Info !~ m,Clevels,) )
    {
	$self->Set('success', 0);
	$self->Set('errormsg', qq{FileDetails::jp2FileDetails::GetFileDetails: failed for jp2 file=\"$$fileinfo_hr{file}\" \nwith cmd=$jp2InfoCommand with \noutput=$jp2Info and \nerror=$jp2Error} );
	return;
    }

    $self->_ParseFilePath( $fileinfo_hr );
    $self->_ParseFileDetails( $jp2Info, $fileinfo_hr );

    $$fileinfo_hr{width} = $$fileinfo_hr{maxwidth};
    $$fileinfo_hr{height} = $$fileinfo_hr{maxheight};

    $self->Set('success', 1);
}


# ----------------------------------------------------------------------
# NAME         : _ParseFileDetails
# PURPOSE      : Take the jp2 information returned by kdu_expand -quiet
#                and parse it for three particular values
# INPUT        : String of text that was returned from the caller's call
#                to kdu_expand
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub _ParseFileDetails
{
    my $self = shift;
    my ($jp2Info, $fileinfo_hr) = (@_);

    # ?????????? or split on \n??????
    my @lines = split( /\x0A/, $jp2Info );

    my ( $Ssize )   =  grep(/^Ssize/, @lines);
    my ( $Clevels ) =  grep(/^Clevels/, @lines);

    $Ssize =~ m/Ssize=\{([^,]*),([^\}]*)\}/i;
    $$fileinfo_hr{maxheight} = $1;
    $$fileinfo_hr{maxwidth} = $2;

    ( undef, $$fileinfo_hr{levels} ) = split( /\=/, $Clevels );
    chomp( $$fileinfo_hr{levels} );

}


# ----------------------------------------------------------------------
1;
