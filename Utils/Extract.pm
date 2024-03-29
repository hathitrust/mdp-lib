package Utils::Extract;

=head1 NAME

Utils::Extract

=head1 DESCRIPTION

This package contains code to extract a file from a zip archive for
MBooks indexing and pageturner viewing.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

use strict;

use Utils;
use Utils::Logger;
use Identifier;
use Debug::DUtils;
use Utils::Logger;

# Perl
use IPC::Run;
use Time::HiRes qw();
use File::Basename qw(basename dirname);

END {
    __handle_EndBlock_cleanup();
}

# Handle > 2G zips
my $UNZIP_PROG = "/usr/bin/unzip";

# zip return codes
use constant NO_ERRORS => 0;
use constant NO_ERRORS_CAUTION_WARNING => 1;
use constant NO_ERRORS_NO_MATCHING_FILES => 11;

my $time0;

# ---------------------------------------------------------------------

=item __get_df_report

Description

=cut

# ---------------------------------------------------------------------
sub __get_df_report {
    my $mount = shift;
    return "\n" . `df -i $mount` . "\n" . `df -a $mount`;
}

# ---------------------------------------------------------------------

=item __handle_EndBlock_cleanup

Description

=cut

# ---------------------------------------------------------------------
sub __handle_EndBlock_cleanup {
    cleanup();
}

# ---------------------------------------------------------------------

=item cleanup

Description

=cut

# ---------------------------------------------------------------------
sub cleanup {
    my $pid = $$;
    my $suffix = shift;
    my $expired = 300; # seconds

    # quiet the logs
    local (*OUT, *ERR);
    open OUT, ">&STDOUT";
    open ERR, ">&STDERR";
    close STDOUT;
    close STDERR;

    # regexp must match template in get_formatted_path()
    my $tmp_root = __get_root();
    if (opendir(DIR, $tmp_root)) {
        my @targets = grep(! /(^\.$|^\.\.$)/, readdir(DIR));
        my $pattern = qr{.*?-_-1-_-${pid}-_-2-_-.*};
        if ( $suffix ) { $pattern = qr{.*?-_-1-_-${pid}-_-2-_-[0-9]+-_-${suffix}} }
        my @rm_pid_targets = grep(/$pattern/, @targets);
        # remove the temp files created by this pid
        foreach my $sd (@rm_pid_targets) {
            system("rm", "-rf", "$tmp_root/$sd");
        }

        # remove expired temp files not cleaned up by failed pids
        my $now = time();
        foreach my $sd (@targets) {
            my ($created) = ($sd =~ m,.*?-_-2-_-(\d+),);
            next unless ( $created );
            if (($now - $created) > $expired) {
                system("rm", "-rf", "$tmp_root/$sd");
            }
        }
    }
    closedir(DIR);

    open STDOUT, ">&OUT";
    open STDERR, ">&ERR";
}

# ---------------------------------------------------------------------

=item get_formatted_path

Use a template to generate file and directory paths that contain the
pid and unix time as components.  Template is used to manage
cache. This cache is highly volatile and is cleaned in the END block
of this module. As such, there will never be a non-unique combination
of pid and time.  The perl TMPDIR function with CLEANUP =>1 was
inexplicably leaving directories behind hence this code.

template: prefix-_-1-_-PID-_-2-_-TIME-_-suffix

=cut

# ---------------------------------------------------------------------
sub get_formatted_path {
    my ($prefix, $suffix, $delta) = @_;

    $delta = 0 || $delta;
    $suffix = $suffix ? qq{-_-$suffix} : '';

    ASSERT(($prefix !~ m,-_-[12]-_-,), qq{ERROR: prefix contains '-_-[12]-_-' characters } . __get_df_report('/ram'));
    my $path = $prefix . qq{-_-1-_-$$} . q{-_-2-_-} . (time() + $delta) . $suffix;
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
    my $suffix = shift;
    my $delta = shift || 0;

    my $tmp_root = __get_root();
    my $input_cache_dir = get_formatted_path("$tmp_root/$pairtree_form_id", $suffix, $delta);
    if (! -e $input_cache_dir) {
        my $rc = mkdir($input_cache_dir);
        ASSERT($rc, qq{Failed to create dir=$input_cache_dir rc=$rc errno=$! } . __get_df_report('/ram'));
    }

    return $input_cache_dir;
}

