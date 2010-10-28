package Search::XPat::Simple;

=head1 NAME

Search::XPat::Simple (xpat)

=head1 DESCRIPTION

This class is a simplified version of DLXS XPat.pm

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;
use IPC::Open3;
use Symbol;


use Utils;
use Debug::DUtils;
use Search::XPat::Result;
use Search::XPat::ResultSet;


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

Description

=cut

# ---------------------------------------------------------------------
sub _initialize
{
    my $self        = shift;
    my $dd          = shift;
    my $pset_offset = shift;
    
    $self->{'dd'}          = $dd;
    $self->{'pset_offset'}  = $pset_offset;
    $self->{'separator'}   = '</Sync>';
    
    DEBUG('xpat,all', qq{<h2>XPAT dd: $dd</h2>\n});
    
    # Start XPat
    my ($wtr, $rdr, $err);
    eval
    {
        # use IPC::Open3 to fork and set up pipes
        $wtr = $self->{'wtr'} = gensym();
        $rdr = $self->{'rdr'} = gensym();
        $err = $self->{'err'} = gensym();
        
        # set up autoflush on writer pipe
        select $wtr;
        $| = 1;
        select STDOUT;
        $| = 1;
        
        my @startup_command =
            ($PTGlobals::gXPATU, "-D", "$dd", "-q", "-s", "EndOfResults");
        my $startup_command = join(' ', @startup_command);
        
        DEBUG('xpat,all', qq{startup command: $startup_command\n});
        
        # use IPC::Open3 to fork off XPat process
        my $pid = open3($wtr, $rdr, $err, @startup_command);
    };
    if ($@)
    {
        my $error_msg =
            qq{Could not fork XPat process or start remote process or child had exec error. $@};
        die $error_msg;
    }
    
    ## ---------------------------------------------------------------
    ## check if XPAT process was ok with the parameters it was passed
    ## ---------------------------------------------------------------
    local $/ = $self->{'separator'};
    
    my $xpat_result = <$rdr>;
    
    my $error;
    if ($xpat_result =~ m,<Sync>EndOfResults</Sync>,s)
    {
        # We got the expected Sync response -- see if accompanied by
        # error message
        ($error) = ($xpat_result =~ m,<Error>(.*?)</Error>,s);
        $error = qq{Sync tag sent but: } . $error
            if ($error);
    }
    else
    {
        $error = qq{No Sync tag sent by XPAT.  Startup failed. Pipe read="$xpat_result"};
    }    

    # Handle the error fallout if any
    if ($error)
    {
        my $hostname = `hostname`;
        $error = $error
            . qq{<br/>[HTTP_HOST="$ENV{'HTTP_HOST'}" hostname="$hostname"] };
        die $error;
    }
    else
    {
        my $default_mode_cmd = $self->get_mode_cmd_string('default');
        # Return results in byte occurrence order and change left
        # context from XPat's default of 14 so that hit is closer to
        # center
        my $cmd = $default_mode_cmd  . '{LeftContext 0};';
        print $wtr $cmd;
    }
}


# ---------------------------------------------------------------------

=item get_mode_cmd_string

Description

=cut

# ---------------------------------------------------------------------
sub get_mode_cmd_string
{
    my $self = shift;
    return '{sortorder occur};{quieton raw};';
}


# ---------------------------------------------------------------------

=item get_results_from_query

Description

=cut

