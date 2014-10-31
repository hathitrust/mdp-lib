package Institutions;


=head1 NAME

Institutions;

=head1 DESCRIPTION

This package provides the interface and access logic to
institution-specific data.

 CREATE TABLE `ht_institutions` (
   `sdrinst`          varchar(32)  NOT NULL DEFAULT ' ',
   `name`             varchar(256) NOT NULL DEFAULT ' ',
   `template`         varchar(256) NOT NULL DEFAULT ' ',
   `authtype`         varchar(32)  NOT NULL DEFAULT 'shibboleth',
   `domain`           varchar(32)  NOT NULL DEFAULT ' ',
   `us`               tinyint(1)   NOT NULL DEFAULT '0',
   `mapto_domain`     varchar(32)           DEFAULT NULL,
   `mapto_sdrinst`    varchar(32)           DEFAULT NULL,
   `mapto_name`       varchar(256)          DEFAULT NULL,
   `map_to_entityID`  varchar(256)          DEFAULT NULL,
   `enabled`          tinyint(1)   NOT NULL DEFAULT '0',
   `orph_agree`       tinyint(1)   NOT NULL DEFAULT '0',
   `entityID`         varchar(256)          DEFAULT NULL,
              PRIMARY KEY (`sdrinst`)
 );

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use Context;
use Database;
use DbUtils;

# ---------------------------------------------------------------------

=item ___get_I_ref, ___set_I_ref

Needed for persistent clients, e.g. imgsrv.

=cut

# ---------------------------------------------------------------------
sub ___get_I_ref {
    my $C = shift;

    my $Institution_Hash_ref = ( $C->has_object('Institutions') ? $C->get_object('Institutions') : {} );
    return $Institution_Hash_ref;
}
sub ___set_I_ref {
    my ($C, $i_ref) = @_;

    bless $i_ref, 'Institutions';
    $C->set_object('Institutions', $i_ref);
}


sub __Load_Institution_Hash {
    my $C = shift;
    my ($selector, $key, $value) = @_;

    my $Institution_Hash = ___get_I_ref($C);

    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_institutions WHERE $key=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $value);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    $Institution_Hash->{$selector}{$value} = $ref_to_arr_of_hashref->[0];

    ___set_I_ref($C, $Institution_Hash);

    return $Institution_Hash;
}


# ---------------------------------------------------------------------

=item _load_institution_sdrinst_hash, _load_institution_entityID_hash, _load_institution_domain_hash

We do lookups based on entityID if the user is authenticated or, when
not, by sdrinst, obtained from Apache SDRINST environment variable
which is set based on institutional IP address ranges.

=cut

# ---------------------------------------------------------------------
sub _load_institution_sdrinst_hash {
    my $C = shift;
    my $sdrinst = shift;

    my $Institution_Hash = ___get_I_ref($C);
    return $Institution_Hash if (defined $Institution_Hash->{sdrinsts}{$sdrinst});

    $Institution_Hash = __Load_Institution_Hash($C, 'sdrinsts', 'sdrinst', $sdrinst);
    return $Institution_Hash;
}

sub _load_institution_entityID_hash {
    my $C = shift;
    my $entityID = shift;

    my $Institution_Hash = ___get_I_ref($C);
    return $Institution_Hash if (defined $Institution_Hash->{entityIDs}{$entityID});

    $Institution_Hash = __Load_Institution_Hash($C, 'entityIDs', 'entityID', $entityID);
    return $Institution_Hash;
}

sub _load_institution_domain_hash {
    my $C = shift;
    my $domain = shift;

    my $Institution_Hash = ___get_I_ref($C);
    return $Institution_Hash if (defined $Institution_Hash->{domains}{$domain});

    $Institution_Hash = __Load_Institution_Hash($C, 'domains', 'domain', $domain);
    return $Institution_Hash;
}


# ---------------------------------------------------------------------

