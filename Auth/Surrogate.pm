package Auth::Surrogate;

=head1 Auth::Surrogate

Auth::Surrogate

=head1 DESCRIPTION

This class replaces the auth system to allow overrides of the SDRINST
and SDRLIB environment variables in development.  If the SDR file is
present in /<<appname>>/cgi/... it will override.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use CGI;

# ---------------------------------------------------------------------

=item read_sdr_auth_file

Description

=cut

# ---------------------------------------------------------------------
sub read_sdr_auth_file
{
    my $auth_file = shift;

    return 0
        if (! open(AUTH_FILE, "<$auth_file"));

    my $line;
    $line = <AUTH_FILE>;
    return 0 if (! $line);
    chomp($line);
    $ENV{'SDRINST'} = $line;

    $line = <AUTH_FILE>;
    return 0 if (! $line);
    chomp($line);
    $ENV{'SDRLIB'} = $line;

    close (AUTH_FILE);

    return $auth_file;
}


# ---------------------------------------------------------------------

=item authorize

If running in debugger i.e. outside of web auth environment, set
environment by hardcoding but never in a production environment,
otherwise, let auth system do the work.

=cut

# ---------------------------------------------------------------------
sub authorize {
    my $classpath = shift;

    # Make the perl compiler happy about an uninitialized value.
    $ENV{'DEBUG'} = '' if (! exists $ENV{'DEBUG'});

    #
    # If debugging from the command line / perl debugger in a
    # development environment and it's not the release environment,
    # set SDRINST, SDRLIB environment variables. These varaibles can
    # be set using debug=hathi|nonhathi (which see) under a web
    # browser.
    #
    if (
        ($ENV{'HT_DEV'} =~ m,[a-z]+,)
        &&
        (! defined($ENV{'HTTP_HOST'}))
        &&
        $ENV{'TERM'}
       ) {
        my $authfile_read = 0;
        my $auth_file = $ENV{'SDRROOT'} . $classpath . '/SDR';
        my $fail_msg =
            qq{[FATAL] Could not open $auth_file. }
                . qq{Create this file to set SDRINST, SDRLIB for your development environment};
        my $inst = $ENV{'SDRINST'} || '';
        my $lib = $ENV{'SDRLIB'} || '';
        my $succ_msg =
            qq{[INFO] SDRINST=$inst, SDRLIB=$lib } .
                qq{environment variables were set from values in file="$auth_file"};

        # Must read file to supply these values at command line or debugger
        $authfile_read = read_sdr_auth_file($auth_file);
        if ($authfile_read) {
            $main::g_auth_debug_message .= $succ_msg;
        }
        else {
            die $fail_msg;
        }
    }

    return 1;
}

1;


