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

# Need to override a value?

$config->override('db_hostname', $ENV[DB_HOSTNAME]);

=head1 METHODS

=over 8

=cut

use strict;

use Config::Tiny;

use Utils;
use Debug::DUtils;


sub new {
    my $package = shift;
    my $primary_config_filename = shift;
    my $secondary_config_filename = shift;
    my $tertiary_config_filename = shift;

    my $self = { config => {} };

    bless($self, $package);

    $self->{primary_config_file} = $primary_config_filename;
    $self->add_config_from_file($primary_config_filename, 'primary_config');

    if (defined($secondary_config_filename)) {
        $self->{secondary_config_file} = $secondary_config_filename;
        $self->add_config_from_file($secondary_config_filename, 'secondary_config');
    }

    if (defined($tertiary_config_filename)) {
        $self->{tertiary_config_file} = $tertiary_config_filename;
        $self->add_config_from_file($secondary_config_filename, 'tertiary_config');
    }

    return $self;

}

# ---------------------------------------------------------------------

=item add_config_from_file($config_file, $optional_config_key)

Add configuration values from the given file, doing ENV[key] expansion.

If the optional config_key is given, the Config::Tiny object resulting
from loading that file will be stored in $self->{$optional_config_key}

=cut

# ---------------------------------------------------------------------

sub add_config_from_file {
    my $self = shift;
    my $config_file = shift;
    my $config_key = shift;

    ASSERT(-e "$config_file",
        qq{"Could not find  config file $config_file"});

    my $config = Config::Tiny->read($config_file);
    ASSERT($config, qq{Error in config file $config_file: } . Config::Tiny::errstr);

    if (defined($config_key)) {
        $self->{$config_key} = $config;
    }
    $self->merge_from_config_tiny($config);
    $self->override_from_ENV($config_file);
}


sub merge_from_config_tiny {
    my $self = shift;
    my $ct = shift;
    $self->override_from_hashref($ct->{_});
}

# ---------------------------------------------------------------------

=item merge($config)

Description

=cut

# ---------------------------------------------------------------------
sub merge {
    my $self = shift;
    my $M_config = shift;

    my $mtype = ref $M_config;

    ASSERT(($mtype eq 'MdpConfig'), qq{"Invalid argument: MdpConfig merge given '$mtype' instead of MdpConfig object"});


    foreach my $key (CORE::keys %{$M_config->{'config'}{_}}) {
        # Do not overwrite any key value in the main config that came
        # from a tertiary config file.  Those are (typically)
        # debugging values that would be stomped by defaults from the
        # to-be-merged-in M_config
        if (defined $self->{'tertiary_config'}->{_}{$key}) {
            if ($self->{'tertiary_config'}->{_}{$key} ne $M_config->{'config'}->{_}{$key}) {
                next;
            }
        }

        $self->{'config'}->{_}{$key} = $M_config->{'config'}->{_}{$key};
    }

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


# ---------------------------------------------------------------------

=item keys

Get all the keys. MdpConfig doesn't allow any hierarchy at all,
so, it's all top-level

=cut


# ---------------------------------------------------------------------

sub keys {
    my $self = shift;
    return CORE::keys(%{$self->{'config'}->{_}});
}


# ---------------------------------------------------------------------

=item override($key, $val)

Set (and thus override) a configuation parameter

=cut

# ---------------------------------------------------------------------

sub override {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    my $config = $self->{'config'};
    $config->{_}{$key} = $value;
    return $value;
}


# ---------------------------------------------------------------------

=item override_from_hashref($hashref)

Set (and thus potentially overrides) key/value pairs from the given hashref

=cut

# ---------------------------------------------------------------------

sub override_from_hashref {
    my $self = shift;
    my $hr = shift;

    foreach my $key (CORE::keys %$hr) {
        $self->override($key, $hr->{$key});
    }
}


# ---------------------------------------------------------------------

=item override_from_ENV

Any value of the form ENV[keyname] will be overwritten with the
corresponding environment variable.

If the environment variable is unset, throw a warning and move on.

=cut

# ---------------------------------------------------------------------

sub override_from_ENV {
    my $self = shift;
    my $filename = shift;

    $filename || ($filename = "<unknown>");

    foreach my $key ($self->keys()) {
        my $val = $self->get($key);
        if ($val =~ /ENV\[["']?(.+?)["']?\]/) {
            my $env_var = $1;
            my $env_val = $ENV{$env_var};
            if ($env_val) {
                $self->override($key, $env_val);
            }
            else {
                warn("Config $filename references ENV[$env_var] which is unset");
            }
        }
    }
}


# ---------------------------------------------------------------------

=item has ($config_var_name)

Test that a config variable has a value

=cut

# ---------------------------------------------------------------------
sub has {
    my ($self, $var_name) = @_;

    my $val = $self->{'config'}->{_}{$var_name};
    return defined($val);
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

            foreach my $key (sort CORE::keys %{$config->{_}}) {
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
