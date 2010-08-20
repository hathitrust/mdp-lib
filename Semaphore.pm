package Semaphore;

=head1 NAME

Semaphore;

=head1 DESCRIPTION

This class provides semaphore file functionality allowing the
instantiator to acquire an exclusive lock on a semaphore file.

=head1 SYNOPSIS

use Sem;
my $sem = new Semaphore('/wherever/locks/thing.lock');
if ($sem) {
    # enjoy exclusive access to a resource ...
    $sem->unlock;
}
else {
  # try again later ...
  exit;
}

=head1 METHODS

=over 8

=cut

use strict;
use Fcntl qw(:flock);
use IO::Handle;

# ---------------------------------------------------------------------

=item new

Obtain an exclusive lock in a file in a non-blocking mode.  Failure to
obtain the lock means some other process has the lock. Making the file
handle local means that when the process exits, even it it fails to
call unlock due to runtime error, the lock will be released.

We have seen an error under NFS where the open statement fails with
$!="Stale NFS file handle at /sdr1/lib/App/Semaphore.pm line 56."
Best guess is a race condition where process B has deleted the file
when open, running from process A, tries to access the filehandle,
leading to this error. That is, open is not atomic across NFS nodes.
The solution is to ignore the open error and return undef, allowing
the client to make another attempt.  There is evidence this approach
will "work" because, in an older version of this code, a bug caused
the die on open failure to be ignored and everything appeared to work.

=cut

# ---------------------------------------------------------------------
sub new {
    my $class = shift;
    my $file_spec = shift || die qq{filename missing in new Semaphore};
    
    die qq{file=$file_spec must be a disposable semaphore file (.sem)} 
      if ($file_spec !~ m,\.sem$,);
    
    # Linux locking using fcntl is advisory. We can open the file even
    # if locked but we won't be able to get a lock.
    if (open(my $fh, ">", $file_spec)) {
        if (flock($fh, LOCK_EX|LOCK_NB)) {
            chmod 0666, $file_spec;
            $fh->autoflush(1);
            print($fh $$);
            
            my $self = {
                        'fh' => $fh,
                        'file_spec' => $file_spec,
                       };
            bless $self, $class;
            return $self;
        }
        else {
            close($fh);
        }
    }

    return undef;
}

# ---------------------------------------------------------------------

=item unlock

Release the lock, delete the file

=cut

# ---------------------------------------------------------------------
sub unlock {
    my $self = shift;

    my $fh = delete $self->{'fh'};
    my $unlocked = flock($fh, LOCK_UN);
    close($fh);

    # NOT atomic but if another process has aquired the lock here the
    # unlink will fail which is ok
    unlink(delete $self->{'file_spec'});

    return $unlocked;
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
