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

sub new
{
    my $class = shift;
    my $cacheDir = shift;
    
    my $self = {};
    $self->{cacheDir} = $cacheDir . "/";
    Utils::mkdir_path( $cacheDir, undef );
    
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
    my ( $id, $key, $value ) = @_;
    my $keyFileName = $self->BuildKeyFileName($id, $key);

    my $tmpfilename = $self->GenerateTemporaryFilename($id, $key);
    $self->serialize($value, $tmpfilename);

    if ( ! -s $keyFileName ) {
        # $outputFileName is still empty, so rename
        for( my $try = 0; $try < 3; $try++ ) {
            last if (move($tmpfilename, $keyFileName));
        }
    }
    
    if ( -f $tmpfilename ) {
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
    if ( $self->file_exists_n_newer($keyFileName) ) {
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
    
    if (Utils::file_exists($derivative)) {
        my $itemFileSystemLocation = Identifier::get_item_location($id);
        my $barcode = Identifier::get_id_wo_namespace($id);
        my $zipfile = qq{$itemFileSystemLocation/$barcode.zip};
        

        my $zip_mtime = (stat($zipfile))[9];
        my $der_mtime = (stat($derivative))[9];

        if ($der_mtime > $zip_mtime) {
            $exists_n_newer = 1;
        }
    }

    return $exists_n_newer;
}

1;