# ---------------------------------------------------------------------
sub get_results_from_query
{
    my $self  = shift;
    my ($label, $query) = @_;
    
    # prepare handles for reading and writing
    my $wtr = $self->{'wtr'};
    my $rdr = $self->{'rdr'};
    my $err = $self->{'err'};
    
    local $/ = $self->{'separator'};  # likely '</Sync>'
    
    # make sure there  is a semicolon at end of query
    $query .= ';' if ($query !~ m,;\s*$,);
    
    #
    #   T h e   Q u e r y
    #
    $query = $query . '~sync "EndOfResults";';
    $query = Encode::encode_utf8($query);
    print $wtr $query;
    $query = Encode::decode_utf8($query);
    
    DEBUG('results,all',
          sub
          {
              my $q = $query;
              Utils::map_chars_to_cers(\$q);
              return qq{<h5>get_results_from_query(} .
                  $self->get_data_dict_name() .
                      qq{)<br/>\nSENDING TO XPAT: $q</h5>\n};
          });
    
    # read in entire output from XPat
    my $xpat_result = <$rdr> || '';
    $xpat_result = Encode::decode_utf8($xpat_result);
    
    # XPat crash, no access, ...
    if (! $xpat_result)
    {
        my $hostname = `hostname`;
        my $error_msg =
            qq{XPat return string is undefined after attempting query: "$query" } .
                qq{The XPat process may have died or the connection to it may have been lost. } .
                    qq{Data Dictionary: } .
                        $self->get_data_dict_name() .
                            qq{HTTP_HOST="$ENV{'HTTP_HOST'}" hostname="$hostname"] } ;
        
        die $error_msg;
    }
    
    DEBUG('results',
          sub 
          {
              my $raw = $xpat_result;
              Utils::map_chars_to_cers(\$raw);
              return qq{<h5><font color="red">get_results_from_query<br />RAW XPAT RESULT: </font>\n $raw</h5>\n};
          });
    
    my $xro = new Search::XPat::Result(\$xpat_result, $label, $self);
    
    return $xro;
}

# ---------------------------------------------------------------------

=item get_simple_results_from_query

Description

=cut

# ---------------------------------------------------------------------
sub get_simple_results_from_query
{
    my $self = shift;
    my $query = shift;
    
    my $error = undef;
    
    # prepare handles for reading and writing
    my $wtr = $self->{'wtr'};
    my $rdr = $self->{'rdr'};
    my $err = $self->{'err'};
    
    local $/ = $self->{'separator'};  # likely '</Sync>'
    
    # make sure there  is a semicolon at end of query
    $query .= ';' if ($query !~ m,;\s*$,);
    
    #
    #   T h e   Q u e r y
    #
    $query = $query . '~sync "EndOfResults";';
    $query = Encode::encode_utf8($query);
    print $wtr $query;
    $query = Encode::decode_utf8($query);
    
    DEBUG('results,all',
          sub
          {
              my $q = $query;
              Utils::map_chars_to_cers(\$q);
              return qq{<h5>getsimple__results_from_query(} .
                  $self->get_data_dict_name() .
                      qq{)<br/>\nSENDING TO XPAT: $q</h5>\n};
          });
    
    # Read XPAT output
    my $xpat_result = <$rdr> || '';
    $xpat_result = Encode::decode_utf8($xpat_result);
    
    # XPat crash?
    if (! $xpat_result)
    {
        my $hostname = `hostname`;
        my $error_msg =
            qq{XPat return string is undefined after attempting query: "$query" } .
                qq{The XPat process may have died or the connection to it may have been lost. } .
                    qq{Data Dictionary: } .
                        $self->get_data_dict_name() .
                            qq{ [HTTP_HOST="$ENV{'HTTP_HOST'}" hostname="$hostname"]};
        
        die $error_msg;
    }
    
    DEBUG('results',
          sub
          {
              my $raw = $xpat_result;
              Utils::map_chars_to_cers(\$raw);
              return qq{<h5><font color="red">get_simple_results_from_query<br/>RAW XPAT RESULT: </font>\n$raw</h5>\n};
          });
    
    if ($xpat_result =~ m,<Error>,)
    {
        # get error set when there is a REAL problem with the passed
        # in query, caller needs to be able to handle it
        my $tmp_error;
        while ($xpat_result =~ m,<Error>(.*?)</Error>,gs)
        {
            $tmp_error .= "$1\n"
        }
        $error = 1;
        $xpat_result = $tmp_error;
    }
    
    $xpat_result =~ s,<Sync>EndOfResults</Sync>,,gs;
    
    return ($error, $xpat_result);
}

# ---------------------------------------------------------------------

=item get_data_dict_name

Description

=cut

# ---------------------------------------------------------------------
sub get_data_dict_name
{
    my $self = shift;
    my $truncate = shift;
    
    my $dd = $self->{'dd'};
    $dd =~ s,^.*/,, if ($truncate);
    
    return $dd;
}

# ---------------------------------------------------------------------

=item get_pset_offset

Description

=cut

# ---------------------------------------------------------------------
sub get_pset_offset
{
    my $self = shift;
    return $self->{'pset_offset'};
}


# ----------------------------------------------------------------------


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
