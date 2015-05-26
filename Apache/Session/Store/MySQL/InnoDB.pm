#############################################################################
#
# Apache::Session::Store::MySQL::InnoDB
# Implements session object storage via MySQL InnoDB
# Copyright(c) 1998, 1999, 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::Store::MySQL::InnoDB;

use strict;

use DBI;
use Apache::Session::Store::DBI;

use Time::HiRes qw(time);

use vars qw(@ISA $VERSION);

@ISA = qw(Apache::Session::Store::DBI);
$VERSION = '1.03';

$Apache::Session::Store::MySQL::InnoDB::DataSource = undef;
$Apache::Session::Store::MySQL::InnoDB::UserName   = undef;
$Apache::Session::Store::MySQL::InnoDB::Password   = undef;

sub connection {
    my $self    = shift;
    my $session = shift;
    
    return if (defined $self->{dbh});

	$self->{'table_name'} = $session->{args}->{TableName} || $Apache::Session::Store::DBI::TableName;

    if (exists $session->{args}->{Handle}) {
        $self->{dbh} = $session->{args}->{Handle};
        $self->{commit} = $session->{args}->{Commit};
        
        # if ( $self->{dbh}->{AutoCommit} == 1 && $self->{commit} ) {
        #     $self->{dbh}->begin_work;
        #     # $self->{dbh}->{AutoCommit} = 0;
        # }

        return;
    }

    my $datasource = $session->{args}->{DataSource} || 
        $Apache::Session::Store::MySQL::InnoDB::DataSource;
    my $username = $session->{args}->{UserName} ||
        $Apache::Session::Store::MySQL::InnoDB::UserName;
    my $password = $session->{args}->{Password} ||
        $Apache::Session::Store::MySQL::InnoDB::Password;
        
    $self->{dbh} = DBI->connect(
        $datasource,
        $username,
        $password,
        { RaiseError => 1, AutoCommit => 0 }
    ) || die $DBI::errstr;

    
    #If we open the connection, we close the connection
    $self->{disconnect} = 1;
    
    #the programmer has to tell us what commit policy to use
    $self->{commit} = $session->{args}->{Commit};
}

sub materialize {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    # if (!defined $self->{materialize_sth}) {
    #     $self->{materialize_sth} = 
    #         $self->{dbh}->prepare_cached(qq{
    #             SELECT a_session FROM $self->{'table_name'} WHERE id = ? FOR UPDATE});
    # }

    if (!defined $self->{materialize_sth}) {
        $self->{materialize_sth} = 
            $self->{dbh}->prepare_cached(qq{
                SELECT a_session FROM $self->{'table_name'} WHERE id = ?});
    }
    
    $self->{materialize_sth}->bind_param(1, $session->{data}->{_session_id});
    
    $self->{materialize_sth}->execute;
    
    my $results = $self->{materialize_sth}->fetchrow_arrayref;

    if (!(defined $results)) {
        $self->{dbh}->rollback if ( $session->{commit} );
        $self->{commit} = 0;
        die "Object does not exist in the data store";
    }

    $self->{materialize_sth}->finish;

    $session->{serialized} = $results->[0];
}

sub insert {
    my $self    = shift;
    my $session = shift;
    
    $self->connection($session);
    eval {
        $self->_begin_work;
        $self->SUPER::insert($session);
        $self->_commit;
    };
    if ( my $err = $@ ) {
        print STDERR "SESSION INSERT ERROR : $err : " . $self->{dbh}->errstr . "\n";
        $self->_rollback;
    }
}

