package Context;

=head1 NAME

Context  (C)

=head1 DESCRIPTION

This is a Container class to make it easy to pass around the complete
context for the application in a single object.  It stores each object
by its ref() for later retrieval.

It also provides a convenient location for transient session data.

It is a singleton.

=head1 SYNOPSIS

 $C = new Context;

 $cgi = new CGI;
 $C->set_object('CGI', $cgi);
 $C->get_object('CGI');

 $so = new Session;
 $C->set_object('Session', $ses);
 $C->get_object('Session');
 $C->get_object('Session')->set_persistent($key, $data) ;


=head1 METHODS

=over 8

=cut

use strict;
use Utils;

my $oneTrueSelf;

sub new {
    unless ( defined($oneTrueSelf) ) {
        my $type = shift;
        my $this = {};
        $oneTrueSelf = bless $this, $type;
    }
    return $oneTrueSelf;
}


# ---------------------------------------------------------------------

=item dispose

Invoke the terminal (dispose) methods of the contained objects in Context

=cut

# ---------------------------------------------------------------------
sub dispose
{
    my $self = shift;
    
    # dispose of the Database LAST!!!
    foreach my $object_key (sort { $a eq 'Database' ? 1 : $b eq 'Database' ? -1 : ( $a cmp $b ) } keys %$self)
    {
        next if ( $object_key eq 'Database' );
        my $object = $self->get_object($object_key);
        my $package = ref($object);
        if (exists &{"${package}::dispose"})
        {
            $object->dispose();
        }
    }

    my $db = $self->get_object("Database", 1);
    if ( ref($db) ) { $db->dispose(); }
    
    $oneTrueSelf = undef;
}





# ---------------------------------------------------------------------

=item set_object

Add an object to the container keyed by its package name

=cut

# ---------------------------------------------------------------------
sub set_object
{
    my $self = shift;
    my $object_key = shift;
    my $object = shift;
    my $no_assert = shift;
    
    my $package = ref($object);
    ASSERT(scalar($package =~ m,(.*::)?$object_key(.*?::)?,), 
           qq{Incorrect key="$object_key" for $package})
        unless ($no_assert);

    $self->{$object_key} = $object;
}


# ---------------------------------------------------------------------

=item get_object

Get an object from the container by its package name.

=cut

# ---------------------------------------------------------------------
sub get_object
{
    my $self = shift;
    my $object_key = shift;
    my $no_assert = shift;
    
    ASSERT(exists($self->{$object_key}), qq{'$object_key' not found in Context})
        unless ($no_assert);

    return $self->{$object_key};
}

# ---------------------------------------------------------------------

=item has_object

Test for an object from the container by its package name.

=cut

# ---------------------------------------------------------------------
sub has_object
{
    my $self = shift;
    my $object_key = shift;
    
    return exists($self->{$object_key});
}


1;

__END__

=head1 AUTHORS

Phillip Farber, University of Michigan, pfarber@umich.edu
Roger Espinoza, University of Michigan, roger@umich.edu

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
