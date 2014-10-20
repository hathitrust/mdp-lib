package Access::Statements;

=head1 NAME

Access::Statements;

=head1 DESCRIPTION

This package provides an interface to the Access and Use statements
database. 

PROGRAMMING NOTE: This module is shared between HT apps (like pt, imgsrv) and
the Data API and the access stmts[_api] services.

=head1 SYNOPSIS

Do NOT call any of the PRIVATE: methods directly.

Accept a pair of values (mdp.rights_current.attr,
mdp.rights_current.access_profile) and return the statement field data as
requested in the request hash to which the pair maps. 

Only one of $C or $dbh is required.

my $stmt_hashref = Access::Statements::get_stmt_by_rights_values($C, $dbh, $attr, $access_profile,
                                 {
                                   stmt_key      => 1,
                                   stmt_url      => 1,
                                   stmt_url_aux  => 1,
                                   stmt_icon     => 1,
                                   stmt_icon_aux => 1,
                                   stmt_head     => 1,
                                   stmt_text     => 1,
                                 });

Return the basic statements by their keys.

my $stmt_ref = Access::Statements::get_stmt_by_key($C, $dbh, $key
                                 {
                                   stmt_key      => 1,
                                   stmt_url      => 1,
                                   stmt_url_aux  => 1,
                                   stmt_icon     => 1,
                                   stmt_icon_aux => 1,
                                   stmt_head     => 1,
                                   stmt_text     => 1,
                                 });


Refer to mdp-lib/RightsGlobals.pm for definitions of attribute, access_profile, statement-key, etc.

=head1 METHODS

=over 8

=cut

use Context;
use Utils;
use DbUtils;
use RightsGlobals;

my %ALL_FIELDS = 
  (
   stmt_key      => 1,
   stmt_head     => 1,
   stmt_text     => 1,
   stmt_url      => 1,
   stmt_url_aux  => 1,
   stmt_icon     => 1,
   stmt_icon_aux => 1,
  );
 
# ---------------------------------------------------------------------

=item get_stmt_by_rights_values

Description

=cut

# ---------------------------------------------------------------------
sub get_stmt_by_rights_values {
    my ($C, $dbh, $attr, $access_profile, $req_ref) = @_;

    my $_dbh = defined($C) ? $C->get_object('Database')->get_DBH($C) : $dbh;
    my $sth;
    
    my ($attr_key, $access_profile_key) = 
      (
       $RightsGlobals::g_attribute_keys{$attr},
       $RightsGlobals::g_access_profile_names{$access_profile},
      );

    $attr_key = 'nobody' unless ($attr_key);
    $access_profile_key = 'google' unless ($access_profile_key);
    
    my $key_SELECT_clause = qq{(SELECT stmt_key FROM test_access_stmts_map WHERE a_attr=? AND a_access_profile=?)};
    $sth = DbUtils::prep_n_execute($_dbh, $key_SELECT_clause, $attr_key, $access_profile_key);
    my $key = $sth->fetchrow_array();
    $req_ref->{stmt_key} = $key;

    my $database_fields_arr_ref = __build_field_lists($req_ref);
    my $database_fields = join(', ', @$database_fields_arr_ref);
    
    my $WHERE_clause = qq{WHERE access_stmts.stmt_key=$key_SELECT_clause};
    my $statement = qq{SELECT $database_fields FROM access_stmts } . $WHERE_clause;
    $sth = DbUtils::prep_n_execute($_dbh, $statement, $attr_key, $access_profile_key);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}

# ---------------------------------------------------------------------

=item get_stmt_by_key

Description

=cut

# ---------------------------------------------------------------------
sub get_stmt_by_key {
    my ($C, $dbh, $key, $req_ref) = @_;

    my $_dbh = defined($C) ? $C->get_object('Database')->get_DBH($C) : $dbh;

    my $database_fields_arr_ref = __build_field_lists($req_ref);
    my $database_fields = join(', ', @$database_fields_arr_ref);

    my $WHERE_clause = qq{WHERE access_stmts.stmt_key=?};
    my $statement = qq{SELECT $database_fields FROM access_stmts } . $WHERE_clause;
    my $sth = DbUtils::prep_n_execute($_dbh, $statement, $key);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}

# ---------------------------------------------------------------------

=item get_all_stmts

Description

=cut

# ---------------------------------------------------------------------
sub get_all_stmts {
    my ($C, $dbh, $req_ref) = @_;

    my $_dbh = defined($C) ? $C->get_object('Database')->get_DBH($C) : $dbh;

    my $database_fields_arr_ref = __build_field_lists($req_ref);
    my $database_fields = join(', ', @$database_fields_arr_ref);

    my $statement = qq{SELECT $database_fields FROM access_stmts };
    my $sth = DbUtils::prep_n_execute($_dbh, $statement);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}

# ---------------------------------------------------------------------

=item get_all_mappings

Description

=cut

# ---------------------------------------------------------------------
sub get_all_mappings {
    my ($C, $dbh) = @_;

    my $_dbh = defined($C) ? $C->get_object('Database')->get_DBH($C) : $dbh;

    my $statement = qq{SELECT * FROM test_access_stmts_map };
    my $sth = DbUtils::prep_n_execute($_dbh, $statement);
    my $ref_to_arr_of_hashref = $sth->fetchall_arrayref({});

    return $ref_to_arr_of_hashref;
}


# ---------------------------------------------------------------------

=item __build_field_lists

Construct fields lists to return data from database and RightsGlobals

=cut

# ---------------------------------------------------------------------
sub __build_field_lists {
    my $req_hashref = shift;

    my @database_fields = ();
    
    foreach my $field (keys %$req_hashref) {
        if ($ALL_FIELDS{$field}) {
            if ($req_hashref->{$field}) {
                push(@database_fields, $field);
            }
        }
    }

    return \@database_fields;
}


1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011-14 ©, The Regents of The University of Michigan, All Rights Reserved

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
