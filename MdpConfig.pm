package MdpConfig;

=head1 NAME

MdpConfig (config)

=head1 DESCRIPTION

Wraps Config::Tiny to read and parse a config file.

Typically the $primary_config_filename is the most global followed by
a more local $secondary_config_filename.  So, for example the
$primary_config_filename might be the configuration for a suite of
applications and the $secondary_config_filename might be the
supplements for a single application.

The $tertiary_config_filename could be used to override setting in
either the $primary_config_filename or $secondary_config_filename for
development purposes.

Either $secondary_config_filename or $tertiary_config_filename are
optional.  Use undef for $secondary_config_filename if not required and
a $tertiary_config_filename is specified. The variations on this theme
are apparent.

=head1 SYNOPSIS

use MdpConfig;

my $config = new MdpConfig($primary_config_filename,
                           [$secondary_config_filename, $tertiary_config_filename]);

$config->get('db_hostname');

=head1 METHODS

=over 8

=cut

use strict;

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
    my $primary_config_filename = shift;
    my $secondary_config_filename = shift;
    my $tertiary_config_filename = shift;

    ASSERT(-e "$primary_config_filename",
           qq{"Could not find primary config file $primary_config_filename"});

    my $config;

    my $primary_config = $config = Config::Tiny->read($primary_config_filename);
    ASSERT($primary_config, qq{Error in primary config file $primary_config_filename: } . Config::Tiny::errstr);

    my $self = {};
    $self->{'primary_config'} = $primary_config;
    $self->{'primary_config_file'} = $primary_config_filename;

    my $secondary_config;
    if (defined($secondary_config_filename)) {
        if (-e "$secondary_config_filename") {
            $secondary_config = Config::Tiny->read($secondary_config_filename);
            ASSERT($secondary_config, qq{Error in secondary config file $secondary_config_filename: } . Config::Tiny::errstr);
            $self->{'secondary_config'} = $secondary_config;
            $self->{'secondary_config_file'} = $secondary_config_filename;

            foreach my $key (keys %{$secondary_config->{_}} ) {
                $config->{_}{$key} = $secondary_config->{_}{$key};
            }
        }
    }

    my $tertiary_config;
    if (defined($tertiary_config_filename)) {
        if (-e "$tertiary_config_filename") {
            $tertiary_config = Config::Tiny->read($tertiary_config_filename);
            ASSERT($tertiary_config, qq{Error in tertiary config file $tertiary_config_filename: } . Config::Tiny::errstr);
            $self->{'tertiary_config'} = $tertiary_config;
            $self->{'tertiary_config_file'} = $tertiary_config_filename;

            foreach my $key (keys %{$tertiary_config->{_}} ) {
                $config->{_}{$key} = $tertiary_config->{_}{$key};
            }
        }
    }

    $self->{'config'} = $config;

    bless($self, $package);
    return $self;
}



# ---------------------------------------------------------------------

=item get ($config_var_name)

Get a config variable value

=cut

# ---------------------------------------------------------------------
sub get {
    my ($self, $var_name) = @_;

    my $val = $self->{'config'}->{_}{$var_name};
    ASSERT(defined($val), qq{config key="$var_name" does not have a value});

    if (wantarray) {
        return split(/\|/, $val);
    }
    else {
        return $val;
    }
}


1;


# ---------------------------------------------------------------------

=item __config_debug

Description

=cut

# ---------------------------------------------------------------------
sub __config_debug {
    my $self = shift;

    my $config = $self->{'config'};
    my $primary_config = $self->{'primary_config'};
    my $secondary_config = $self->{'secondary_config'};
    my $tertiary_config = $self->{'tertiary_config'};

    DEBUG('all,conf',
          sub {
              my $s;

              $s .= q{primary config file=} . $self->{'primary_config_file'} . qq{<br/>\n};
              $s .= q{secondary config file=} . $self->{'secondary_config_file'} . qq{<br/>\n};
              $s .= q{tertiary config file=} . $self->{'tertiary_config_file'} . qq{<br/>\n};

              foreach my $key (sort keys %{$config->{_}} ) {
                  my $res = $config->{_}{$key};

                  my $pri = $primary_config->{_}{$key};
                  my $sec = $secondary_config->{_}{$key} if ($secondary_config);
                  my $ter = $tertiary_config->{_}{$key} if ($tertiary_config);

                  my $from = (defined($ter) ? 'tertiary' : (defined($sec) ? 'secondary' : 'primary'));
                  $s .= qq{$key = $res from $from config<br/>\n}
              }
              return $s;
          });
}

__END__

=head1 AUTHOR

Original: Jessica Feeman, University of Michigan, jhovater@umich.edu
Modified: Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-2010 ©, The Regents of The University of Michigan, All Rights Reserved

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
