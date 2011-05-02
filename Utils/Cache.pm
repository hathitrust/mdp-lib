package Utils::Cache;

=head1 NAME

Utils::Cache

=head1 DESCRIPTION

Basic cache for objects; serializes Perl structures to disk 
with either Storable or JSON (see Utils::Cache::*).

You supply an ($id,$key) tuple to save/get data. $id is 
expanded to a Pairtree structure behind the scenes.

This class is not used directly; instead use either
Utils::Cache::Storable or Utils::Cache::JSON.

To mitigate the chance of collisions, data is serialized 
to a temporary file which is then moved to the appropriate
($id,$key) location under $cache_dir.


=head1 SYNOPSIS

$cache = Utils::Cache::Storable->new($cache_dir);
$cache->Set($id, $key, $data);

$data2 = $cache->Get($id, $key);

=head1 METHODS

=over 8

=cut

use File::Copy;
use Time::HiRes qw(time);

use Identifier;
use Utils::Extract;

use CGI;

use Debug::DUtils;

sub new
{
    my $class = shift;
    my $cacheDir = shift;
    my $max_cache_age = shift || 0;
    
    my $self = {};
    $self->{cacheDir} = $cacheDir . "/";
    Utils::mkdir_path( $cacheDir, undef );
    
    $self->{max_cache_age} = $max_cache_age;
    
    bless $self, $class;
    return $self;
}

# ---------------------------------------------------------------------

=item Set($id,$key,$value)

Serializes $value to the filesystem.

=cut

# ---------------------------------------------------------------------
sub Set
{
    my $self = shift;
    my ( $id, $key, $value, $force ) = @_;
    my $keyFileName = $self->BuildKeyFileName($id, $key);

    # serialize data to a temporary file as a cheap way of 
    # avoiding file collisions.
    my $tmpfilename = $self->GenerateTemporaryFilename($id, $key);
    $self->serialize($value, $tmpfilename);
    
    my $save_cache = ! $self->file_exists_n_newer($id, $keyFileName);

    if ( $save_cache || $force ) {
        for( my $try = 0; $try < 3; $try++ ) {
            my $retval = move($tmpfilename, $keyFileName);
            DEBUG('pt,mdpitem,cache', qq{<h3>Cache->Set: move $retval :: $try</h3>});
            last if ( $retval );
        }
    }
    
    if ( -f $tmpfilename ) {
        # $tmpfilename couldn't be moved so we punt and return this filename
        # to the caller.
        DEBUG('pt,mdpitem,cache', qq{<h3>Set: using $tmpfilename</h3>});
        $keyFileName = $tmpfilename;
    }
    
    return $keyFileName;
}

# ---------------------------------------------------------------------

=item Get($id,$key)

If ($id,$key) is found in $cache_dir, the file contents are
"instantiated".

Otherwise, undef is returned.

Checks to see if there's a newer $id in the repository; treats
($id,$key) as empty if true.

=cut

# ---------------------------------------------------------------------
sub Get
{
    my $self = shift;
    my $id = shift;
    my $key = shift;
    
    my $keyFileName = $self->BuildKeyFileName($id, $key);
    
    if ( $self->file_exists_n_newer($id, $keyFileName) ) {
        return $self->instantiate($keyFileName);
    }
    
    return undef;
}

# ---------------------------------------------------------------------

=item GetFile($id,$key)

Return the path to ($id,$key) in $cache_dir, if it exists.

Otherwise, undef is returned.

This allows JSON structures to be cached and then streamed
by applications without re-constituting the data.

Checks to see if there's a newer $id in the repository; treats
($id,$key) as empty if true.

=cut

# ---------------------------------------------------------------------
sub GetFile
{
    my $self = shift;
    my $id = shift;
    my $key = shift;

    my $keyFileName = $self->BuildKeyFileName($id, $key);
    if ( $self->file_exists_n_newer($id, $keyFileName) ) {
        return $keyFileName;
    }

    return undef;
}

sub GenerateTemporaryFilename
{
    my $self = shift;
    my $id = shift;
    my $outputFileType = shift || 'dat';
    
    my $base = Identifier::get_pairtree_id_with_namespace($id);
    return Utils::Extract::__get_tmpdir($base) . "/${$}__" . time() . ".$outputFileType";
    
}

sub BuildKeyFileName
{
    my $self = shift;
    my $id   = shift;
    my $key  = shift;
    my $escaped_key = CGI::escape($key);
    
    my $keydir = $self->{cacheDir} . Identifier::id_to_mdp_path($id);
    Utils::mkdir_path( $keydir, undef );
    
    return $keydir . "/$escaped_key" . $self->suffix();
    
}

sub ASSERT
{
    my $self=shift;
    my ($condition, $message) = (@_);

    if ( ! $condition )
    {
        $condition = "" unless ( defined($condition) );
        die (qq{ASSERTION FAILURE:\n$message\n$condition\n});
    }
}

sub suffix {
    my $self = shift;
    return '.bin';
}

# ---------------------------------------------------------------------

=item file_exists_n_newer

Check existence of web derivative and that its mtime is newer that
mtime of zip file it was derived from.  Assumes all archival files are
in zip files. That should now be the case.

=cut

# ---------------------------------------------------------------------
sub file_exists_n_newer {
    my $self = shift;
    my $id = shift;
    my $derivative = shift;
    

    my $exists_n_newer = 0;
    my $max_cache_age = $$self{max_cache_age};
    
    if (Utils::file_exists($derivative)) {

        my $der_mtime = (stat($derivative))[9];

        # ensure that $derivative is no older than $delta seconds
        if ( $max_cache_age > 0 && ( time() - $der_mtime > $max_cache_age ) ) {
            DEBUG('pt,mdpitem,cache', qq{<h3>file_exists_n_newer: } . time() . qq{ - $der_mtime > $max_cache_age</h3>});
            return 0;
        }

        my $itemFileSystemLocation = Identifier::get_item_location($id);
        my $barcode = Identifier::get_id_wo_namespace($id);
        my $zipfile = qq{$itemFileSystemLocation/$barcode.zip};
        

        my $zip_mtime = (stat($zipfile))[9];

        if ($der_mtime > $zip_mtime) {
            $exists_n_newer = 1;
        }

        DEBUG('pt,mdpitem,cache', qq{<h3>file_exists_n_newer: der_mtime [$der_mtime] zip_mtime [$zip_mtime] = $exists_n_newer</h3>});
        
    }

    return $exists_n_newer;
}

1;
