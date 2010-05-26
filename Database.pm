package Database;


=head1 NAME

Database (db)

=head1 DESCRIPTION

This class encapsulates the database connection and access to the
database handle.

=head1 SYNOPSIS

my $config = new MdpConfig('some.conf');

my $db = new Database($config);

$C->set_object('Database', $db);


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

use DBI;

use Utils;
use Debug::DUtils;
use DbUtils;

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

Initialize Database

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self = shift;
    my $config = shift;

    my $db_name = $config->get('db_name');
    my $db_user = $config->get('db_user');
    my $db_passwd = $config->get('db_passwd');

    my $db_server = $config->get('db_server');
    my $dsn = qq{DBI:mysql:$db_name:$db_server};

    $self->{'dsn'} = $dsn;
    $self->{'db_user'} = $db_user;
    
    my $dbh;
    my $connect_attempts = 3;
    while ($connect_attempts) {
        $connect_attempts--;
        
        $dbh = DBI->connect(
                            $dsn, 
                            $db_user, 
                            $db_passwd, 
                            {
                             RaiseError => 1, 
                            }
                           );
        last if ($dbh);
        sleep 5;
    }
    silent_ASSERT($dbh, qq{database connect failed: } . DBI->errstr);

    my $charset_cmd = qq{SET NAMES 'UTF8'};
    silent_ASSERT($dbh->do($charset_cmd), qq{database charset failed: } . DBI->errstr);

    # mysql_auto_reconnect in conjunction with a ping() will reconnect
    # if a client is affected by the mysql server timeout but only if
    # AutoCommit is on
    $dbh->{AutoCommit} = 1;
    $dbh->{mysql_auto_reconnect} = 1;
    $dbh->{mysql_enable_utf8} = 1;

    $self->{'dbh'} = $dbh;

    $self->test_schema_version($config);
}

# ---------------------------------------------------------------------

=item test_schema_version

Description: virtual, subclass optional

=cut

# ---------------------------------------------------------------------
sub test_schema_version
{
}

# ---------------------------------------------------------------------

=item get_DBH

Database handle accessor

=cut

# ---------------------------------------------------------------------
sub get_DBH
{
    my $self = shift;
    my $C = shift;
    
    return $self->{'dbh'};
}

# ---------------------------------------------------------------------

=item get_dsn

Database data source name (dsn) accessor

=cut

# ---------------------------------------------------------------------
sub get_dsn
{
    my $self = shift;
    my $C = shift;
    
    return $self->{'dsn'};
}

# ---------------------------------------------------------------------

=item get_db_user

Database user name accessor

=cut

# ---------------------------------------------------------------------
sub get_db_user
{
    my $self = shift;
    my $C = shift;
    
    return $self->{'db_user'};
}


# ---------------------------------------------------------------------

=item dispose

Clean up the database connection

=cut

# ---------------------------------------------------------------------
sub dispose
{
    my $self = shift;
    my $dbh = $self->get_DBH();
    if ($dbh->{Active})
    {
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
