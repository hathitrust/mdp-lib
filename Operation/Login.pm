package Operation::Login;


=head1 NAME

Operation::Login (op)

=head1 DESCRIPTION

This class is the Login implementation of the abstract Operation
class.  It is an "early operation" always executed to make temporary
collections owned anonymously by the session to become owned by a
logged in user.

=head1 SYNOPSIS

See coding example in base class Operation

=head1 METHODS

=over 8

=cut

use strict;

use base qw(Operation);

use Auth::Auth;
use Utils;
use Debug::DUtils;

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

Initialize MBooks::Operation::Login.  Must call parent initialize.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my $attr_ref = shift;

    my $C = $$attr_ref{'C'};
    my $act = $$attr_ref{'act'};

    $self->SUPER::_initialize($C, $act);
}



# ---------------------------------------------------------------------

=item execute_operation

Perform the database operations necessary for the Login Operation

=cut

# ---------------------------------------------------------------------
sub execute_operation
{
    my $self = shift;
    my $C = shift;

    DEBUG('op', qq{execute operation="Login"});

    # Parameter validation et. al.
    $self->SUPER::execute_operation($C);

    my $auth = $C->get_object('Auth');
    if ($auth->isa_new_login())
    {
        my $act = $self->get_action();
        my $CS = $act->get_transient_facade_member_data($C, 'collection_set_object');
        my $co = $act->get_transient_facade_member_data($C, 'collection_object');

        my $session_user_id = $C->get_object('Session')->get_session_id();
        my $user_id = $auth->get_user_name($C);

        ASSERT(($user_id ne $session_user_id),
               qq{New login user_id="$user_id" and session user id="$session_user_id"});

        # Get list of collections owned by session-id user and change
        # status to private after changing owner to logged-in user to
        # allow the edit_status operation to proceed.
        my @session_based_collids;
        my $coll_data_arrayref = $CS->get_coll_data_from_user_id($session_user_id);
        foreach my $coll_hashref (@$coll_data_arrayref)
        {
            push(@session_based_collids, $$coll_hashref{'MColl_ID'});
        }

        my $user_display_name = $auth->get_user_display_name($C);
        $CS->change_owner($session_user_id, $user_id, $user_display_name);

        foreach my $collid (@session_based_collids)
        {
            $co->edit_status($collid, 'private');    
        }
    }

    return $ST_OK;
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

