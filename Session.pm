package Session;


=head1 NAME

Session (ses)

=head1 DESCRIPTION

This is a Wrapper class for Apache::Session. Manages the session id
via cookies.

=head1 VERSION

$Id: Session.pm,v 1.15 2010/04/28 18:11:33 pfarber Exp $

=head1 SYNOPSIS

my $ses = Session::start_session($C);

my $sid = $ses->get_session_id();

$ses->set_persistent($key, $value);

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

use CGI;
use CGI::Cookie;

use Apache::Session::MySQL::InnoDB;
my $g_session_store = 'Apache::Session::MySQL::InnoDB';

use Debug::DUtils;
use Utils;
use Database;


# ---------------------------------------------------------------------

=item start_session

Class method which acts like a mini-factory to create a Session object.

Cookie Logic: Update cookie obj on session object with a possibly
different session id returned from the "new Session" call. Get session
id from cookie or create new cookie and store it on the session.

If you want to run using a new session instead of the session whose id
is stored in your cookie set newsid=1 on the URL,

No expiration time is set on the cookie making it a session cookie
which expires when the browser is closed.  Hence the session cleaner
run interval the life of the session since the browser could remain
open and inactive for longer than the database session.

bin/managesessions.pl runs once every hour and deletes sessions that have
been inactive for 2 hours or more so an inactive session will expire
in a maximum of 2:59:59.

=cut

# ---------------------------------------------------------------------
sub start_session
{
    my $C = shift;
    my $commit = shift;

    my $cgi = $C->get_object('CGI');
    my $cookie_name = $C->get_object('MdpConfig')->get('cookie_name');

    my ($sid, $previous_sid);

    if ($previous_sid = $sid = $cgi->param('newsid'))
    {
        $previous_sid = $sid = undef
            if ($sid eq "1");

        # Otherwise use the value of 'newsid' from the URL and recover
        # that session if it is still available in the database
    }
    else
    {
        my %cookies = fetch CGI::Cookie;
        if (defined($cookies{$cookie_name}))
        {
            $previous_sid = $sid = $cookies{$cookie_name}->value;
        }
    }
    
    my $ses;
    eval
    {
	$ses = new Session($C, $sid, 0, $commit);
    };
    ASSERT(!$@, qq{Error creating session: $@});

    $sid = $ses->get_session_id();

    # No expiration time set on the cookie makes it a browser session
    # cookie that expires when the browser is closed.  Therefore the
    # session lifetime is the min of browser session lifetime and
    # database record lifetime.  managemdpsessions.pl runs once every
    # hour and deletes sessions that have been inactive for 2 hours or
    # more so an inactive session will expire in a maximum of 2:59:59.
    my $session_cookie =
        new CGI::Cookie(
                        -name    => $cookie_name,
                        -value   => $sid,
                        -path    => '/',
                        -domain  => Utils::get_cookie_domain($cgi),
                        -httponly => 1,
                      );

    $ses->set_cookie($session_cookie);

    #
    # Establish the debugging environment.  This updates the global
    # session variable in Utils::DUtils to retrieve the save debug
    # messages. No trans-session debugging calls will work before this
    # call.
    Debug::DUtils::setup_debug_environment($ses);
    #
    # Call debugging_enabled() to emit auth debug text after
    # environment is set up
    Debug::DUtils::debugging_enabled();

    DEBUG('session,all',
          sub
          {
              my $t = ($previous_sid eq $sid) ? q{EXISTING session } : q{NEW session };
              return $t . qq{sid=$sid};
          });
              
    $C->get_object('MdpConfig')->__config_debug();
    
    return $ses;
}


# ---------------------------------------------------------------------

=item new

Create new Session object. If $empty is true, return only an empty,
but blessed Session object for use in managemdpsessions.pl

=cut

# ---------------------------------------------------------------------
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

If there was no incoming session id, pass Apache::Session "undef" as
session id; it will create a new id

