#############################################################################
#
# Apache::Session::MySQL::InnoDB
# Apache persistent user sessions in a Postgres database
# Copyright(c) 1998, 1999, 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::MySQL::InnoDB;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.01';
@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::Lock::Null;
use Apache::Session::Store::MySQL::InnoDB;
use Apache::Session::Generate::MD5;
use Apache::Session::Serialize::Storable;

sub populate {
    my $self = shift;

    $self->{object_store} = new Apache::Session::Store::MySQL::InnoDB $self;
    $self->{lock_manager} = new Apache::Session::Lock::Null $self;
    $self->{generate}     = \&Apache::Session::Generate::MD5::generate;
    $self->{validate}     = \&Apache::Session::Generate::MD5::validate;
    $self->{serialize}    = \&Apache::Session::Serialize::Storable::serialize;
    $self->{unserialize}  = \&Apache::Session::Serialize::Storable::unserialize;

    return $self;
}

sub save {
    my $self = shift;
    # don't bother updating the database at all
    return unless ( $self->{args}->{Commit} );
    $self->SUPER::save();
}

1;


=pod

=head1 NAME

Apache::Session::MySQL::InnoDB - An implementation of Apache::Session

=head1 SYNOPSIS

 use Apache::Session::MySQL::InnoDB;

 #if you want Apache::Session to open new DB handles:

 tie %hash, 'Apache::Session::MySQL::InnoDB', $id, {
    DataSource => 'dbi:mysql:database=sessions',
    UserName   => $db_user,
    Password   => $db_pass,
    Commit     => 1
 };

 #or, if your handles are already opened:

 tie %hash, 'Apache::Session::MySQL::InnoDB', $id, {
    Handle => $dbh,
    Commit => 1
 };

=head1 DESCRIPTION

This module is an implementation of Apache::Session.  It uses the Postgres
backing store and no locking.  See the example, and the documentation for
Apache::Session::Store::MySQL::InnoDB for more details.

=head1 USAGE

The special Apache::Session argument for this module is Commit.  You MUST
provide the Commit argument, which instructs this module to either commit
the transaction when it is finished, or to simply do nothing.  This feature
is provided so that this module will not have adverse interactions with your
local transaction policy, nor your local database handle caching policy.  The
argument is mandatory in order to make you think about this problem.

=head1 AUTHOR

This module was written by Jeffrey William Baker <jwbaker@acm.org>.

=head1 SEE ALSO

L<Apache::Session::File>, L<Apache::Session::Flex>,
L<Apache::Session::DB_File>, L<Apache::Session::MySQL::InnoDB>, L<Apache::Session>