sub update {
    my $self    = shift;
    my $session = shift;

    my $t0 = time();
    
    $self->connection($session);
    eval {
        # my @tmp = ();
        # my ($package, $filename, $line, $subroutine) = caller(1);
        # push @tmp, $subroutine;
        # ($package, $filename, $line, $subroutine) = caller(2);
        # push @tmp, $subroutine;
        # ($package, $filename, $line, $subroutine) = caller(3);
        # push @tmp, $subroutine;
        # ($package, $filename, $line, $subroutine) = caller(4);
        # push @tmp, $subroutine;
        # print STDERR "SESSION UPDATE : $$session{data}{_session_id} : $ENV{REQUEST_URI} : @tmp\n";
        $self->_begin_work;
        $self->SUPER::update($session);
        $self->_commit;
    };
    if ( my $err = $@ ) {
        print STDERR "SESSION UPDATE ERROR : $err : " . $self->{dbh}->errstr . "\n";
        $self->_rollback;
    }

}

sub remove {
    my $self    = shift;
    my $session = shift;
    
    $self->connection($session);
    eval {
        $self->_begin_work;
        $self->SUPER::remove($session);
        $self->_commit;
    };
    if ( my $err = $@ ) {
        print STDERR "SESSION REMOVE ERROR : $err : " . $self->{dbh}->errstr . "\n";
        $self->_rollback;
    }
}

sub _begin_work {
    my $self = shift;
    if ( $self->{dbh}->{AutoCommit} == 1 && $self->{commit} ) {
        # $self->{dbh}->begin_work;
        $self->{dbh}->{AutoCommit} = 0;
        $self->{__in_transaction} = 1;
    } elsif ( $self->{dbh}->{AutoCommit} == 0 ) {
        # NOT autocommitting
        $self->{__in_transaction} = 1;
    }
}

sub _commit {
    my $self = shift;
    $self->{dbh}->commit if ( $self->{__in_transaction} );
}

sub _rollback {
    my $self = shift;
    $self->{dbh}->rollback;
}

sub DESTROY {
    my $self = shift;

    # if ($self->{commit} ) {
    #     print STDERR "STILL COMMITING : " . $self->{dbh}->{AutoCommit} . "\n";
    #     $self->{dbh}->commit;
    # }
    
    if ($self->{disconnect}) {
        $self->{dbh}->disconnect;
    }
}

1;

=pod

=head1 NAME

Apache::Session::Store::MySQL::InnoDB - Store persistent data in a MySQL InnoDB database

=head1 SYNOPSIS

 use Apache::Session::Store::MySQL::InnoDB;

 my $store = new Apache::Session::Store::MySQL::InnoDB;

 $store->insert($ref);
 $store->update($ref);
 $store->materialize($ref);
 $store->remove($ref);

=head1 DESCRIPTION

Apache::Session::Store::MySQL::InnoDB fulfills the storage interface of
Apache::Session. Session data is stored in a Postgres database.

=head1 SCHEMA

To use this module, you will need at least these columns in a table 
called 'sessions', or another name if you supply the TableName parameter.

 id char(32)     # or however long your session IDs are.
 a_session text  # This has an ~8 KB limit :(

To create this schema, you can execute this command using the psql program:

 CREATE TABLE sessions (
    id char(32) not null primary key,
    a_session text
 );

If you use some other command, ensure that there is a unique index on the
table's id column.

=head1 CONFIGURATION

The module must know what datasource, username, and password to use when
connecting to the database.  These values can be set using the options hash
(see Apache::Session documentation).  The options are:

=over 4

=item DataSource

=item UserName

=item Password

=item Handle

=item TableName

=back

Example:

 tie %hash, 'Apache::Session::MySQL::InnoDB', $id, {
     DataSource => 'dbi:Pg:dbname=database',
     UserName   => 'database_user',
     Password   => 'K00l'
 };

Instead, you may pass in an already-opened DBI handle to your database.

 tie %hash, 'Apache::Session::MySQL::InnoDB', $id, {
     Handle => $dbh
 };

=head1 AUTHOR

This module was based on the Apache::Session Postgres support.

This modules was written by Jeffrey William Baker <jwbaker@acm.org>

A fix for the commit policy was contributed by Michael Schout <mschout@gkg.net>

=head1 SEE ALSO

L<Apache::Session>, L<Apache::Session::Store::DBI>