Sometimes a 'valid' sid (after a crash or in the debugger) corresponds
to a zero-length session file (never populated due to the crash or
interruption?).  In these cases the sid is worthless so we need to
generate a new one.

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my ($self, $C, $sid, $empty, $commit) = @_;

    if ($empty)
    {
        $self->{'persistent_data'} = {};
        $self->{'transient_data'} = {};
        $self->{'empty'} = 1;
    }
    else
    {
        my %session_hash = ();

        if (! $sid ||
             $sid !~ m,[0-9a-zA-Z]{16},)
        {
            _make_persistent($C, undef, \%session_hash, $commit);
        }
        else
        {
            # putatively valid sid provided
            _make_persistent($C, $sid, \%session_hash, $commit);
        }

        if (! $session_hash{_session_id})
        {
            _make_persistent($C, undef, \%session_hash, $commit);
        }

        # Set the session id for future use
        $sid = $session_hash{_session_id};

        # save the Apache::Session::DBI id and tied hash in this
        # Session wrapper object
        $self->{'id'} = $sid;
        $self->{'persistent_data'} = \%session_hash;
    }
}


# ---------------------------------------------------------------------

=item _make_persistent

Serialize and store the session hash in the database.

=cut

# ---------------------------------------------------------------------
sub _make_persistent
{
    my ($C, $sid, $session_hash_ref, $commit) = @_;

    unless ( defined $commit ) { $commit = 1; }

    my $config = $C->get_object('MdpConfig');
    my $db = $C->get_object('Database');

    my $dbh = $db->get_DBH($C);
    ASSERT($dbh->{Active}, qq{database handle not valid for session creation});

    my $session_store_attrsref;
    if ( $g_session_store eq 'Apache::Session::MySQL' ) {
        $session_store_attrsref = {
                                     Handle     => $dbh,
                                     LockHandle => $dbh,
                                  };
    } else {
        $Apache::Session::Store::DBI::TableName = 'ht_sessions';
        $session_store_attrsref = {
                                     Handle     => $dbh,
                                     Commit     => $commit       # for InnoDB transactions
                                  };
    }



    eval
    {
        tie %$session_hash_ref, $g_session_store, $sid, $session_store_attrsref;
    };
    if ($@)
    {
        # sid provided is not in the session database. re-submit
        # with undef to get a new session
        if ($@ =~ m,Object does not exist in the data store,)
        {
            tie %$session_hash_ref, $g_session_store, undef, $session_store_attrsref;
        }
    }
    elsif (! $$session_hash_ref{'_session_id'})
    {
        die(qq{session hash returned empty from tie. BLOB size problem?});
    }
}




# ---------------------------------------------------------------------

=item get_session_id

Return the session's id.

=cut

# ---------------------------------------------------------------------
sub get_session_id
{
    my $self = shift;
    return $self->{'id'};
}



# ---------------------------------------------------------------------

=item get_cookie

Return the session cookie.

=cut

# ---------------------------------------------------------------------
sub get_cookie
{
    my $self = shift;
    return $self->{'cookie'};
}




# ---------------------------------------------------------------------

=item set_cookie

Set the session cookie

=cut

# ---------------------------------------------------------------------
sub set_cookie
{
    my $self = shift;
    my $cookie = shift;
    $self->{'cookie'} = $cookie;
}


# ---------------------------------------------------------------------

=item close

Update time stamp on this Session and close it. Calling untie on
Apache::Session hash causes it to be serialized to the database

=cut

# ---------------------------------------------------------------------
sub close
{
    my $self = shift;

    my $session_ref = $self->{'persistent_data'};
    $session_ref->{'timestamp'} = time;

    if (! $self->{'empty'})
    {
        untie (%{$session_ref})
    }
}


# ---------------------------------------------------------------------

=item set_persistent_session_hash

Overwrites the entire persistent_data hash in this object. Used by
managemdpsessions.pl to assign a "thawed" hash ref to the member data of
an empty, blessed Session object.

=cut

