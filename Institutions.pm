package Institutions;


=head1 NAME

Institutions;

=head1 DESCRIPTION

This package provides the interface and access logic to
institution-specific data.

 CREATE TABLE `ht_institutions`
   (
    `sdrinst`        varchar(32)  NOT NULL DEFAULT ' ',
    `name`           varchar(256) NOT NULL DEFAULT ' ',
    `template`       varchar(256) NOT NULL DEFAULT ' ',
    `authtype`       varchar(32)  NOT NULL DEFAULT 'shibboleth',
    `domain`         varchar(32)  NOT NULL DEFAULT ' ',
    `us`             tinyint(1)   NOT NULL DEFAULT '0',
    `mapto_domain`   varchar(32)  NULL,
    `mapto_sdrinst`  varchar(32)  NULL,
    `mapto_name`     varchar(256) NULL,
    `enabled`        tinyint(1)   NOT NULL DEFAULT '0',
    `orph_agree`     tinyint(1)   NOT NULL DEFAULT '0',
           PRIMARY KEY (`sdrinst`)
   );

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use Context;
use Database;
use DbUtils;

my $Institution_Domain_Hash;
my $Institution_SDRINST_Hash;

sub __load_institution_hash {
    my $C = shift;
    my $key = shift;
    my $value = shift;

    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_institutions WHERE $key=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $value);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    $Institution_Domain_Hash->{$value} =
      {
       'sdrinst'       => $ref_to_arr_of_hashref->[0]->{sdrinst},
       'name'          => $ref_to_arr_of_hashref->[0]->{name},
       'template'      => $ref_to_arr_of_hashref->[0]->{template},
       'authtype'      => $ref_to_arr_of_hashref->[0]->{authtype},
       'domain'        => $ref_to_arr_of_hashref->[0]->{domain},
       'us'            => $ref_to_arr_of_hashref->[0]->{us},
       'mapto_domain'  => $ref_to_arr_of_hashref->[0]->{mapto_domain},
       'mapto_sdrinst' => $ref_to_arr_of_hashref->[0]->{mapto_sdrinst},
       'mapto_name'    => $ref_to_arr_of_hashref->[0]->{mapto_name},
       'enabled'       => $ref_to_arr_of_hashref->[0]->{enabled},
       'orph_agree'    => $ref_to_arr_of_hashref->[0]->{orph_agree},
      };
}

sub __load_institution_domain_hash {
    my $C = shift;
    my $domain = shift;

    return if (defined $Institution_Domain_Hash->{$domain});

    __load_institution_hash($C, 'domain', $domain);
}

sub __load_institution_sdrinst_hash {
    my $C = shift;
    my $sdrinst = shift;

    return if (defined $Institution_SDRINST_Hash->{$sdrinst});

    __load_institution_hash($C, 'sdrinst', $sdrinst);
}


# ---------------------------------------------------------------------

=item get_institution_field_val

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_domain_field_val {
    my $C = shift;
    my ($domain, $field, $mapped) = @_;

    __load_institution_domain_hash($C, $domain);

    my $val;

    if (! $mapped) {
        $val = $Institution_Domain_Hash->{$domain}->{$field};
    }
    else {
        if ($field eq 'name' && $Institution_Domain_Hash->{$domain}->{mapto_name}) {
            $val = $Institution_Domain_Hash->{$domain}->{mapto_name};
        }
        elsif ($field eq 'domain' && $Institution_Domain_Hash->{$domain}->{mapto_domain}) {
            $val = $Institution_Domain_Hash->{$domain}->{mapto_domain};
        }
        elsif ($field eq 'sdrinst' && $Institution_Domain_Hash->{$domain}->{mapto_sdrinst}) {
            $val = $Institution_Domain_Hash->{$domain}->{mapto_sdrinst};
        }
        else {
            $val = $Institution_Domain_Hash->{$domain}->{$field};
        }
    }

    return $val;
}

# ---------------------------------------------------------------------

=item get_institution_sdrinst_field_val

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_sdrinst_field_val {
    my $C = shift;
    my ($sdrinst, $field, $mapped) = @_;

    __load_institution_sdrinst_hash($C, $sdrinst);

    my $val;

    if (! $mapped) {
        $val = $Institution_Domain_Hash->{$sdrinst}->{$field};
    }
    else {
        if ($field eq 'name' && $Institution_Domain_Hash->{$sdrinst}->{mapto_name}) {
            $val = $Institution_Domain_Hash->{$sdrinst}->{mapto_name};
        }
        elsif ($field eq 'domain' && $Institution_Domain_Hash->{$sdrinst}->{mapto_domain}) {
            $val = $Institution_Domain_Hash->{$sdrinst}->{mapto_domain};
        }
        elsif ($field eq 'sdrinst' && $Institution_Domain_Hash->{$sdrinst}->{mapto_sdrinst}) {
            $val = $Institution_Domain_Hash->{$sdrinst}->{mapto_sdrinst};
        }
        else {
            $val = $Institution_Domain_Hash->{$sdrinst}->{$field};
        }
    }

    return $val;
}

# ---------------------------------------------------------------------

=item get_institution_list

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_list {
    my $C = shift;

    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_institutions};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012 ©, The Regents of The University of Michigan, All Rights Reserved

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
