package View::Fallback;


=head1 NAME

View::Fallback (fb);

=head1 DESCRIPTION

This class encapsulates the logic to construct a fallback path.  The
current design supports 3 level of priority.  In order these are:

1) Skin

2) Collection

3) Base

These priorities are enforced in the Base XSL by calling XSL templates
to load CSS/JS/XSL in this order.  If, for example, there is no
skin.css and a skin.xsl containing a template to being the custom CSS
into the load via a <script> tag, the systems falls back to the
default empty skin.xsl in the Base path.

Skins/Collections are typically CSS overrides of Base.  Javascript and
even XSL can fallback as well but this should be less common.

=head1 VERSION

$Id: Fallback.pm,v 1.10 2009/12/21 21:36:21 pfarber Exp $

=head1 SYNOPSIS

use View::Fallback;

my $fb = new View::Fallback($C);

my $fallback_path_arr_ref = $fb->get_fallback_path($C);

=head1 METHODS

=over 8

=cut


use strict;

use CGI;

use Context;
use View::Skin;
use Utils;
use Debug::DUtils;


# Class data - we expect this will move to a database table as the
# number of collections with a special look and feel or of skins
# increases. 

# NOTE: Skin name constants must agree with values in Skin.pm
my %g_skin_map =
    (
     'default'   => '',
     'michigan'  => '/web/m/michigan',
     'wisconsin' => '/web/w/wisconsin',
     'crms'      => '/pt/web/crms',
     'crmsworld' => '/pt/web/crms',
     'mobile'   =>  '/pt/web/mobile',
     'mobilewayf' => '/wayf/web/mobile',
     'alicorn'   => '/pt/web/alicorn',
     'unicorn'   => '/pt/web/unicorn',
     '2021'      => '/pt/web/2021',
    );

# Map internal coll_ids to a permanent collection name '0000000000' is
# a NOOP.  Multiple IDs that map to the same identifier allow
# development of collections that do not yet exist or are not yet
# public but owned by others
my %g_coll_id_map = 
    (
     # '1729205717' => 'umpress:UM_Press',    # pfarber
     # '383'        => 'umpress:UM_Press',    # suzchap
     # '622231186'  => 'umpress:UM_Press',    # umpress
     # '1715299752' => 'aadl:moaa_resources',
     # '1874608773' => 'aadl:moaa',
     # '0000000000' => 'umhistmath',
     # '781708252'  => 'keanuniv:NJ_History_Project',
     # '247770968'  => 'estc:estc',
    );

# Map permanent collection name to web directory path
my %g_collection_map = 
    (
     'aadl:moaa_resources'         => '/mb/web/m/moaa-cb1',
     'aadl:moaa'                   => '/mb/web/m/moaa-cb2',
     'umpress:UM_Press'            => '/mb/web/u/umpress',
     'umhistmath'                  => '',
     'keanuniv:NJ_History_Project' => '/mb/web/k/kean',
     'estc:estc'                   => '/mb/web/e/estc',
    );

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize View::Fallback object.

=cut

# ---------------------------------------------------------------------
sub _initialize 
{
    my $self = shift;
    my $C = shift;
    
    my $use_local_paths = DEBUG('local');
    my $key = $use_local_paths ? 'local_base_fallback_paths' : 'base_fallback_paths';
    my @base_fallback_paths = $C->get_object('MdpConfig')->get($key);

    $self->{'base_fallback_paths'} = \@base_fallback_paths;
}


# ---------------------------------------------------------------------

=item get_fallback_path

COnstruct a fallback path that prioritizes Skin, Collection and Base.

=cut

# ---------------------------------------------------------------------
sub get_fallback_path
{
    my $self = shift;
    my $C = shift;

    my @fallback_path = ();
    
    # Base
    my $base_fallback_arr_ref = $self->get_base_fallback_path($C);
    @fallback_path = @$base_fallback_arr_ref;
    
    # Collection
    my $cgi = new CGI($C->get_object('CGI'));
    my $coll_id = $cgi->param('c');
    my $coll_path = $g_collection_map{$g_coll_id_map{$coll_id}};
    if ($coll_path)
    {
        @fallback_path = ($coll_path, @fallback_path);
    }

    # Skin
    my $skin = new View::Skin($C);
    my $skin_name = $skin->get_skin_name($C);

    # Local configuration
    my $config = $C->get_object('MdpConfig');
    if ( $config->has('skin_map') ) {
        my %tmp = split(/[\|=]/, $config->get('skin_map'));
        @g_skin_map{ keys %tmp } = values %tmp;
    }

    ASSERT(grep(/$skin_name/, keys %g_skin_map), qq{Skin=$skin_name not found in skin map});

    my $skin_path = $g_skin_map{$skin_name};
    if ($skin_path)
    {
        @fallback_path = ($skin_path, @fallback_path);
    }
    
    return \@fallback_path;
}


# ---------------------------------------------------------------------

=item get_base_fallback_path

Description

=cut

# ---------------------------------------------------------------------
sub get_base_fallback_path
{
    my $self = shift;
    my $C = shift;

    return $self->{'base_fallback_paths'};
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
