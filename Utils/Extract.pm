package Utils::Extract;


=head1 NAME

Utils::Extract

=head1 DESCRIPTION

This package contains code to extract a file from a zip archive for
MBooks indexing and pageturner viewing.

=head1 VERSION

$Id: Extract.pm,v 1.29 2010/04/07 16:33:51 pfarber Exp $

=head1 SYNOPSIS

Coding example

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
use Identifier;
use Debug::DUtils;

# Perl
use Cwd;

END {
    __handle_EndBlock_cleanup();
}

# Handle > 2G zips
my $UNZIP_PROG = "/l/local/bin/unzip";

# ---------------------------------------------------------------------

=item __handle_EndBlock_cleanup

Description

=cut

# ---------------------------------------------------------------------
sub __handle_EndBlock_cleanup {
    my $pid = $$;
    my $expired = 120; # seconds

    # regexp must match template in get_formatted_path()
    if (opendir(DIR, '/ram')) {
        my @targets = grep(! /(^\.$|^\.\.$)/, readdir(DIR));
        my @rm_pid_targets = grep(/.*?_${pid}__.*/, @targets);
        foreach my $sd (@rm_pid_targets) {
            system("rm -rf /ram/$sd");
        }

        my $now = time();
        foreach my $sd (@targets) {
            my ($created) = ($sd =~ m,.*?__(\d+)_.*,);
            if (($now - $created) > $expired) {
                system("rm -rf /ram/$sd");
            }
        }
    }
    closedir(DIR);
}


# ---------------------------------------------------------------------

=item get_formatted_path

Use a template to generate file and directory paths that contain the
pid and unix time as components.  Template is used to manage
cache. This cache is highly volatile and is cleaned in the END block
of this module. As such, there will never be a non-unique combination
of pid and time.  The perl TMPDIR function with CLEANUP =>1 was
inexplicably leaving directories behind hence this code.

template: prefix_PID__TIME_suffix

=cut

# ---------------------------------------------------------------------
sub get_formatted_path {
    my ($prefix, $suffix) = @_;

    ASSERT(($prefix !~ m,_,), qq{ERROR: prefix contains '_' character});
    my $path = $prefix . qq{_$$} . q{__} . time() . qq{_$suffix};
    return $path;
}

# ---------------------------------------------------------------------

=item __get_tmpdir

Create a quasi-unique directory using a pattern. Test for existence.
Client code could call this in a tight loop within the same one second
time interval so share the dir if it exists.

=cut

# ---------------------------------------------------------------------
sub __get_tmpdir {
    my $pairtree_form_id = shift;

    my $input_cache_dir = get_formatted_path("/ram/$pairtree_form_id", undef);
    if (! -e $input_cache_dir) {
        my $rc = mkdir($input_cache_dir);
        ASSERT($rc, qq{Failed to create dir=$input_cache_dir rc=$rc errno=$!});
    }

    return $input_cache_dir;
}

# ---------------------------------------------------------------------

=item extract_file_to_temp_cache

Description

=cut

# ---------------------------------------------------------------------
sub extract_file_to_temp_cache {
    my $id = shift;
    my $file_sys_location = shift;
    my $filename = shift;

    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($id);
    my $input_cache_dir = __get_tmpdir($stripped_pairtree_id);
    my $cwd = cwd();

    chdir $input_cache_dir;

    my $zip_file = $file_sys_location . qq{/$stripped_pairtree_id.zip};

    # -j: just filenames, not full paths, -qq: very quiet
    system("$UNZIP_PROG", "-j", "-qq", $zip_file, "$stripped_pairtree_id/$filename");
    chdir $cwd;

    DEBUG('doc', qq{UNZIP: $UNZIP_PROG -j -qq $zip_file $stripped_pairtree_id/$filename});
    return
        (-e qq{$input_cache_dir/$filename})
            ? qq{$input_cache_dir/$filename}
                : undef;
}


# ---------------------------------------------------------------------

=item extract_dir_to_temp_cache

Description

=cut

# ---------------------------------------------------------------------
sub extract_dir_to_temp_cache {
    my $id = shift;
    my $file_sys_location = shift;
    my $patterns_arr_ref = shift;

    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($id);
    my $input_cache_dir = __get_tmpdir($stripped_pairtree_id);
    my $cwd = cwd();

    chdir $input_cache_dir;

    my $zip_file = $file_sys_location . qq{/$stripped_pairtree_id.zip};

    # -j: just filenames, not full paths, -qq: very quiet
    system("$UNZIP_PROG", "-j", "-qq", $zip_file, @$patterns_arr_ref);
    chdir $cwd;

    DEBUG('doc', qq{UNZIP: $UNZIP_PROG -j -qq $zip_file } . join(' ', @$patterns_arr_ref));

    return $input_cache_dir;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008-10 ©, The Regents of The University of Michigan, All Rights Reserved

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
