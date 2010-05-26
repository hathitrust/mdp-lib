package App;


=head1 NAME

App (app)

=head1 DESCRIPTION

This class provides a framework for high level application logic not
appropriate to the Controller.

=head1 VERSION

$Id: App.pm,v 1.15 2009/12/15 16:27:07 pfarber Exp $

=head1 SYNOPSIS

my $app = new App($C, 'someapp');

my $ctl = new MBooks::Controller($C, $dph, $vw);

$app->run_application($C, $ctl);


=head1 METHODS

=over 8

=cut

BEGIN {
    if ($ENV{'HT_DEV'}) {
        require "strict.pm";
        strict::import();
    }
}

use Utils;
use Debug::DUtils;
use Context;
use Controller;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}




# ---------------------------------------------------------------------

=item _initialize

Initialize App object.

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my $C = shift;
    my $name = shift;
    my $production_disabled = shift;

    $self->{'application_name'} = $name;
    $self->{'production_disabled'} = $production_disabled;

    # See if the UNAVAILABLE envvar switch is on due to server
    # maintenance ...
    $self->test_availability();

    # ... or set it in code if app is production disabled except for
    # development
    $self->__test_app_enabled();
}


# ---------------------------------------------------------------------

=item run_application

Obvious

=cut

# ---------------------------------------------------------------------
sub run_application {
    my $self = shift;
    my ($C, $ctl) = @_;

    $ctl->run_controller($C);
}

# ---------------------------------------------------------------------

=item get_app_name

Description

=cut

# ---------------------------------------------------------------------
sub get_app_name {
    my $self = shift;
    my $C = shift;

    return $self->{'application_name'};
}


# ---------------------------------------------------------------------

=item __test_app_enabled

Description: Temporary switch to allow development subnet to see full
functionality not yet available in production.  

=cut

# ---------------------------------------------------------------------
my $g_override_enabled_test = 1;

sub __test_app_enabled {
    my $self = shift;
    
    if ($ENV{'HT_DEV'}) {
        return 1;
    }
    else
    {
        # Skip tests if flag is set
        return 1
            if ($g_override_enabled_test);

        # Can everyone see me in production or test for
        # debugging_enabled() allows me to run just from development
        # subnet
        if ($self->{'production_disabled'}) {
            if (! Debug::DUtils::debugging_enabled()) {
                $ENV{'UNAVAILABLE'} = 1;
                ASSERT(0);
            }
        }
    }
}




# ---------------------------------------------------------------------

=item test_availability

Determine whether this app is allowed to run by testing the
UNAVAILABLE environment variable.

UNAVAILABLE can be set in the virtual host for maintenance or
programatically for a variety of reasons.

When set and followed by any assertion failure, it triggers the
display of a friendly page explaining the outage.

=cut

# ---------------------------------------------------------------------
sub test_availability
{
    my $self = shift;

    # Set by the virtual host for maintenance
    ASSERT(0)
        if (defined($ENV{'UNAVAILABLE'}));
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007 ©, The Regents of The University of Michigan, All Rights Reserved

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
