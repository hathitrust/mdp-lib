package DbUtils;


=head1 NAME

DbUtils;

=head1 DESCRIPTION

This package contains database DBI utilities

=head1 VERSION

$Id: DbUtils.pm,v 1.15 2009/05/04 17:09:59 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use DBI;
use Utils;
use Debug::DUtils;

use constant DATABASE_RETRY_SLEEP => 300; # 5 minutes
use constant MAX_DATABASE_RETRIES => 12;  # 1 hour of outage

use Utils::Logger;
use Time::HiRes qw(time);

use constant LOG_QUERIES => 1;


# ---------------------------------------------------------------------

=item prep_n_execute

Description

=cut

# ---------------------------------------------------------------------
sub prep_n_execute {
    my ($dbh, $statement, @params) = @_;

    my $start = time;

    # Ensure connection for long running jobs and for apps that have
    # to work across database maintenance intervals
    my $db_ok = $dbh->ping();
    if ($ENV{DATABASE_LONG_RETRY}) {
        unless($db_ok) {
            my $retries = 0;
            while ($retries < MAX_DATABASE_RETRIES) {
                sleep DATABASE_RETRY_SLEEP;
                $db_ok = $dbh->ping();
                last if ($db_ok);
                $retries++;
            }
        }
    }

    @params = () if (! defined $params[0]);

    my $count_ref;
    if ( ref($params[-1]) ) {
        $count_ref = pop @params;
    }

    # my $statement;
    # my @params;
    # unless(ref($statement_n_params)) {
    #     $statement = $statement_n_params;
    # } else {
    #     $statement = shift @$statement_n_params;
    #     @params = @$statement_n_params;
    # }

    my $ct;
    my $sth;
    eval
    {
        $sth = $dbh->prepare($statement);
    };
    ASSERT((! $@), qq{DBI error: $@});
    ASSERT($sth, qq{Could not prepare statement: $statement } . ($dbh->errstr || ''));

    eval
    {
        $ct = $sth->execute(@params);
    };
    ASSERT((! $@), qq{DBI error on statement=$statement: $@});
    ASSERT($ct, qq{Could not execute statement=$statement } . ($sth->errstr || ''));
    $$count_ref = $ct if (ref($count_ref));

    if (DEBUG('dbtime') || 0) { #XXX 1
        my $elapsed = time - $start;
        my ($package, $filename, $line, $subroutine) = caller(1);
        print STDERR "elapsed=$elapsed $subroutine $statement \n";
    }

    if ( LOG_QUERIES ) {
        _log_message($start, $statement, \@params);
    }

    return $sth;
}

# ---------------------------------------------------------------------

=item generate_unique_id

Returns a 32-bit signed integer between 0 and 2147483647 that is not a
value currently sotred in the indicated field of the indicated table.

Wed Mar 16 10:41:21 2011 Collection Builder LS backend needs a value
for the coll_id Solr doc field for every item regardless of whether
the item is in a collection or not.  Reserve 0 for the coll_id of
items not in any collection.

=cut

# ---------------------------------------------------------------------
sub generate_unique_id
{
    my ($dbh, $table_name, $cell_name) = @_;

    use constant MAXSIGNEDINTLESSONE => 2147483647 - 1;
    my $uniq_id;

    # zero is reserved for special cases
    my $testing = 1;
    while ($testing)
    {
        $uniq_id = int(rand()*MAXSIGNEDINTLESSONE) + 1;
        if (! get_cell_by_key($dbh, $table_name, $cell_name, $cell_name, $uniq_id))
        {
            $testing = 0;
        }
    }

    return $uniq_id;
}

# ---------------------------------------------------------------------

=item get_cell_by_key


Retrieve a single cell, identified by unique key.

($dbh) reference a DBI database handle.  ($table_name) name of
table to use.  ($cell_name) the column name of the cell for which a
value is desired.  ($key_col_name) name of column holding keys.
($key_col_val) value of key to match.

If the key isn't unique, only the first cell value for the first row
of the retrieval is returned.

=cut

