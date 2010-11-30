package Action;

=head1 NAME

Action (act)

=head1 DESCRIPTION

This class is a version of the Facade design pattern.  It provides a
common interface to and supports an execution environment for
instances of the Operation class and the PIFiller class.

The Operation class implements mainly database operations.

The PIFiller class implements the PI handlers for a given template.

Together, these components provide the complete functionality of an
Action.

=head1 VERSION

$Id: Action.pm,v 1.25 2010/02/03 20:31:16 pfarber Exp $

=head1 SYNOPSIS

$act->execute_action($C);

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

use Debug::DUtils;
use Utils;
use ObjFactory;
use Operation::Status;

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

Initialize Action

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my $C = shift;

    # Propagate data if a prior action exists
    my $act = $C->get_object('Action', 1);
    if ($act)
    {
        my $error_ref = $act->get_error_record();
        $self->set_error_record($C, $error_ref);
    }

    my $ab = $C->get_object('Bind');
    $self->set_name($ab->get_action_name($C));
    $self->set_type($ab->get_action_type($C));

    $self->{'of'} = new ObjFactory;

    my $pifiller_name = $ab->get_action_pifiller_name($C);
    if ($pifiller_name)
    {
        my %of_pif_attrs = (
                            'class_name' => $pifiller_name,
                            'parameters' => {'C' => $C},
                           );
        my $pif = $self->instantiate_object($C, \%of_pif_attrs);
        $self->set_PI_filler($pif);
    }

    my @operations;
    my $operation_name_arr_ref = $ab->get_action_operation_names($C);
    foreach my $op_name (@$operation_name_arr_ref)
    {
        my %of_op_attrs = (
                           'class_name' => $op_name,
                           'parameters' => {
                                            'C'   => $C,
                                            'act' => $self,
                                           },
                          );
        my $op = $self->instantiate_object($C, \%of_op_attrs);
        push(@operations, $op);
    }

    $self->set_operations(\@operations);

    # Child initialization
    $self->after_initialize($C);
}


# ---------------------------------------------------------------------

=item after_initialize

Pure virtual method must be overridden in derived classes to effect
initialization in children but called from parent.  Uses the Template
Method Design Pattern

=cut

# ---------------------------------------------------------------------
sub after_initialize
{
    ASSERT(0, qq{Pure virtual method after_initialize() not implemented in child});
}


# ---------------------------------------------------------------------

=item execute_action

Run each of this Action's Operation objects.  Database actions create
Action facade member data that UI actions read.  Since the Actions can
separated by redirects, the facade member data is saved on and retrieved
from the Session.

=cut

# ---------------------------------------------------------------------
sub execute_action
{
    my $self = shift;
    my $C = shift;

    my $type = $self->get_type($C);
    my $op_arr_ref = $self->get_operations();

    my $status = $Operation::Status::ST_OK;

    if ( $type eq 'database')
    {
        $status = $self->execute_early_ops($C)
            if ($status == $Operation::Status::ST_OK);

        foreach my $op (@$op_arr_ref)
        {
            $status = $op->execute_operation($C, $self)
                if ($status == $Operation::Status::ST_OK);
        }

        $status = $self->execute_late_ops($C, $self)
            if ($status == $Operation::Status::ST_OK);

        $self->WRITE_facade_data($C);
    }
    elsif ($type eq 'UI')
    {
        $self->READ_facade_data($C);

        $status = $self->execute_early_ops($C, $self)
            if ($status == $Operation::Status::ST_OK);

        # View can have Operations as well as Builders.  Just do the
        # Operations here. View is responsible for running Builders
        foreach my $op (@$op_arr_ref)
        {
            $status = $op->execute_operation($C, $self)
                if ($status == $Operation::Status::ST_OK);
        }

        $self->execute_late_ops($C, $self)
            if ($status == $Operation::Status::ST_OK);
    }
    else
    {
        ASSERT(0, qq{Invalid action type="$type"});
    }

    return $status;
}

# ---------------------------------------------------------------------

=item WRITE_facade_data

WRITE: Database Action facade member data for use by UI Action.

Must be smart to allow multiple Actions in a row to save their
contribution to facade member data persistently: Merge current facade
member data with any pre-existing facade member data set by previous
'database' Actions.

Each collection of facade member data
corresponding to the execution of an Action is segregated with its own
read flag.  Only segregated facade member data collections with the
flag set to zero are read back from the session to the Action's member
data.

=cut

# ---------------------------------------------------------------------
sub WRITE_facade_data
{
    my $self = shift;
    my $C = shift;

    my $type = $self->get_type($C);
    ASSERT(($type eq 'database'),
           qq{Illegal write of Facade data by Action type="$type"});

    # Mark this collection of facade member data as not read yet by a
    # UI Action.
    $self->set_persistent_facade_member_data($C, 'facade_data_read', 0);
    my $current_facade_dataref = $self->get_all_facade_member_data($C);

    # Save this collection of facade member data segregated with its
    # flag on the session keyed by the name of the Action
    my $ses = $C->get_object('Session');
    $ses->set_persistent_subkey('facade', $self->get_name(), $current_facade_dataref);
}