sub __get_root {
    my $tmp_root = defined($ENV{'RAMDIR'}) ? $ENV{'RAMDIR'} : "/ram";
    return $tmp_root;
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
    my $suffix = shift;
    my $input_cache_dir = shift;

    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($id);
    my $zip_file = $file_sys_location . qq{/$stripped_pairtree_id.zip};
    $input_cache_dir = __get_tmpdir($stripped_pairtree_id, $suffix) unless ( $input_cache_dir );

    my @unzip;
    push @unzip, $UNZIP_PROG, "-j", "-qq", "-d", $input_cache_dir, $zip_file, "$stripped_pairtree_id/$filename";

    __run($id, \@unzip, "$input_cache_dir/$filename");

    return
      (-e qq{$input_cache_dir/$filename})
        ? qq{$input_cache_dir/$filename}
          : undef;
}


# ---------------------------------------------------------------------

=item extract_filelist_to_temp_cache

Description

=cut

# ---------------------------------------------------------------------
sub extract_filelist_to_temp_cache {
    my $id = shift;
    my $file_sys_location = shift;
    my $filelist_arr_ref = shift;
    my $suffix = shift;

    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($id);
    my $zip_file = $file_sys_location . qq{/$stripped_pairtree_id.zip};
    my $input_cache_dir = __get_tmpdir($stripped_pairtree_id, $suffix);
    my $error_file = Utils::get_tmp_logdir() . '/extract-error';

    my @filenames = map{ "$stripped_pairtree_id/$_" } @$filelist_arr_ref;

    my @unzip;
    # -j: just filenames, not full paths, -qq: very quiet
    push @unzip, $UNZIP_PROG, "-j", "-qq", "-d", $input_cache_dir, $zip_file, @filenames;

    __run($id, \@unzip);

    return $input_cache_dir;
}

# ---------------------------------------------------------------------

=item __extract_report

Description

=cut

# ---------------------------------------------------------------------
sub __extract_report {
    my ($system_retval, $error_file, $cmd) = @_;

    chmod(0666, $error_file) if (-o $error_file);

    my $ok =
      (
       $system_retval == NO_ERRORS
       ||
       $system_retval == NO_ERRORS_CAUTION_WARNING
       ||
       $system_retval == NO_ERRORS_NO_MATCHING_FILES
      );
    unless ($ok) {
        my $t_ref = read_file($error_file, 1);
        my $msg = qq{UNZIP: code="$system_retval msg=$$t_ref  } . __get_df_report('/ram') . qq{command=$cmd};
        Utils::Logger::__Log_simple($msg);
        ASSERT(0, $msg);
    }
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
    my $exclude_patterns_arr_ref = shift;

    my $stripped_pairtree_id = Identifier::get_pairtree_id_wo_namespace($id);
    my $zip_file = $file_sys_location . qq{/$stripped_pairtree_id.zip};
    my $input_cache_dir = __get_tmpdir($stripped_pairtree_id);
    my $error_file = Utils::get_tmp_logdir() . '/extract-error';

    my @unzip;
    # -j: just filenames, not full paths, -qq: very quiet
    push @unzip, $UNZIP_PROG, "-j", "-qq", "-d", $input_cache_dir, $zip_file, @$patterns_arr_ref;

    if (defined($exclude_patterns_arr_ref)) {
        push @unzip, "-x", @$exclude_patterns_arr_ref;
    }

    __run($id, \@unzip);

    return $input_cache_dir;
}

sub __run {
    my $id = shift;
    my $unzip = shift;
    my $test_filename = shift;

    my $error_file = Utils::get_tmp_logdir() . '/extract-error';

    my @yes;
    # Pipe echo to unzip so it won't hang on a user prompt when ramdisk is full
    push @yes, "echo", "n";

    my $stderr;
    my $time0 = Time::HiRes::time();
    IPC::Run::run \@yes, '|',  $unzip, ">", "/dev/null", "2>>", \$stderr;
    my $system_retval = $? >> 8;

    my $cmd = join(' ', @$unzip);
    DEBUG('doc', qq{UNZIP: $cmd});

    if ( $test_filename ) {
        $stderr = '' unless ( $stderr );
        my $filename = basename($test_filename);
        my $input_cache_dir = dirname($test_filename);
        soft_ASSERT((-e $test_filename, 
            qq{Could not extract $filename to $input_cache_dir} . "\n" . 
            $cmd . "\n" . 
            qq{code=$system_retval} . "\n" . 
            $stderr . "\n" . 
            __get_df_report('/ram')));
    }

    __extract_report($system_retval, $error_file, $cmd);

    my $delta = Time::HiRes::time() - $time0;
    Utils::Logger::__Log_benchmark(undef, [["id", $id],["delta",$delta],["label","__run"],["cmd",$cmd]], 'extract');
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008-14 ©, The Regents of The University of Michigan, All Rights Reserved

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
