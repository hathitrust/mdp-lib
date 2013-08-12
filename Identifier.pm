package Identifier;


=head1 NAME

Identifier (id)

=head1 DESCRIPTION

This class provides identifier and namespace handling for MDP
identifiers (IDs).

=head1 SYNOPSIS

 if (Identifier::validate_mbooks_id($cgi))
 {
    do_stuff;
 }
 else
 {
    crap_out;
 }

=head1 METHODS

=over 8

=cut

use strict;

use Utils;
use Debug::DUtils;
use File::Pairtree;
use Context;
use Database;
use DbUtils;

# New short ID mapping scheme 1[g]-19[g] correspond to rights
# attributes 1-19.  A 'g' suffix means Google-sourced, otherwise
# non-Google sourced. Fully alpha ids select an ID from the indicated
# namespace.
my %g_default_debug_ids =
  (
   '1'     => 'pur1.32754063106516',
   '1g'    => 'mdp.39015000272388',
   '2'     => 'mdp.39015007162160',
   '2g'    => 'inu.30000000106090',
   '3'     => 'mdp.39015005761732',
   '3g'    => 'mdp.39015008422266',
   '4'     => '0',
   '4g'    => '0',
   '5'     => 'mdp.39015022393097',
   '5g'    => 'inu.30000003148040',
   '6'     => '0',
   '6g'    => '0',
   '7'     => 'mdp.39015001787368',
   '7g'    => 'inu.32000003311323',
   '8'     => 'miun.aql8896.0001.001',
   '8g'    => 'mdp.39015000308703',
   '9'     => 'mdp.39015000630403',
   '9g'    => 'inu.30000000209332',
   '10'    => 'mdp.39015088004018',
   '10g'   => 'inu.30000041642848',
   '11'    => '0',
   '11g'   => 'coo.31924052765348',
   '12'    => 'usu.39060016612839',
   '12g'   => 'mdp.39015001981979',
   '13'    => 'mdp.39015062008340',
   '13g'   => 'mdp.39015000000623',
   '14'    => 'uiuo.ark:/13960/t7pn9188r',
   '14g'   => 'inu.30000011561242',
   '15'    => '0',
   '15g'   => 'inu.39000000843933',
   '16'    => '0',
   '16g'   => '0',
   '17'    => 'loc.ark:/13960/t89g5s93h',
   '17g'   => 'mdp.39015005094613',
   '18'    => 'mdl.reflections.umn16596a',
   '18g'   => 'umn.31951d00814843v',
   '19'    => 'uc2.ark:/13960/t02z16p6s',
   '19g'   => 'mdp.39015000579790',

   'islam' => 'mdp.39015079124874',
   'mongo' => 'mdp.39015035951055',
  );

# ---------------------------------------------------------------------

=item PUBLIC: validate_mbooks_id

Set debug ID and alters the QUERY_STRING enviroment validate to be
consistent with the value in the CGI object.

=cut

# ---------------------------------------------------------------------
sub validate_mbooks_id {
    my $arg = shift;
    return __check_validation($arg);
}


# ---------------------------------------------------------------------

=item __split_id

Description

=cut

# ---------------------------------------------------------------------
sub __split_id {
    my $id = shift;

    my ($namespace) = ($id =~ m,^(.+?)\..+$,);
    my ($barcode) = ($id =~ m,^$namespace\.(.+)$,);

    return ($namespace, $barcode);
}

# ---------------------------------------------------------------------

=item PUBLIC: split_id

Remove the namspace identifier if id is being sent to a service
that does not understand it (yet).

=cut

