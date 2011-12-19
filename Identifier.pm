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

my %g_default_debug_ids =
    (
     # Internal library id results from a bug in a screen-scraper script
     '0' => {
            },
     # no page metadata testing. monograph
     '1' => {
             'id'  => 'mdp.39015015394847',
            },
     # Internet Archive source=4, public-domain, attr=9
     '2' => {
             'id'  => 'uc2.ark:/13960/t0dv1g69b',
            },
     # MIUN namespace, should go to title page
     '3' => {
             'id'  => 'miun.aas8778.0001.001',
            },
     # Serial (volume data), turncated title, no page metadata,
     # accented Latin characters
     '4' => {
             'id'  => 'mdp.39015062775989',
            },
     # size testing 1.2G, 1469 pages
     '5' => {
             'id'  => 'mdp.39015035951055',
            },
     # UM Press volume, public-domain attr=7
     '6' => {
             'id'  => 'mdp.39015009120471',
            },
     # HathiTrust pfarber ssd volume public-domain
     '7' => {
             'id'  => 'mdp.39015069378902',
            },
     # HathiTrust pfarber ssd volume in-copyright
     '8' => {
             'id'  => 'mdp.39015026496847',
            },
     # OPB attr=3
     '9' => {
             'id'  => 'mdp.39015004314111',
            },
     # pd, selected from reduced repository for HT dev environment
     '10' => {
             'id'  => 'mdp.39015051323379',
             },
     # Islamic MSS, all OCR is zero length
     '11' => {
             'id'  => 'mdp.39015079124874',
             },
     # CC Creative Commons Attribution-NonCommercial-ShareAlike
     '12' => {
             'id'  => 'mdp.39015015823563',
             },
     # pdus
     '13' => {
              'id'  => 'inu.30000000123830',
             },
    );

# ---------------------------------------------------------------------

=item PUBLIC: validate_mbooks_id

Set debug ID and alters the QUERY_STRING enviroment validate to be
consistent with the value in the CGI object.

=cut

# ---------------------------------------------------------------------
sub validate_mbooks_id {
    my $arg = shift;

    my $candidate_id;
    if (ref($arg) =~ m/^CGI/) {
        $candidate_id = $arg->param('id');
    }
    else {
        $candidate_id = $arg;
    }

    # Set a known well-formed id on the cgi for debugging
    my $id = __set_debug_id($candidate_id);

    # Set id on the cgi and QUERY_STRING
    __set_id_globally($id, $arg);
    
    return $id;
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
    my $namespace = the_namespace($id);
    $id  =~ s,^$namespace\.,,;

    return $id;
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
    my $namespace = the_namespace($id);
    $id =~ s,^$namespace\.,,;

    return qq{$namespace.} . File::Pairtree::s2ppchars($id);
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
    my $namespace = the_namespace($id);
    $id =~ s,^$namespace\.,,;

    return File::Pairtree::s2ppchars($id);
}

# ---------------------------------------------------------------------

=item PUBLIC: the_namespace

Description

=cut

# ---------------------------------------------------------------------
sub the_namespace {
    my $id = shift;

    __check_validation($id);
    my ($namespace) = ($id =~ m,^(.+?)\..+$,);

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

    my $dataroot = Utils::resolve_data_root();
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
    my $namespace = the_namespace($id);
    my $root = $namespace . q{/pairtree_root};

    # Initial pairtree module
    $File::Pairtree::root = $root;

    my $barcode = get_id_wo_namespace($id);
    my $path = File::Pairtree::id2ppath($barcode) . File::Pairtree::s2ppchars($barcode);

    return $path;
}


# ---------------------------------------------------------------------

=item PRIVATE: __check_validation

Description

=cut

# ---------------------------------------------------------------------
sub __check_validation {
    my $id = shift;
    ASSERT(validate_mbooks_id($id), qq{Invalid id="$id"});
}

# ---------------------------------------------------------------------

=item PRIVATE: __set_debug_id

Description

=cut

# ---------------------------------------------------------------------
sub __set_debug_id {
    my $id = shift;

    # Set up '1', '2', ... as easy IDs to remember
    if (grep(/^$id$/, keys %g_default_debug_ids)) {
        silent_ASSERT(($id ne '0'), qq{Bogus debug id: 0});
        return $g_default_debug_ids{$id}{'id'};
    }
    return $id;
}


# ---------------------------------------------------------------------

=item PRIVATE: __set_id_globally

Description

=cut

# ---------------------------------------------------------------------
sub __set_id_globally {
    my $id = shift;
    my $arg = shift;

    my $QUERY_STRING;
    if (ref($arg) =~ m/^CGI/) {
        $QUERY_STRING = $arg->query_string();
        $QUERY_STRING =~ s,id=.+?[\;\&]?,,g;
        $arg->param('id', $id);
        $QUERY_STRING = qq{id=$id;} . $QUERY_STRING;
        $ENV{'QUERY_STRING'} = $QUERY_STRING;
    }
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
    my $C = shift;
    my $cgi = shift;
    
    if ($cgi->param('id') eq 'r') {
        my $dbh = $C->get_object('Database')->get_DBH();
        my $statement = qq{SELECT CONCAT(namespace, '.', id) FROM small ORDER BY RAND() LIMIT 0,1};
        my $sth = DbUtils::prep_n_execute($dbh, $statement);
        my $random_id = $sth->fetchrow_array;
        if ($random_id) {
            $cgi->param('id', $random_id);
        }
        else {
            $cgi->param('id', 'mdp.39015015394847');
        }
    }
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007-10 ©, The Regents of The University of Michigan, All Rights Reserved

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
