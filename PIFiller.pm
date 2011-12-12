package PIFiller;


=head1 NAME

PIFiller (pif)

=head1 DESCRIPTION

This class is an abstract class whose subclasses provide methods to
process the PIs for a given template.

Subclasses of this class inherit the PI_handler Perl attribute handler
herein which populates class data with the name of the PI handled and
the coderef of the handler method for later binding to the PIs in a
given template.

=head1 SYNOPSIS

The naming convention is

sub "handle_" . SOME_PI_NAME . "_PI" : PI_handler(SOME_PI_NAME)

So the COLL_LIST PI handler in an implementation of the PIFiller class
would be declared like this

sub handle_COLL_LIST_PI : PI_handler(COLL_LIST)
{
   my $self = shift;
   ...
}


=head1 METHODS

=over 8

=cut

BEGIN
{
    if ( $ENV{'HT_DEV'} )
    {
        require "strict.pm";
        strict::import();
    }
}

use Attribute::Handlers;

sub new
{
    my $class = shift;

    my $self = {};
    bless $self, $class;

    return $self;
}




# ---------------------------------------------------------------------

=item PI_handler : ATTR

Record the occurrence of a PI handler definition in a Action subclass
in the %PI_to_handler_map

PI handlers in subclasses of Root should be declared as described in the SYNOPSIS

Note: this very special subroutine runs very early in the CHECK phase
of compilation.  It is called by Perl not by the application as such.

=cut

# ---------------------------------------------------------------------
my %PI_to_handler_map;
sub PI_handler
    :ATTR
{
    my ($package, $symbol, $PI_handler, $attr, $PI_name, $phase) = @_;
    
    $PI_name = $PI_name->[0] if ( ref($PI_name) eq 'ARRAY' );
    $PI_to_handler_map{$PI_name} = $PI_handler;
}




# ---------------------------------------------------------------------

=item get_PI_handler_mapping

Return the map (hash) of PIs to PI handler code references.  Each PI
handler must use the special ATTR syntax to define which PI is is
designed to handle.

=cut

# ---------------------------------------------------------------------
sub get_PI_handler_mapping
{
    my $self = shift;
    my $C = shift;
    return \%PI_to_handler_map;
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


