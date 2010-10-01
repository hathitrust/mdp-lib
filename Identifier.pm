package Identifier;


=head1 NAME

Identifier (id)

=head1 DESCRIPTION

This class provides identifier and namespace handling for MDP
identifiers (IDs).  

=head1 VERSION

$Id: Identifier.pm,v 1.46 2010/04/30 20:20:26 pfarber Exp $

=head1 SYNOPSIS

 if (Identifier::validate_mbooks_id($cgi))
 {
    do stuff;
 }
 else
 {
    crap out;
 }

=head1 METHODS

=over 8

=cut

BEGIN
{
    if ($ENV{'HT_DEV'})
    {
        require "strict.pm";
        strict::import();
    }
}

use Utils;
use Debug::DUtils;
use File::Pairtree;

# ----------------------------------------------------------
# Package variables
# ----------------------------------------------------------

# At some point all IDs must have namespace prefixes (we hope)
my %g_namespace_data =
    (
     'mdp'              => {'regexp'    => '^mdp\.39015\d{9}$',
                            'namespace' => 'mdp', },
     'mdp_flint'        => {'regexp'    => '^mdp\.49015\d{9}$',
                            'namespace' => 'mdp', },
     'miu_notis'        => {'regexp'    => '^miun\..+$',
                            'namespace' => 'miun', },
     'miu_aleph'        => {'regexp'    => '^miua\..+',
                            'namespace' => 'miua', },
     'wu'               => {'regexp'    => '^wu\..+$',
                            'namespace' => 'wu', },
     'inu'              => {'regexp'    => '^inu\.\d+$',
                            'namespace' => 'inu', },
     'uc1'              => {'regexp'    => '^uc1\..+$',
                            'namespace' => 'uc1', },
     'uc2'              => {'regexp'    => '^uc2\..+$',
                            'namespace' => 'uc2', },
     'pst'              => {'regexp'    => '^pst\..+$',
                            'namespace' => 'pst', },
     'umn'              => {'regexp'    => '^umn\..+$',
                            'namespace' => 'umn', },
     'chi'              => {'regexp'    => '^chi\..+$',
                            'namespace' => 'chi', },
     'nnc1'             => {'regexp'    => '^nnc1\..+$',
                            'namespace' => 'nnc1', }, 
     'nnc2'             => {'regexp'    => '^nnc2\..+$',
                            'namespace' => 'nnc2', },
     'nyp'              => {'regexp'    => '^nyp\..+$',
                            'namespace' => 'nyp', },
     'yale'             => {'regexp'    => '^yale\..+$',
                            'namespace' => 'yale', },
     'njp'              => {'regexp'    => '^njp\..+$',
                            'namespace' => 'njp', },
     'uiuo'             => {'regexp'    => '^uiuo\..+$',
                            'namespace' => 'uiuo', },
    );

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
    );


# ----------------------------------------------------------
# Protected Class member data
# ----------------------------------------------------------
my $g_THE_ID = '';
my $g_THE_ID_TYPE = '';
my $g_NAMESPACE = '';

# ---------------------------------------------------------------------

=item PUBLIC: validate_mbooks_id

Ensures that a putative ID adheres to the MDP identifier scheme. At
least as much as it is possibe to make this determination.  NOTIS IDs
are loose.

This needs to be called early in **EVERY** program to ensure that IDs
within programs are fully qualified with namespaces.

Later, if they leave the program each special case should be handled
as a function of destination.

Also alters the QUERY_STRING enviroment validate to be consistent with
the value in the CGI object.

=cut

# ---------------------------------------------------------------------
sub validate_mbooks_id
{
    my $arg = shift;

    my $candidate_id;
    if (ref($arg) eq 'CGI')
    {
        $candidate_id = $arg->param('id');
    }
    else
    {
        $candidate_id = $arg;
    }
    silent_ASSERT(defined($candidate_id), qq{id parameter not supplied});
    
    # Set a known well-formed id on the cgi for debugging
    my $id = __set_debug_id($candidate_id);

    # Has this cgi already been validated?
    return $id if ($id eq $g_THE_ID);

    # Record the type of the incoming id if it matches the known types
    return 0 if (! __set_id_types($id));

    # Set id on the cgi and QUERY_STRING based on type
    __set_id_globally($id, $arg);

    return $id;
}



