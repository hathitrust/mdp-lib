package Namespaces;

=head1 NAME

Namespaces

=head1 DESCRIPTION

This package provides the interface and access logic to
namespace-specific data.

 CREATE TABLE `ht_namespaces` (
    `namespace`      varchar(8)   NOT     NULL,
    `institution`    varchar(255) DEFAULT NULL,
    `grin_instance`  varchar(32)  DEFAULT NULL,
    `default_source` varchar(32)  DEFAULT NULL,
           PRIMARY KEY (`namespace`)
    ) ENGINE=MyISAM DEFAULT CHARSET=latin1

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
use Identifier;

my %Namespace_Hash;

sub __load_namespace_hash {
    my $C = shift;

    return if (scalar keys %Namespace_Hash);

    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT * FROM ht_namespaces};
    my $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    %Namespace_Hash = map { $_->{namespace},
                              {
                               institution   => $_->{institution},
                               grin_instance => $_->{grin_instance},
                              }
                          } @$ref_to_arr_of_hashref;
}


# ---------------------------------------------------------------------

=item get_institution_by_namespace

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_by_namespace {
    my ($C, $id) = @_;

    __load_namespace_hash($C);
    my ($namespace, $barcode) = Identifier::split_id($id);

    return $Namespace_Hash{$namespace}->{institution};
}

# ---------------------------------------------------------------------

=item get_google_id_by_namespace

Description

=cut

# ---------------------------------------------------------------------
sub get_google_id_by_namespace {
    my ($C, $id) = @_;

    __load_namespace_hash($C);
    my ($namespace, $barcode) = Identifier::split_id($id);

    my $grin_prefix =
      __map_UCAL_GRIN_prefix(
                             $Namespace_Hash{$namespace}{grin_instance},
                             $barcode
                            );

    return (defined $grin_prefix) ? $grin_prefix . ':' . $barcode : undef;
}

# ---------------------------------------------------------------------

=item __map_uc1_2_GRIN_prefix

Description

=cut

# ---------------------------------------------------------------------
sub __map_UCAL_GRIN_prefix {
    my ($grin_prefix, $barcode) = @_;

    return $grin_prefix
      unless (defined $grin_prefix && $grin_prefix eq 'UCAL');
  
    # From ht_to_grin.rb aelkiss
    return 'UCSC'
      if ( $barcode =~ m/^32106\d{9}$/ );
    return 'UCSD'
      if ( $barcode =~ m/^31822\d{9}$/ );
    return 'UCSF'
      if ( $barcode =~ m/^31378\d{9}$/ );
    return 'UCD'
      if ( $barcode =~ m/^31175\d{9}$/ );
    return 'UCLA'
      if ( $barcode =~ m/^l\d{10}|31158\d{9}$/ );
    return 'SRLF'
      if ( $barcode =~ m/^a{1,3}\d{9}/ );

    # Nothing from these campuses?
    return 'UCI'
      if ( $barcode =~ m/^.1970\d{9}$/ );
    return 'UCSB'
      if ( $barcode =~ m/^.1205\d{9}$/ );
    return 'UCB'
      if ( $barcode =~ m/^\d{10}$/ );

    # No matches
    return 'UCAL';
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012-14 ©, The Regents of The University of Michigan, All Rights Reserved

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