# ---------------------------------------------------------------------

=item READ_facade_data

READ: Database Action facade member data for use by UI Action.  Handle
logic of debug=xml,xsltwrite to persist the data but not reuse it, if
not debugging.

=cut

# ---------------------------------------------------------------------
sub READ_facade_data
{
    my $self = shift;
    my $C = shift;

    my $type = $self->get_type($C);
    ASSERT(($type eq 'UI'),
           qq{Illegal read of Facade data by Action type="$type"});

    my $ses = $C->get_object('Session');

    if (DEBUG('xml,xsltwrite'))
    {
        my %all_facade_data;
        my $all_segregated_facade_data = $ses->get_persistent('facade');
        foreach my $key (keys %$all_segregated_facade_data)
        {
            %all_facade_data =
                (%all_facade_data, %{$$all_segregated_facade_data{$key}});
        }
        $self->set_all_facade_member_data($C, \%all_facade_data);
    }
    else
    {
        # Flip idempotent 'accessed' switch so we don't reuse this
        # data for each segregation that hasn't been read yet.
        # Already read segregations are left on the session for
        # debugging persistence but not communicated to the UI Action
        # Facade.

        my %unread_facade_data;

        my $all_segregated_facade_data = $ses->get_persistent('facade');
        foreach my $key (keys %$all_segregated_facade_data)
        {
            if (! $$all_segregated_facade_data{$key}{'facade_data_read'})
            {
                # Not read. Merge this segregation of Facade Action
                # data from Session into the Action Facade member date
                # and set the read switch
                $$all_segregated_facade_data{$key}{'facade_data_read'} = 1;
                %unread_facade_data =
                    (%unread_facade_data, %{$$all_segregated_facade_data{$key}});

                # record this segregation persistently on the Session
                # to preserve the new 'facade_data_read' settings
                $ses->set_persistent_subkey('facade', 
                                            $key, 
                                            $$all_segregated_facade_data{$key});
            }
        }

        $self->set_all_facade_member_data($C, \%unread_facade_data);
    }
}


# ---------------------------------------------------------------------

=item execute_early_ops

Run global early Operations

=cut

# ---------------------------------------------------------------------
sub execute_early_ops
{
    my $self = shift;
    my $C = shift;

    my $status = $Operation::Status::ST_OK;

    my $ab = $C->get_object('Bind');
    foreach my $op_name (@{ $ab->get_early_op_names($C) })
    {
        my %of_op_attrs = (
                           'class_name' => $op_name,
                           'parameters' => {
                                            'C'   => $C,
                                            'act' => $self,
                                           },
                          );
        my $op = $self->instantiate_object($C, \%of_op_attrs);
        $status = $op->execute_operation($C)
            if ($status == $Operation::Status::ST_OK);
    }

    return $status;
}




# ---------------------------------------------------------------------

=item execute_late_ops

Run global late Operations

=cut

# ---------------------------------------------------------------------
sub execute_late_ops
{
    my $self = shift;
    my $C = shift;

    my $status = $Operation::Status::ST_OK;

    my $ab = $C->get_object('Bind');
    foreach my $op_name (@{ $ab->get_late_op_names($C) })
    {
        my %of_op_attrs = (
                           'class_name' => $op_name,
                           'parameters' => {
                                            'C'   => $C,
                                            'act' => $self,
                                           },
                          );
        my $op = $self->instantiate_object($C, \%of_op_attrs);
        $status = $op->execute_operation($C)
            if ($status == $Operation::Status::ST_OK);
    }

    return $status;
}


# ---------------------------------------------------------------------

=item instantiate_object

Helper routine

=cut

# ---------------------------------------------------------------------
sub instantiate_object
{
    my $self = shift;

    my $C = shift;
    my $of_attrs_ref = shift;

    my $of = $self->get_object_factory();
    return $of->create_instance($C, $of_attrs_ref);
}



# ---------------------------------------------------------------------

=item get_PI_handler_mapping

Facade method to PIFiller::get_PI_handler_mapping, which see

=cut

# ---------------------------------------------------------------------
sub get_PI_handler_mapping
{
    my $self = shift;
    my $C = shift;

    my $pif = $self->get_PI_filler();
    ASSERT($pif, qq{PIFiller not set in Action=} . ref($self));

    return $pif->get_PI_handler_mapping($C);
}



# ---------------------------------------------------------------------

=item get_object_factory

Accessor for the class ObjFactory

=cut

# ---------------------------------------------------------------------
sub get_object_factory
{
    my $self = shift;
    return $self->{'of'};
}




# ---------------------------------------------------------------------

=item get_PI_filler

Return the PI_filler set by a subclass of this Action handler