# ---------------------------------------------------------------------

=item PUBLIC: get_id_wo_namespace

Remove the namspace identifier if id is being sent to a service
that does not understand it (yet).

=cut

# ---------------------------------------------------------------------
sub get_id_wo_namespace
{
    my $id = shift;

   # Maybe initialize Identifier if id has not been validated yet.
    __check_validation($id);
    
    $id  =~ s,^$g_NAMESPACE\.,,;
    chomp($id);
    
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

   # Maybe initialize Identifier if id has not been validated yet.
    __check_validation($id);
    
    $id  =~ s,^$g_NAMESPACE\.,,;
    chomp($id);
    
    return qq{$g_NAMESPACE.} . s2ppchars($id);
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

   # Maybe initialize Identifier if id has not been validated yet.
    __check_validation($id);
    
    $id  =~ s,^$g_NAMESPACE\.,,;
    chomp($id);
    
    return s2ppchars($id);
}

# ---------------------------------------------------------------------

=item PUBLIC: the_namespace

Description

=cut

# ---------------------------------------------------------------------
sub the_namespace
{
    my $id = shift;

    # Maybe initialize Identifier if id has not been validated yet.
    __check_validation($id);
    
    return $g_NAMESPACE;
}

# ---------------------------------------------------------------------

=item PUBLIC: get_item_location

Return full path to the dir that contains this id's files.  Provides
mapping for the mdp, miun and miua namespaces 

=cut

# ---------------------------------------------------------------------
sub get_item_location
{
    my $id = shift;

    # Maybe initialize Identifier if id has not been validated yet.
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
sub id_to_mdp_path
{
    my $id = shift;

    __check_validation($id);

    my $namespace = the_namespace($id);
    my $root = $namespace . q{/pairtree_root};
    
    # Initial pairtree module
    $File::Pairtree::root = $root;

    my $barcode = get_id_wo_namespace($id);
    my $path = id2ppath($barcode) . s2ppchars($barcode);

    return $path;
}


# ---------------------------------------------------------------------

=item PRIVATE: __check_validation

Description

=cut

# ---------------------------------------------------------------------
sub __check_validation
{
    my $id = shift;
    
    # Maybe initialize Identifier if id has not been validated yet.
    if (! (($id eq $g_THE_ID) && $g_THE_ID_TYPE && $g_NAMESPACE))
    {
        ASSERT(validate_mbooks_id($id), qq{Invalid id="$id"});
    }
}

# ---------------------------------------------------------------------

=item PRIVATE: __set_debug_id

Description

=cut

# ---------------------------------------------------------------------
sub __set_debug_id
{
    my $id = shift;

    # Set up '1', '2', ... as easy IDs to remember
    if (grep(/^$id$/, keys %g_default_debug_ids)) {
        silent_ASSERT(($id ne '0'), qq{Bogus debug id: 0});
        return $g_default_debug_ids{$id}{'id'};
    }
    return $id;
}


# ---------------------------------------------------------------------

=item PRIVATE: __set_id_types

Description

=cut

# ---------------------------------------------------------------------
sub __set_id_types
{
    my $id = shift;

    foreach my $prefix_type (keys %g_namespace_data)
    {
        my $RE = $g_namespace_data{$prefix_type}{'regexp'};
        my $comp_RE = qr/$RE/; # compile the prefix pattern regexp
        if ($id =~ m,$comp_RE,i)
        {
            $g_THE_ID_TYPE = $prefix_type;
            $g_NAMESPACE = $g_namespace_data{$prefix_type}{'namespace'};
            return 1;
        }

    }
    return 0;
}


# ---------------------------------------------------------------------

=item PRIVATE: __set_id_globally

Description

=cut

# ---------------------------------------------------------------------
sub __set_id_globally
{
    my $id = shift;
    my $arg = shift;

    my $QUERY_STRING;
    if (ref($arg) eq 'CGI')
    {
        $QUERY_STRING = $arg->query_string();
        $QUERY_STRING =~ s,id=$id[;&]?,,g;
    }

    $g_THE_ID = $id;

    if (ref($arg) eq 'CGI')
    {
        $arg->param('id', $id);
        $QUERY_STRING = qq{id=$id;} . $QUERY_STRING;
        $ENV{'QUERY_STRING'} = $QUERY_STRING;
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
