package Operation;


=head1 NAME

Operation (op)

=head1 DESCRIPTION

This class implements the abstract interface to an Operation.  An
Operation can be any part of an Action which is not directly involved
with supplying the dynamic content for a PI.  That is the job of a
PIFiller.

It validates and defaults the URL since it is closest to the point
where the URL parameters are meaningful.

Operations are typically database queries, updates and search engine
queries.  The class can encapsulate the results of the opeation and
pass them on by requests from the PIFiller.  Both Operation and
PIFiller classes are coordinated by the Action class.


=head1 VERSION

$Id: Operation.pm,v 1.12 2008/12/19 18:36:13 pfarber Exp $

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

use Utils;
use Action::Bind;
use Context;

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

Initialize Operation base class

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my ($C, $act) = @_;

    # Containing Facade
    $self->{'action'} = $act;
}



# ---------------------------------------------------------------------

=item execute_operation

Base class method to validate and default CGI parameters.  Derived
classes must call $self->SUPER::execute_operation(@_) in their
implementation of this method.

=cut

# ---------------------------------------------------------------------
sub execute_operation
{
    my $self = shift;
    my $C = shift;

    $self->assert_n_default_url_params($C);
    $self->validate_url_params($C);

    my $op_name = ref($self);
    my $cgi = $C->get_object('CGI');

    # Are all the required parameters for this Operation present?
    foreach my $rparam (keys %{$Action::Bind::g_operation_params{$op_name}{'req_params'}})
    {
        silent_ASSERT(defined $cgi->param($rparam),
                      qq{missing required parameter="$rparam"});
    }

    # Default any missing optional parameters
    foreach my $oparam (keys %{$Action::Bind::g_operation_params{$op_name}{'opt_params'}})
    {
        if (! defined($cgi->param($oparam)))
        {
            $cgi->param($oparam,
                        $Action::Bind::g_operation_params{$op_name}{'opt_params'}{$oparam});
        }
    }
}


# ---------------------------------------------------------------------

=item validate_url_params

Test important URL parameter values against regular expressions.
TODO: maybe test values against the database too.

=cut

# ---------------------------------------------------------------------
sub validate_url_params
{
    my $self = shift;
    my $C = shift;

    # Validate incoming URL parameters
    my $cgi = $C->get_object('CGI');

    foreach my $p ($cgi->param())
    {
        if (grep(/$p/, keys %Action::Bind::g_validator_for_param))
        {
            my $val = $cgi->param($p);
            my $re = $Action::Bind::g_validator_for_param{$p};
            my $compiled_re = qr/$re/;
            silent_ASSERT(scalar($val =~ m,$compiled_re,), 
                          qq{Invalid value="$val" for URL parameter="$p"});
        }
        else
        {
            $cgi->delete($p);
        }
    }
}

# ---------------------------------------------------------------------

=item assert_n_default_url_params

For the given Operation: make sure the required params are present and
default the optional params if not supplied.

=cut

# ---------------------------------------------------------------------
sub assert_n_default_url_params
{
    my $self = shift;
    my $C = shift;

    my $ab = $C->get_object('Bind');
    my $cgi = $C->get_object('CGI');
    my $params_hashref = $ab->get_operation_params_hashref($C, ref($self));

    # First: required
    my $required_params_hashref = $$params_hashref{'required'};
    foreach my $param (keys %$required_params_hashref)
    {
        silent_ASSERT(defined($cgi->param($param)),
                      qq{Missing required parameter="$param" for Operation:} . ref($self));
    }

    # Next: optional
    my $optional_params_hashref = $$params_hashref{'optional'};
    foreach my $param (keys %$optional_params_hashref)
    {
        # CGI params override the optional defaults
        my $param_val = $cgi->param($param);
        if (!defined($param_val))
        {
            $cgi->param($param, $$optional_params_hashref{$param});
        }
    }
}



# ---------------------------------------------------------------------

=item get_action

Description

=cut

# ---------------------------------------------------------------------
sub get_action
{
    my $self = shift;
    return $self->{'action'};
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