# ---------------------------------------------------------------------
sub get_cell_by_key
{
    my ($dbh, $table_name, $cell_name, $key_col_name, $key_col_val, $limit) = @_;


    my $limit_clause = '';
    if ( (defined $limit) && ($limit =~ m,^\d+$,) ) {
        $limit_clause = qq{LIMIT $limit};
    }

    my $statement = qq{SELECT $cell_name FROM $table_name WHERE $key_col_name=? $limit_clause;};
    my $sth = prep_n_execute($dbh, $statement, $key_col_val);
    my @row = $sth->fetchrow_array();
    $sth->finish;

    return $row[0];
}


# ---------------------------------------------------------------------

=item update_row_by_key

($dbh) reference to a DBI database handle.  ($table_name) name of
table to use.  ($rowHashRef) a hash with column names as keys and
column values as values.  ($key_col_val) value of key to match.

Potentially updates multiple rows if there are multiple key matches.

Order of columns not important.  Only the columns to be updated must
be provided.  Columns with auto_entered data should generally not be
included. The database will handle them.

=cut

# ---------------------------------------------------------------------
sub update_row_by_key
{
    my ($dbh, $table_name, $row_hashref, $key_col_name, $key_col_val) = @_;
    my $set_string;

    my $where = qq{WHERE $key_col_name\=\?};
    update_row_where($dbh, $table_name, $row_hashref, $where, $key_col_val);
}



# ---------------------------------------------------------------------

=item update_row_where


Update row(s) in a table, identified by where clause.

($DBHref) reference to a DBI database handle.  ($tableName) name of
table to use.  ($rowHashRef) a hash with column names as keys and
column values as values.  ($where) value of where clause to match rows
on.

Potentially updates multiple rows if there are multiple matches of the
where clause.  Order of columns not important.

Only the columns to be updated must be provided.

Columns with auto_entered data should generally not be included. The
database will handle them.

=cut

# ---------------------------------------------------------------------
sub update_row_where
{
    my ($dbh, $table_name, $row_hashref, $where, @params) = @_;
    my $set_string;

    # unshift values onto @params
    my @tmp;
    foreach my $col_name (keys %$row_hashref)
    {
        push @tmp, $$row_hashref{$col_name};
	    $set_string .= $col_name . qq{=?, };
    }
    # strip the trailing comma and space off the end of the setString
    chop($set_string);
    chop($set_string);

    unshift @params, @tmp;

    my $statement = qq{UPDATE $table_name SET $set_string $where;};
    my $sth = prep_n_execute($dbh, $statement, @params);
    $sth->finish;
}


# ---------------------------------------------------------------------

=item del_row_by_key

Description

=cut

# ---------------------------------------------------------------------
sub del_row_by_key
{
    my ($dbh, $table_name, $key_colname, $key_colval) = @_;
    my $statement = qq{DELETE FROM $table_name WHERE $key_colname = ? LIMIT 1;};
    my $sth = prep_n_execute($dbh, $statement, $key_colval);
    $sth->finish;
}

# ---------------------------------------------------------------------

=item get_last_insert_id

Return primary key of the last inserted row in this session XXX remove when no longer needed

=cut

# ---------------------------------------------------------------------
sub get_last_insert_id
{
    my ($dbh) = @_;
    my $statement = qq{SELECT LAST_INSERT_ID();};
    my $sth = prep_n_execute($dbh, $statement);

    my (@id) = $sth->fetchrow_array();
    $sth->finish;
    die qq{select last_insert_id returned 0}  if ($id[0] == 0);

    return $id[0];
}


# ---------------------------------------------------------------------

=item  del_one_or_more_rows_by_key

 Delete one or more rows, identified by unique key.
 INPUT        : 1) ($dbh)  DBI database handle.
                2) ($table_name) name of table to use.
                3) ($key_col_name) name of column holding keys.
                4) ($key_col_val) value of key to match.
Description

=cut

# ---------------------------------------------------------------------
sub del_one_or_more_rows_by_key
{
    my ($dbh, $table_name, $key_col_name, $key_col_val) = @_;
    # my $quotedKeyValue = quote( $dbh, $key_col_val );
    my $statement = qq{DELETE FROM $table_name WHERE $key_col_name=?;};
    my $sth = prep_n_execute($dbh, $statement, $key_col_val);
    $sth->finish;
}


# ---------------------------------------------------------------------

=item insert_new_row

Description

