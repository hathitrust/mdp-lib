package Database;


=head1 NAME

Database (db)

=head1 DESCRIPTION

This class encapsulates the database connection and access to the
database handle.

There are currently two database users with different permissions:
ht_web and ht_maintenance for web-based apps and crontab-based
scripts, respectively.

=head1 SYNOPSIS

my $db_user = 'ht_web'
my $db = new Database($db_user);
$C->set_object('Database', $db);

Interactively

my $db = new Database('jones', 'somepassword', 'adbname', 'adbserver');


=head1 METHODS

=over 8

=cut

use strict;
use DBI;

use Utils;
use Debug::DUtils;
use DbUtils;
use MdpConfig;

my $_prod_root = q{/htapps/babel/etc/};
my $_test_root = q{/htapps/test.babel/etc/};

my $Production_Config_Root = (-e $_prod_root) ? $_prod_root : $_test_root ;

my $Full_Access_Config_Root = q{/htapps/test.babel/etc/};
my $Sample_Access_Config_Root = q{/htapps/} . $ENV{HT_DEV} . q{.babel/etc/};

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}

# ---------------------------------------------------------------------

=item get_db_connect_params

The config file to use depends on whether the development user is
config'd for the sample environment or the full.

=cut

# ---------------------------------------------------------------------
sub ___conf_file {
    my ($root, $user) = @_;
    my $conf_file = $root . $user . q{.conf};
    return $conf_file;
}

sub __get_db_connect_params {
    my $_db_user = shift;

    my $conf_file;
    if ($ENV{HT_DEV}) {
        if (defined $ENV{SDRVIEW} && $ENV{SDRVIEW} eq 'sample') {
            $conf_file = ___conf_file($Sample_Access_Config_Root, $_db_user);
        }
        else {
            $conf_file = ___conf_file($Full_Access_Config_Root, $_db_user);
        }
    }
    else {
        $conf_file = ___conf_file($Production_Config_Root, $_db_user);
    }
    ASSERT(-e $conf_file, qq{Config file=$conf_file missing for db_user=$_db_user});

    my $db_config = new MdpConfig($conf_file);

    my $db_name   = $db_config->get('db_name');
    my $db_user   = $db_config->get('db_user');
    my $db_passwd = $db_config->get('db_passwd');
    my $db_server = $db_config->get('db_server');

    return ($db_user, $db_passwd, $db_name, $db_server);
}

# ---------------------------------------------------------------------

=item _initialize

Initialize Database

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my ($_db_user, $_db_passwd, $_db_name, $_db_server) = @_;

    my ($db_user, $db_passwd,  $db_name, $db_server);

    # If all args supplied (interactively) just connect
    if ($_db_user && $_db_passwd && $_db_name && $_db_server) {
        ($db_user, $db_passwd, $db_name, $db_server) = ($_db_user, $_db_passwd, $_db_name, $_db_server);
    }
    else {
        ($db_user, $db_passwd, $db_name, $db_server) = __get_db_connect_params($_db_user);
    }

    my $dsn = qq{DBI:mysql:$db_name:$db_server};

    my $dbh;
    my $connect_attempts = 3;
    while ($connect_attempts) {
        $connect_attempts--;

        eval {
            $dbh = DBI->connect(
                                $dsn,
                                $db_user,
                                $db_passwd,
                              {
                               # Do our own checks, below
                               RaiseError => 0,
                               PrintError => 0,
                              }
                               );
        };
        last if ($dbh);
        sleep 5;
    }
    silent_ASSERT($dbh, qq{database connect failed: } . (DBI->errstr || ''));

    my $charset_cmd = qq{SET NAMES 'UTF8'};
    silent_ASSERT($dbh->do($charset_cmd), qq{database charset failed: } . (DBI->errstr || ''));

    # mysql_auto_reconnect in conjunction with a ping() will reconnect
    # if a client is affected by the mysql server timeout but only if
    # AutoCommit is on
    $dbh->{AutoCommit} = 1;
    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->{mysql_enable_utf8} = 1;

    $self->{'dbh'} = $dbh;
}

# ---------------------------------------------------------------------

=item get_DBH

Database handle accessor

=cut

# ---------------------------------------------------------------------
sub get_DBH {
    my $self = shift;
    my $C = shift;
    return $self->{'dbh'};
}

# ---------------------------------------------------------------------

=item dispose

Clean up the database connection

=cut

# ---------------------------------------------------------------------
sub dispose {
    my $self = shift;
    my $dbh = $self->get_DBH();
    if ($dbh->{Active}) {
        $dbh->disconnect();
    }
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008 ©, The Regents of The University of Michigan, All Rights Reserved

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
