package Action::Bind;


=head1 NAME

Action::Bind (ab)

=head1 DESCRIPTION

This class encapsulates the bindings that associate URL parameters,
action names, and action handlers.  It provides a query
interface for these bindings.

Its application specific configuration is passed as a filename which
is required when instantiated.  The config data becomes package global.

=head1 VERSION

$Id: Bind.pm,v 1.18 2008/06/12 19:00:03 pfarber Exp $

=head1 SYNOPSIS

$ab = new Action::Bind('bindings.pl');


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

use Utils;


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

Initialize Action::Bind object.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my $C = shift;
    my $config_filename = shift;

    ASSERT(-e "$config_filename",
           qq{"Could not find config file $config_filename"});

    eval
    {
        require $config_filename;
    };
    ASSERT(!$@, qq{Invalid config file $config_filename. Error: $@});

    $self->set_action_name($C);
}



# ---------------------------------------------------------------------

=item set_action_name

Default to the default action

=cut

# ---------------------------------------------------------------------
sub set_action_name
{
    my $self = shift;
    my $C = shift;
    ASSERT(0, qq{_initialize() in __PACKAGE__ is pure virtual});
}


# ---------------------------------------------------------------------

=item get_action_name

Return the action name set by set_action_name()

=cut

# ---------------------------------------------------------------------
sub get_action_name
{
    my $self = shift;
    my $C = shift;

    my $action_name = $self->{'action_name'};
    silent_ASSERT($action_name, qq{Action name not set});

    return $action_name;
}

# ---------------------------------------------------------------------

=item get_action_type

Return the action type from the global bindings

=cut

# ---------------------------------------------------------------------
sub get_action_type
{
    my $self = shift;
    my $C = shift;

    my $action_name = $self->get_action_name($C);
    my $action_type = $Action::Bind::g_action_bindings{$action_name}{'action_type'};

    return $action_type;
}

# ---------------------------------------------------------------------

=item get_action_template_name

Return the action handler's template name that corresponds to the
current action

=cut

# ---------------------------------------------------------------------
sub get_action_template_name
{
    my $self = shift;
    my $C = shift;

    my $action_name = $self->get_action_name($C);
    my $cgi = $C->get_object('CGI');

    my $page = $cgi->param('page') || 'default';

    my $ui_hashref = $Action::Bind::g_action_bindings{$action_name}{'view'}{$page};
    my $template_name = $$ui_hashref{'template'};

    return $template_name;
}

# ---------------------------------------------------------------------

=item get_action_operation_names

Return the class names of the Operation subclasses for this action.

=cut

# ---------------------------------------------------------------------
sub get_action_operation_names
{
    my $self = shift;
    my ($C, $p_action_name) = @_;

    my $action_name = $p_action_name ? $p_action_name : $self->get_action_name($C);
    my $operation_name_arr_ref =
        $Action::Bind::g_action_bindings{$action_name}{'operations'};

    return $operation_name_arr_ref;
}


# ---------------------------------------------------------------------

=item get_early_op_names

Return the names of the Operations performed globally BEFORE the
Action-specific operations are performed.

=cut

# ---------------------------------------------------------------------
sub get_early_op_names
{
    my $self = shift;
    my $C = shift;

    return $Action::Bind::g_early_operations;
}




# ---------------------------------------------------------------------

=item get_late_op_names

Return the names of the Operations performed globally AFTER the
Action-specific operations are performed.

=cut

# ---------------------------------------------------------------------
sub get_late_op_names
{
    my $self = shift;
    my $C = shift;

    return $Action::Bind::g_late_operations;
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

