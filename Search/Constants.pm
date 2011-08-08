package Search::Constants;


=head1 NAME

Search::Constants

=head1 DESCRIPTION

This package defines values retruned by the indexing code and checked
by application code and stored in j_errors table in the mdp database.

It also includes a map of class B IP addresses and corresponding site
names that key item_ids in index queues for multisite application
indexing support.

=head1 VERSION

$Id: Constants.pm,v 1.19 2010/01/10 19:39:41 pfarber Exp $

=head1 SYNOPSIS

use Search::Constants;

=over 8

=cut


use Exporter;
use base qw(Exporter);

our @EXPORT = qw(
                 IX_NOT_INDEXED
                 IX_INDEXED

                 IX_NO_ERROR
                 IX_INDEX_FAILURE
                 IX_INDEX_TIMEOUT
                 IX_SERVER_GONE
                 IX_ALREADY_FAILED
                 IX_DATA_FAILURE
                 IX_METADATA_FAILURE
                 IX_CRITICAL_FAILURE
                 IX_NO_INDEXER_AVAIL
                 IX_MAX_VALUE

                 IX_NO_COLLECTION
                );

use constant IX_NOT_INDEXED             => 0;
use constant IX_INDEXED                 => 1;

# ---------   Only used by SLIP   -----------
use constant IX_NO_ERROR                => 0;
use constant IX_INDEX_FAILURE           => 3;
use constant IX_INDEX_TIMEOUT           => 4;
use constant IX_SERVER_GONE             => 5;
use constant IX_ALREADY_FAILED          => 6;
use constant IX_DATA_FAILURE            => 7;
use constant IX_METADATA_FAILURE        => 8;
use constant IX_CRITICAL_FAILURE        => 9;
use constant IX_NO_INDEXER_AVAIL        => 10;

# UPDATE THIS MAX VALUE.  Other can add onto this to create a private
# index_state value
use constant IX_MAX_VALUE               => 10;

# Reserved coll_id for indexing item not in any collection
use constant IX_NO_COLLECTION           => 0;



# ---------------------------------------------------------------------

=item indexing_failed

Indexing is OK if good HTTP status (200). The HTTP timeout=30. We are
going to assume an IX_INDEX_TIMEOUT succeeded at the server and so, is
not an error. True errors are, document construction failed due to
metadata failure or ocr failure, or Solr parse error or server gone.

=cut

# ---------------------------------------------------------------------
sub indexing_failed
{
    my $index_state = shift;
    
    my $ok = (
              $index_state == IX_INDEXED 
              ||
              $index_state == IX_NO_ERROR
              ||
              $index_state == IX_INDEX_TIMEOUT
             );
    return (! $ok);
}

# ---------------------------------------------------------------------
1;


__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008-9 ©, The Regents of The University of Michigan, All Rights Reserved

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
