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
    `alias_domain`   varchar(32)  NULL,
    `us`             tinyint(1)   NOT NULL DEFAULT '0',
    `mapto_domain`   varchar(32)  NULL,
    `mapto_sdrinst`  varchar(32)  NULL,
    `mapto_name`     varchar(256) NULL,
    `enabled`        tinyint(1)   NOT NULL DEFAULT '0',
    `orph_agree`     tinyint(1)   NOT NULL DEFAULT '0',
           PRIMARY KEY (`sdrinst`)
   );

 CREATE TABLE `ht_institutions` (
   `sdrinst`       varchar(32)  NOT NULL DEFAULT ' ',
   `name`          varchar(256) NOT NULL DEFAULT ' ',
   `template`      varchar(256) NOT NULL DEFAULT ' ',
   `authtype`      varchar(32)  NOT NULL DEFAULT 'shibboleth',
   `domain`        varchar(32)  NOT NULL DEFAULT ' ',
   `us`            tinyint(1)   NOT NULL DEFAULT '0',
   `mapto_domain`  varchar(32)           DEFAULT NULL,
   `mapto_sdrinst` varchar(32)           DEFAULT NULL,
   `mapto_name`    varchar(256)          DEFAULT NULL,
   `enabled`       tinyint(1)   NOT NULL DEFAULT '0',
   `orph_agree`    tinyint(1)   NOT NULL DEFAULT '0',
   `entityID`      varchar(256)          DEFAULT NULL,
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

my $Institution_Hash;

# ---------------------------------------------------------------------

=item __get_domains

return domain and alias_domain for $domain passed in as 'domain' or
'alias_domain'

=cut

# ---------------------------------------------------------------------
sub __get_domains {
    my $C = shift;
    my $candidate_domain = shift;

    return unless (defined $candidate_domain);

    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT domain, alias_domain FROM ht_institutions WHERE (domain=? OR alias_domain=?)};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $candidate_domain, $candidate_domain);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    my $domain = $ref_to_arr_of_hashref->[0]->{domain};
    my $alias_domain = $ref_to_arr_of_hashref->[0]->{alias_domain};

    return ($domain, $alias_domain);
}

sub __load_institution_hash {
    my $C = shift;
    my ($selector, $key, $value) = @_;

    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_institutions WHERE $key=?};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $value);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    $Institution_Hash->{$selector}{$value} = $ref_to_arr_of_hashref->[0];
}

sub _load_institution_domain_hash {
    my $C = shift;
    my $candidate_domain = shift;

    return if (defined $Institution_Hash->{domains}{$candidate_domain});

    my ($domain, $alias_domain) = __get_domains($C, $candidate_domain);

    __load_institution_hash($C, 'domains', 'domain', $domain)
      if (defined $domain);
    __load_institution_hash($C, 'domains', 'alias_domain', $alias_domain) 
      if (defined $alias_domain);
}

sub _load_institution_sdrinst_hash {
    my $C = shift;
    my $sdrinst = shift;

    return if (defined $Institution_Hash->{sdrinsts}{$sdrinst});

    __load_institution_hash($C, 'sdrinsts', 'sdrinst', $sdrinst);
}


# ---------------------------------------------------------------------

=item get_institution_domain_field_val

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_domain_field_val {
    my $C = shift;
    my ($domain, $field, $mapped) = @_;

    _load_institution_domain_hash($C, $domain);

    my $val;

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
        else {
            $val = $Institution_Hash->{domains}{$domain}{$field};
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

    _load_institution_sdrinst_hash($C, $sdrinst);

    my $val;

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
        else {
            $val = $Institution_Hash->{sdrinsts}{$sdrinst}{$field};
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

Description

Used by ping.

=cut

# ---------------------------------------------------------------------
sub get_idp_list {
    my $C = shift;
    my $list_ref = get_institution_list($C);
    my $results = [];

    my $inst = $C->get_object('Auth')->get_institution_code($C) || 'notaninstitution';

    foreach my $hash ( sort { $$a{name} cmp $$b{name} } @$list_ref ) {
        my $development = 0;

        if ( ! $$hash{enabled} ) {
            $development = 1;
            next unless ( $ENV{HT_DEV} );
        }

        my $idp_url = $$hash{template};
        my $host = $ENV{'HTTP_HOST'} || 'localhost';
        $idp_url =~ s,___HOST___,$host,;
        ## $idp_url =~ s,___TARGET___,$L_target,;

        push @$results, { 
            enabled => $$hash{enabled},
            sdrinst => $$hash{sdrinst},
            idp_url => $idp_url,
            authtype => $$hash{authtype},
            name => $$hash{name},
            selected => ( $inst eq $$hash{sdrinst} ),
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