# ---------------------------------------------------------------------
sub split_id {
    my $id = shift;

    __check_validation($id);
    my ($namespace, $barcode) = __split_id($id);

    return ($namespace, $barcode);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_id_wo_namespace

Remove the namspace identifier if id is being sent to a service
that does not understand it (yet).

=cut

# ---------------------------------------------------------------------
sub get_id_wo_namespace {
    my $id = shift;

    __check_validation($id);
    my ($namespace, $barcode) = __split_id($id);

    return $barcode;
}


# ---------------------------------------------------------------------

=item PUBLIC: get_pairtree_id_with_namespace

Pairtree process the non-namespace part of the id then prepend the
namespace separated by a dot.  This is for historical reasons to
preserve use of the existing XPAT indexes that were named in this way.

If the id was, e.g. mdp.39015073487137 the index files would be named
mdp.39015073487137.{xml,rgn,dd,init} where as if we pairtree processed
the whole id they'd be named mdp,39015073487137.{xml,rgn,dd,init}
making the exist indexes in the cache inaccessible.

=cut

# ---------------------------------------------------------------------
sub get_pairtree_id_with_namespace {
    my $id = shift;

    __check_validation($id);
    my ($namespace, $barcode) = __split_id($id);

    return qq{$namespace.} . File::Pairtree::s2ppchars($barcode);
}

# ---------------------------------------------------------------------

=item PUBLIC: get_pairtree_id_wo_namespace

Remove the namspace identifier if id is being sent to a service that
does not understand it and pairtree transform it so it can be used as
a filename component.

=cut

# ---------------------------------------------------------------------
sub get_pairtree_id_wo_namespace {
    my $id = shift;

    __check_validation($id);
    my ($namespace, $barcode) = __split_id($id);

    return File::Pairtree::s2ppchars($barcode);
}

# ---------------------------------------------------------------------

=item PUBLIC: the_namespace

Description

=cut

# ---------------------------------------------------------------------
sub the_namespace {
    my $id = shift;

    __check_validation($id);
    my ($namespace, $barcode) = __split_id($id);

    return $namespace;
}

# ---------------------------------------------------------------------

=item PUBLIC: get_item_location

Return full path to the dir that contains this id's files.  Provides
mapping for the mdp, miun and miua namespaces

=cut

# ---------------------------------------------------------------------
sub get_item_location {
    my $id = shift;

    chomp($id);
    __check_validation($id);

    my $dataroot = Utils::resolve_data_root($id);
    my $path = $dataroot . qq{/obj/} . id_to_mdp_path($id);
    chomp($path);

    return $path;
}


# ---------------------------------------------------------------------

=item PUBLIC: id_to_mdp_path

Decompose an id into the convention path to the object in the
repository (filesystem)

Changed to use File::Pairtree Wed Apr 22 13:23:39 2009

=cut

# ---------------------------------------------------------------------
sub id_to_mdp_path {
    my $id = shift;

    __check_validation($id);
    my ($namespace, $barcode) = __split_id($id);
    my $root = $namespace . q{/pairtree_root};

    # Initial pairtree module
    $File::Pairtree::root = $root;
    my $path = File::Pairtree::id2ppath($barcode) . File::Pairtree::s2ppchars($barcode);

    return $path;
}


# ---------------------------------------------------------------------

=item PRIVATE: __check_validation

Description

=cut

# ---------------------------------------------------------------------
sub __check_validation {
    my $arg = shift;

    my $id;
    my $arg_is_CGI = (ref($arg) =~ m/^CGI/);

    if ($arg_is_CGI) {
        $id = $arg->param('id');
    }
    else {
        $id = $arg;
    }

    if ($id eq 'r') {
        $id = randomize_id($id);
    }
    else {
        # Set up '1', '1g', '2', ... as easy IDs to remember
        $id = $g_default_debug_ids{$id} if (grep(/^$id$/, keys %g_default_debug_ids));
    }

    silent_ASSERT(defined $id, 'id not defined');

    # Set id on the cgi and QUERY_STRING
    __set_id_globally($id, $arg) if ($arg_is_CGI);

    return $id;
}

# ---------------------------------------------------------------------

=item PRIVATE: __set_id_globally

Description

=cut

# ---------------------------------------------------------------------
sub __set_id_globally {
    my $id = shift;
    my $cgi = shift;

    my $query_string;
    $query_string = $cgi->query_string();
    $query_string =~ s,id=.+?[\;\&]?,,g;
    $cgi->param('id', $id);
    $query_string = qq{id=$id;} . $query_string;
    $ENV{'QUERY_STRING'} = $query_string;
}


# ---------------------------------------------------------------------

=item get_safe_Solr_id

Description

=cut

# ---------------------------------------------------------------------
sub get_safe_Solr_id {
    my $id = shift;

    $id =~ s,ark:,ark\\:,;
    return $id;
}

# ---------------------------------------------------------------------

=item randomize_id

If id=r replace with a random id.  Warning: SLOW on the order of 10 seconds.

=cut

# ---------------------------------------------------------------------
sub randomize_id {
    my $id = shift;

    my $C = new Context;
    my $dbh = $C->get_object('Database')->get_DBH();
    my ($statement, $sth);
    $statement = qq{SELECT count(*) FROM rights_current WHERE attr=1};
    $sth = DbUtils::prep_n_execute($dbh, $statement);
    my $count = $sth->fetchrow_array;
    my $rand_int = int(rand()*$count) + 1;
    $statement = qq{SELECT CONCAT(namespace, '.', id) FROM rights_current WHERE attr=1 LIMIT 1 OFFSET $rand_int};
    $sth = DbUtils::prep_n_execute($dbh, $statement);
    $id = $sth->fetchrow_array || $g_default_debug_ids{1};

    return $id;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-10, 2103 ©, The Regents of The University of Michigan, All Rights Reserved

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
