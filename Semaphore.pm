package Semaphore;


=head1 NAME

Semaphore;

=head1 DESCRIPTION

This class provides semaphore file functionality allowing the
instantiator to acquire an exclusive lock on a semaphore file.

=head1 VERSION

$Id: Semaphore.pm,v 1.3 2008/04/24 17:21:42 pfarber Exp $

=head1 SYNOPSIS

use Sem;
my $sem = new Semaphore('/wherever/locks/thing.lock');
if ($sem)
{
    # enjoy exclusive access to a resource ...
    $sem->unlock;
}
else
{
  # try again later ...
  exit;
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

use Fcntl qw(:flock);
use IO::Handle;

# ---------------------------------------------------------------------

=item new

Obtain an exclusive lock in a file in a non-blocking mode.  Failure to
obtain the lock means some other process has the lock. Making th efile
handle local means that when the process exits, even it it fails to
call unlock due to runtime error, the lock will be released.

=cut

# ---------------------------------------------------------------------
sub new
{
    my $class = shift;
    my $file_spec = shift || die qq{filename missing in new Semaphore};

    open my $fh, ">", $file_spec || die qq{open failed on semaphore file="$file_spec": $!};
    chmod 0666, $file_spec;

    if (flock($fh, LOCK_EX|LOCK_NB))
    {
	$fh->autoflush(1);
        print($fh $$);

        my $self = {
                    'fh' => $fh, 
                    'file_spec' => $file_spec,
                   };
        bless $self, $class;
        return $self;
    }

    return undef;
}

# ---------------------------------------------------------------------

=item unlock

Release the lock, delete the file

=cut

# ---------------------------------------------------------------------
sub unlock 
{
    my $self = shift;
    
    close(delete $self->{'fh'}) 
        || return 0;

    # NOT atomic but if another process has aquired the lock here the
    # unlink will fail which is ok

    unlink( $self->{'file_spec'} );
            
    return 1;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008 ©, The Regents of The University of Michigan, All Rights Reserved

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