=item get_institution_entityID_field_val

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_entityID_field_val {
    my $C = shift;
    my ($entityID, $field, $mapped) = @_;

    return undef unless ( (defined($entityID) && $entityID) && (defined($field) && $field) );
    
    my $val;
    my $Institution_Hash = _load_institution_entityID_hash($C, $entityID);

    if (! $mapped) {
        $val = $Institution_Hash->{entityIDs}{$entityID}{$field};
    }
    else {
        if ($field eq 'name' && $Institution_Hash->{entityIDs}{$entityID}{mapto_name}) {
            $val = $Institution_Hash->{entityIDs}{$entityID}{mapto_name};
        }
        elsif ($field eq 'domain' && $Institution_Hash->{entityIDs}{$entityID}{mapto_domain}) {
            $val = $Institution_Hash->{entityIDs}{$entityID}{mapto_domain};
        }
        elsif ($field eq 'sdrinst' && $Institution_Hash->{entityIDs}{$entityID}{mapto_sdrinst}) {
            $val = $Institution_Hash->{entityIDs}{$entityID}{mapto_sdrinst};
        }
        elsif ($field eq 'entityID' && $Institution_Hash->{entityIDs}{$entityID}{mapto_entityID}) {
            $val = $Institution_Hash->{entityIDs}{$entityID}{mapto_sdrinst};
        }
        else {
            $val = $Institution_Hash->{entityIDs}{$entityID}{$field};
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

    return undef unless ( (defined($sdrinst) && $sdrinst) && (defined($field) && $field) );

    my $val;
    my $Institution_Hash = _load_institution_sdrinst_hash($C, $sdrinst);

    if (! $mapped) {
        $val = $Institution_Hash->{sdrinsts}{$sdrinst}{$field};
    }
    else {
        if ($field eq 'name' && $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_name}) {
            $val = $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_name};
        }
        elsif ($field eq 'domain' && $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_domain}) {
            $val = $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_domain};
        }
        elsif ($field eq 'sdrinst' && $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_sdrinst}) {
            $val = $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_sdrinst};
        }
        elsif ($field eq 'entityID' && $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_entityID}) {
            $val = $Institution_Hash->{sdrinsts}{$sdrinst}{mapto_entityID};
        }
        else {
            $val = $Institution_Hash->{sdrinsts}{$sdrinst}{$field};
        }
    }

    return $val;
}

# ---------------------------------------------------------------------

=item get_institution_domain_field_val

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_domain_field_val {
    my $C = shift;
    my ($domain, $field, $mapped) = @_;

    return undef unless ( (defined($domain) && $domain) && (defined($field) && $field) );

    my $val;
    my $Institution_Hash = _load_institution_domain_hash($C, $domain);

    if (! $mapped) {
        $val = $Institution_Hash->{domains}{$domain}{$field};
    }
    else {
        if ($field eq 'name' && $Institution_Hash->{domains}{$domain}{mapto_name}) {
            $val = $Institution_Hash->{domains}{$domain}{mapto_name};
        }
        elsif ($field eq 'domain' && $Institution_Hash->{domains}{$domain}{mapto_domain}) {
            $val = $Institution_Hash->{domains}{$domain}{mapto_domain};
        }
        elsif ($field eq 'sdrinst' && $Institution_Hash->{domains}{$domain}{mapto_sdrinst}) {
            $val = $Institution_Hash->{domains}{$domain}{mapto_sdrinst};
        }
        elsif ($field eq 'entityID' && $Institution_Hash->{domains}{$domain}{mapto_entityID}) {
            $val = $Institution_Hash->{domains}{$domain}{mapto_entityID};
        }
        else {
            $val = $Institution_Hash->{domains}{$domain}{$field};
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

# ---------------------------------------------------------------------

=item get_idp_list

Used by ping.

=cut

# ---------------------------------------------------------------------
sub get_idp_list {
    my $C = shift;
    my $list_ref = get_institution_list($C);
    my $results = [];

    my $inst = $C->get_object('Auth')->get_institution_code($C) || 'notaninstitution';

    foreach my $hash_ref ( sort { $a->{name} cmp $b->{name} } @$list_ref ) {
        my $add_to_list = 0;

        if ( $hash_ref->{enabled} == 0 ) {
            $add_to_list = 1 if ( defined $ENV{HT_DEV} );
        }
        elsif ( $hash_ref->{enabled} == 1 ) {
            $add_to_list = 1;
        }
        elsif ( $hash_ref->{enabled} == 2 ) {
            $add_to_list = 0;
        }
        next unless ($add_to_list);

        my $idp_url = $hash_ref->{template};
        my $host = $ENV{'HTTP_HOST'} || 'localhost';
        $idp_url =~ s,___HOST___,$host,;

        push @$results, {
            enabled => $hash_ref->{enabled},
            sdrinst => $hash_ref->{sdrinst},
            idp_url => $idp_url,
            authtype => $hash_ref->{authtype},
            name => $hash_ref->{name},
            selected => ( $inst eq $hash_ref->{sdrinst} ),
        };

    }

    return $results;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012-2014 ©, The Regents of The University of Michigan, All Rights Reserved

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
