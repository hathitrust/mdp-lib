package MdpConfig;

=head1 NAME

MdpConfig (config)

=head1 DESCRIPTION

Overrides Config::Tiny to read and parse a config file.

=head1 SYNOPSIS

use MdpConfig;

my $config = new MdpConfig($config_file_name,
                             [$local_config_filename]);

if $local_config_filename is not defined, look in same directory as
$global_config_file for a local config file.

A local config file can also be used to supplement the global as well
as override parts of it.

$config->get('db_hostname');

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

use Config::Tiny;

use Utils;
use Debug::DUtils;



# ---------------------------------------------------------------------

=item new ($config_file_name)

Constructor. Calls Config::Auto::parse() and creates MdpConfig object.

=cut

# ---------------------------------------------------------------------
sub new {
    my $package = shift;
    my $config_filename = shift;
    my $local_config_filename = shift;

    ASSERT(-e "$config_filename",
           qq{"Could not find config file $config_filename"});
    ASSERT(-e "$local_config_filename",
           qq{"Could not find LOCAL config file $local_config_filename"})
        if (defined($local_config_filename));

    my $config = Config::Tiny->read($config_filename);
    ASSERT($config, qq{Error in config file $config_filename: } . Config::Tiny::errstr);

    my $local_config;

    my $self = {};
    $self->{'config'} = $config;
    $self->{'global_config_file'} = $config_filename;

    # Support Local development config if not passed in as second
    # parameter
    if (! defined($local_config_filename)) {
        if ($config_filename =~ m,global.conf,) {
            # Use the local sibling to global.conf for the path
            $local_config_filename = $config_filename;
            $local_config_filename =~ s,global,local,;
        }
    }

    if (-e $local_config_filename) {
        $local_config = Config::Tiny->read($local_config_filename);
        ASSERT($local_config, qq{Error in config file $config_filename: } . Config::Tiny::errstr);
    }

    if ($local_config) {
        $self->{'local_config_file'} = $local_config_filename;

        foreach my $key (keys %{$local_config->{_}} ) {
            $config->{_}{$key} = $local_config->{_}{$key};
        }
    }

    bless($self, $package);
    return $self;
}



# ---------------------------------------------------------------------

=item get ($config_var_name)

Get a config variable value

=cut

# ---------------------------------------------------------------------
sub get
{
    my ($self, $var_name) = @_;

    my $val = $self->{'config'}->{_}{$var_name};
    ASSERT(defined($val), qq{config key="$var_name" does not have a value});

    if (wantarray)
    {
        return split(/\|/, $val);
    }
    else
    {
        return $val;
    }
}


1;


# ---------------------------------------------------------------------

=item __config_debug

Description

=cut

# ---------------------------------------------------------------------
sub __config_debug
{
    my $self = shift;

    my $config = $self->{'config'};
    my $local_config = $self->{'local_config'};

    DEBUG('all,conf',
          sub
          {
              my $s;

              $s .= q{GLOBAL config file=} . $self->{'global_config_file'} . qq{<br/>\n};
              $s .= q{LOCAL config file=} . $self->{'local_config_file'} . qq{<br/><br/>\n};

              foreach my $key (sort keys %{$config->{_}} )
              {
                  my $local_override = '<b>LOCAL</b>'
                      if (defined($local_config->{_}{$key}));
                  $s .= qq{$key = $config->{_}{$key} $local_override<br/>\n}
              }
              return $s;
          });
}

__END__

=head1 AUTHOR

Original: Jessica Feeman, University of Michigan, jhovater@umich.edu
Modified: Phillip Farber, University of Michigan, pfarber@umich.edu

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