# ---------------------------------------------------------------------
sub set_persistent_session_hash
{
    my $self = shift;
    my $hash_ref = shift;
    $self->{'persistent_data'} = $hash_ref;
}


# ---------------------------------------------------------------------

=item set_persistent

Store hash key and value persistently.

=cut

# ---------------------------------------------------------------------
sub set_persistent
{
    my $self = shift;
    my ($key, $item) = @_;
    my $session_ref = $self->{'persistent_data'};
    ${$session_ref}{$key} = $item;
}

# ---------------------------------------------------------------------

=item set_persistent_subkey

Store hash key, subkey and value persistently.

=cut

# ---------------------------------------------------------------------
sub set_persistent_subkey
{
    my $self = shift;
    my ($key, $subkey, $item) = @_;
    my $session_ref = $self->{'persistent_data'};
    ${$session_ref}{$key}{$subkey} = $item;
}

# ---------------------------------------------------------------------

=item get_persistent

Get persistent value by key.

=cut

# ---------------------------------------------------------------------
sub get_persistent
{
    my $self = shift;
    my $key  = shift;
    my $session_ref = $self->{'persistent_data'};
    return ${$session_ref}{$key};
}

# ---------------------------------------------------------------------

=item get_persistent_subkey

Get persistent value by key, subkey.

=cut

# ---------------------------------------------------------------------
sub get_persistent_subkey
{
    my $self = shift;
    my ($key, $subkey) = @_;
    my $session_ref = $self->{'persistent_data'};
    return ${$session_ref}{$key}{$subkey};
}



# ---------------------------------------------------------------------

=item set_transient

Store hash key and value transiently.

=cut

# ---------------------------------------------------------------------
sub set_transient
{
    my $self = shift;
    my ($key, $item) = @_;
    $self->{'transient_data'} = {} unless ( ref($self->{'transient_data'}) );
    my $session_ref = $self->{'transient_data'};
    ${$session_ref}{$key} = $item;
}

# ---------------------------------------------------------------------

=item set_transient_subkey

Store hash key, subkey and value persistently.

=cut

# ---------------------------------------------------------------------
sub set_transient_subkey
{
    my $self = shift;
    my ($key, $subkey, $item) = @_;
    $self->{'transient_data'} = {} unless ( ref($self->{'transient_data'}) );
    my $session_ref = $self->{'transient_data'};
    ${$session_ref}{$key}{$subkey} = $item;
}


# ---------------------------------------------------------------------

=item get_transient

Get transient value by key.

=cut

# ---------------------------------------------------------------------
sub get_transient
{
    my $self = shift;
    my $key  = shift;
    my $session_ref = $self->{'transient_data'};
    return ${$session_ref}{$key};
}

# ---------------------------------------------------------------------

=item get_transient_subkey

Get transient value by key, subkey.

=cut

# ---------------------------------------------------------------------
sub get_transient_subkey
{
    my $self = shift;
    my ($key, $subkey) = @_;
    my $session_ref = $self->{'transient_data'};
    return ${$session_ref}{$key}{$subkey};
}


# ---------------------------------------------------------------------

=item session_dumper

What is says

=cut

# ---------------------------------------------------------------------
sub session_dumper
{
    my $self = shift;

    require Data::Dumper;
    $Data::Dumper::Indent = 2;
    my $dump = Data::Dumper->Dump( [$self], [qw($self)] );

    # protect entities and turn naked & into &amp;
    $dump =~ s/&([^;]+);/ENTITY:$1:ENTITY/gis;
    $dump =~ s/&/&amp;/gis;
    $dump =~ s/ENTITY:([a-z0-9]+):ENTITY/&$1;/gis;

    return qq{<pre style="text-align: left">$dump</pre>};
}



# ---------------------------------------------------------------------

=item dispose

Session cleanup causing serialization via Session::close

=cut

# ---------------------------------------------------------------------
sub dispose
{
    my $self = shift;
    $self->close();
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
