package Password;


=head1 NAME

Password

=head1 DESCRIPTION

This package provides a routine to read a password from the command
line without echoing it in plaintext.

=head1 SYNOPSIS

use Password;
print "Enter passwd: ";
my $passwd = get_password();
print "\n";

=head1 METHODS

=over 8

=cut


use Term::ReadKey;

# ---------------------------------------------------------------------

=item get_password

http://stackoverflow.com/questions/701078/how-can-i-enter-a-password-using-perl-and-replace-the-characters-with

=cut

# ---------------------------------------------------------------------
sub get_password() {
    my $password = "";
    # Start reading the keys
    ReadMode(4); # Disable the control keys
    my $count = 0;
    while (ord(my $key = ReadKey(0)) != 10) {
        # This will continue until the Enter key is pressed (decimal value of 10)
        if(ord($key) == 127 || ord($key) == 8) {
            # DEL/Backspace was pressed
            if ($count > 0) {
                $count--;
                #1. Remove the last char from the password
                chop($password);
                #2 move the cursor back by one, print a blank character, move the cursor back by one
                print "\b \b";
            }
        }
        elsif(ord($key) >= 32) {
            $count++;
            $password = $password.$key;
            print "*";
        }
    }
    ReadMode(0); #Reset the terminal once we are done

    return $password;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2013 ©, The Regents of The University of Michigan, All Rights Reserved

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
