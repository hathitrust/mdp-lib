package View::Skin;



=head1 NAME

View::Skin;  (skin)

=head1 DESCRIPTION

This class encapsulates the logic to determine the skin to apply
according and based on the skin to provide paths to XSL stylesheets
that implement that skin.

=head1 VERSION

$Id: Skin.pm,v 1.11 2009/09/02 14:29:46 pfarber Exp $

=head1 SYNOPSIS

my $skin = new View::Skin($C);

$skin->get_name($C);

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

use CGI;

use Context;
use Utils;
use Debug::DUtils;

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}

use constant DEFAULT_SKIN    => 'default';
use constant MICHIGAN_SKIN   => 'default';
use constant WISCONSIN_SKIN  => 'default';
use constant INDIANA_SKIN    => 'default';
use constant CALIFORNIA_SKIN => 'default';
use constant CRMS_SKIN       => 'crms';


# ---------------------------------------------------------------------

=item _initialize

Initialize View::Skin object.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
}


# ---------------------------------------------------------------------

=item __get_skin_by_location

Description

=cut

# ---------------------------------------------------------------------
sub __get_skin_by_location
{
    my $self = shift;
    my $C = shift;

    my $skin_name = DEFAULT_SKIN;

    my $sdr_inst = $ENV{'SDRINST'};
    if ($sdr_inst eq 'wisc')
    {
        $skin_name = WISCONSIN_SKIN;
    }
    elsif ($sdr_inst eq 'uom')
    {
        $skin_name = MICHIGAN_SKIN;
    }
    elsif ($sdr_inst eq 'ind')
    {
        $skin_name = INDIANA_SKIN;
    }
    elsif ($sdr_inst eq 'ucal')
    {
        $skin_name = CALIFORNIA_SKIN;
    }

    return $skin_name;
}



# ---------------------------------------------------------------------

=item get_skin_name

Primarily based on SDRINST but other logic could also apply here.
This is all hardcoded currently.  This will change when we elaborate
skin configutation.

Current Algorithm:

if (UM authenticated) then
     if (UM friend authenticated) then
        skin is determined by institution (could be no institution)
     else
        skin is um
     endif
else
   skin is determined by institution (could be no institution)
endif


=cut

# ---------------------------------------------------------------------
sub get_skin_name
{
    my $self = shift;
    my $C = shift;

    my $skin_name;

    if ($C->has_object('Auth')) {
        my $auth = $C->get_object('Auth');
        if ($auth->is_logged_in()) {
            if ($auth->login_realm_is_friend()) {
                $skin_name = $self->__get_skin_by_location($C);
            }
            else {
                $skin_name = MICHIGAN_SKIN;
            }
        }
        else {
            $skin_name = $self->__get_skin_by_location($C);
        }
    }
    else {
        $skin_name = $self->__get_skin_by_location($C);
    }

    # Debugging URL parameter to force a skin
    my $skin_key = $C->get_object('CGI')->param('skin');
    $skin_name = $skin_key ? $skin_key : $skin_name;

    ASSERT($skin_name, qq{Skin name algorithm failed});
    return $skin_name;
}



1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008, The Regents of The University of Michigan, All Rights Reserved

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