=cut

# ---------------------------------------------------------------------
sub get_PI_filler
{
    my $self = shift;

    my $pif = $self->{'pif'};
    silent_ASSERT($pif, qq{PIFiller not set by subclass});

    return $pif;
}

# ---------------------------------------------------------------------

=item set_PI_filler

Set the PI_filler of a subclass of this Action handler

=cut

# ---------------------------------------------------------------------
sub set_PI_filler
{
    my $self = shift;
    my $pif = shift;
    $self->{'pif'} = $pif;
}




# ---------------------------------------------------------------------

=item get_operations

Return the operations set by a subclass of this Action handler

=cut

# ---------------------------------------------------------------------
sub get_operations
{
    my $self = shift;

    my $ops_arr_ref = $self->{'operations'};
    ASSERT($ops_arr_ref, qq{Operations not set by subclass});

    return $ops_arr_ref;
}

# ---------------------------------------------------------------------

=item set_operations

Set the operations of a subclass of this Action handler

=cut

# ---------------------------------------------------------------------
sub set_operations
{
    my $self = shift;
    my $op_arr_ref = shift;
    $self->{'operations'} = $op_arr_ref;
}


# ---------------------------------------------------------------------

=item set_persistent_facade_member_data

Allows Operations and PIFillers contained in this Action to share data
across redirects

=cut

# ---------------------------------------------------------------------
sub set_persistent_facade_member_data
{
    my $self = shift;
    my ($C, $key, $val) = @_;

    $self->{'facade'}{'persistent'}{$key} = $val;
}

# ---------------------------------------------------------------------

=item set_transient_facade_member_data

Allows Operations and PIFillers contained in this Action to share data
over one pass of the script

=cut

# ---------------------------------------------------------------------
sub set_transient_facade_member_data
{
    my $self = shift;
    my ($C, $key, $val) = @_;

    $self->{'facade'}{'transient'}{$key} = $val;
}

# ---------------------------------------------------------------------

=item get_persistent_facade_member_data

Allows Operations and PIFillers contained in this Action to share data
across redirects

=cut

# ---------------------------------------------------------------------
sub get_persistent_facade_member_data
{
    my $self = shift;
    my ($C, $key) = @_;

    return $self->{'facade'}{'persistent'}{$key};
}


# ---------------------------------------------------------------------

=item get_transient_facade_member_data

Allows Operations and PIFillers contained in this Action to share data
within one pass of the script

=cut

# ---------------------------------------------------------------------
sub get_transient_facade_member_data
{
    my $self = shift;
    my ($C, $key) = @_;

    return $self->{'facade'}{'transient'}{$key};
}



# ---------------------------------------------------------------------

=item get_all_facade_member_data

Allows storage of this data en masse

=cut

# ---------------------------------------------------------------------
sub get_all_facade_member_data
{
    my $self = shift;
    my $C = shift;

    return $self->{'facade'}{'persistent'};
}

# ---------------------------------------------------------------------

=item set_all_facade_member_data

Allows retrieval of this data en masse

=cut

# ---------------------------------------------------------------------
sub set_all_facade_member_data
{
    my $self = shift;
    my ($C, $data_ref) = @_;

    $self->{'facade'}{'persistent'} = $data_ref;
}


# ---------------------------------------------------------------------

=item get_error_record

=cut

# ---------------------------------------------------------------------
sub get_error_record
{
    my $self = shift;
    my $C = shift;

    return $self->{'facade'}{'error_record'};
}

# ---------------------------------------------------------------------

=item set_error_record

=cut

# ---------------------------------------------------------------------
sub set_error_record
{
    my $self = shift;
    my ($C, $ref) = @_;

    $self->{'facade'}{'error_record'} = $ref;
}

# ---------------------------------------------------------------------

=item make_error_record

=cut

# ---------------------------------------------------------------------
sub make_error_record
{
    my $self = shift;
    my ($C, $msg) = @_;

    my $cgi = new CGI($C->get_object('CGI'));
    my $error_ref = {
                     'CGI' => $cgi,
                     'msg' => $msg,
                    };

    return $error_ref;
}



# ---------------------------------------------------------------------

=item get_name

Obvious

=cut

# ---------------------------------------------------------------------
sub get_name
{
    my $self = shift;
    return $self->{'name'};
}



# ---------------------------------------------------------------------

=item get_type

Obvious

=cut

# ---------------------------------------------------------------------
sub get_type
{
    my $self = shift;
    return $self->{'type'};
}




# ---------------------------------------------------------------------

=item set_name

Obvious

=cut

# ---------------------------------------------------------------------
sub set_name
{
    my $self = shift;
    my $name = shift;
    $self->{'name'} = $name;
}



# ---------------------------------------------------------------------

=item set_type

Obvious

=cut

# ---------------------------------------------------------------------
sub set_type
{
    my $self = shift;
    my $type = shift;
    $self->{'type'} = $type;
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

