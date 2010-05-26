package MetaDataGetter;




=head1 NAME

MB

=head1 DESCRIPTION

This class does X.

=head1 VERSION

$Id: MetaDataGetter.pm,v 1.1 2009/08/13 15:10:52 tburtonw Exp $

=head1 SYNOPSIS

Coding example

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

use LWP::UserAgent;

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


# ---------------------------------------------------------------------

=item _initialize

Initialize 

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my $C = shift;
    
}

# ---------------------------------------------------------------------
sub get_metadata
{
    my ($ids) = shift;
    ASSERT(0, qq{get_metadata() in __PACKAGE__ is pure virtual});
}

# ---------------------------------------------------------------------
1;
