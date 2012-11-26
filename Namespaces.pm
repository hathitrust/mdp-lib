package Namespaces;

=head1 NAME

Namespaces

=head1 DESCRIPTION

This package provides the interface and access logic to
namespace-specific data.

 CREATE TABLE `ht_namespaces` (
    `namespace`      varchar(8)   NOT     NULL,
    `institution`    varchar(255) DEFAULT NULL,
    `inst_code`      varchar(8)   DEFAULT NULL,
    `grin_instance`  varchar(32)  DEFAULT NULL,
    `default_source` varchar(32)  DEFAULT NULL,
           PRIMARY KEY (`namespace`)
    ) ENGINE=MyISAM DEFAULT CHARSET=latin1

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use Context;
use Database;
use DbUtils;

my %Namespace_Hash;

sub __load_namespace_hash {
    my $C = shift;

    return if (scalar keys %Namespace_Hash);
    
    my $dbh = $C->get_object('Database')->get_DBH;

    my $statement = qq{SELECT namespace, institution FROM ht_namespaces};
    my $sth = DbUtils::prep_n_execute($dbh, $statement, $value);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    %Namespace_Hash = map { $_->{namespace}, $_->{institution} } @$ref_to_arr_of_hashref;
}


# ---------------------------------------------------------------------

=item get_institution_by_namespace

Description

=cut

# ---------------------------------------------------------------------
sub get_institution_by_namespace {
    my ($C, $namespace) = @_;

    __load_namespace_hash($C);

    return $Namespace_Hash{$namespace};
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