=cut

# ---------------------------------------------------------------------
sub insert_new_row
{
    my ($dbh, $table_name, $row_hashref) = @_;

    # get column names and join them in a comma delimited string
    my @col_names = keys(%$row_hashref);
    my $col_names_str = join qq{,}, @col_names;

    # get row values and join them in a comma delimited string, making
    # sure that they are in the same order as column names.
    my @col_vals;
    my @col_params;
    foreach my $col_name (@col_names)
    {
        push @col_vals, "?";
        push @col_params, $$row_hashref{$col_name};
    }

    my $col_vals_str = join(qq{, }, @col_vals);

    my $statement = qq{INSERT INTO $table_name ($col_names_str) VALUES($col_vals_str);};
    my $sth = prep_n_execute($dbh, $statement, @col_params);
    $sth->finish;
}



# ---------------------------------------------------------------------

=item insert_one_or_more_rows

 Insert one or more new rows into a table..
         1) ($dbh) DBI database handle.
                2) ($table_name) name of table to use.
                3) ($colNamesArrayRef) a ref to an array of column names.
                4) ($rowsArrayRef) a ref to an array of array refs
NOTES         Inserts multiple rows. Be careful to provide a value
                     for each column name.
                Columns with auto_entered data should generally
                not be included. The database will handle them.


=cut

# ---------------------------------------------------------------------
sub insert_one_or_more_rows
{
    my ($dbh, $table_name, $col_names_array_ref, $rows_array_ref, $method) = (@_);

    $method = $method || 'insert';

    ASSERT($method =~ m/^(insert|replace)$/i, qq{unknown method $method.});
    ASSERT($col_names_array_ref, qq{insert_one_or_more_rows lacks array of col names.});
    ASSERT($rows_array_ref, qq{insert_one_or_more_rows lacks array of rows.});

    my $col_names_str = qq{\`} . join (qq{\`\, \`}, @$col_names_array_ref) . qq{\`};
    my @array_of_row_strings;
    my @array_of_row_params;

    foreach my $one_row_array_ref (@$rows_array_ref)
    {
	my $one_row_str;
	my @one_row_vals;
	my @one_row_params;
	my $c = 0;

	foreach my $colname (@$col_names_array_ref)
	{
	    push @one_row_vals, '?';
	    push @one_row_params, $$one_row_array_ref[$c];
	    # push @one_row_quoted, quote($dbh, $$one_row_array_ref[$c]);
	    $c++;
	}
	$one_row_str = join(qq{\, }, @one_row_vals);
	push (@array_of_row_strings, $one_row_str);
	push (@array_of_row_params, @one_row_params);
    }

    my $all_rows_string = join qq{\)\, \(}, @array_of_row_strings;

    my $statement = qq{$method INTO $table_name \($col_names_str\) VALUES \($all_rows_string\)\;};
    my $sth = prep_n_execute($dbh, $statement, @array_of_row_params);
    $sth->finish;
}


# ---------------------------------------------------------------------

=item quote

Description

=cut

# ---------------------------------------------------------------------
sub quote
{
    my ($dbh, $string) = @_;

    my $quoted = $dbh->quote($string);
    return $quoted;
}

sub _log_message
{
    my ( $start, $statement, $params) = @_;

    my $C = new Context;

    # if there's no config, DO NOT LOG
    my $config = ref($C) ? $C->get_object('MdpConfig', 1) : undef;
    unless ( $config ) {
        return;
    }

    my $auth = ref($C) ? $C->get_object('Auth', 1) : undef;    

    $statement =~ s,\s+, ,gsm;
    my $s = join('|',
        Utils::Time::iso_Time(),
        "delta=" . ( Time::HiRes::time() - $start ),
        "userid=" . ( ref($auth) ? $auth->get_user_name($C) : '-' ),
        "cgi=" . (defined $ENV{SCRIPT_URL} ? $ENV{SCRIPT_URL} : '-'),
        "statement=" . $statement,
        "params=" . join(' / ', @$params),
    );

    # see lament in Auth::Logging
    my $pattern = qr(slip/run-___RUN___|___QUERY___);
    Utils::Logger::__Log_string($C, $s, q{db_statement_logfile}, $pattern, 'db');
}

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
