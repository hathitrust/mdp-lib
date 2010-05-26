#
#$Id: testCollectionSet.pl,v 1.3 2008/05/21 20:17:53 pfarber Exp $#

BEGIN
{
    unshift( @INC, $ENV{'SDRROOT'} . '/lib');
}
 
use strict;
use Test::Class;
use CollectionSet::Test;
use Utils;
# warning  depends on SDRROOT/lib/DbUtils not DbUtils
# Could move subs needed by test framework to DbUtils and then modify Test.pm
use DbUtils;

$ENV{'DLPS_TEST'}="true";
#$ENV{'DLPS_TEST'}=undef;

# uncomment and modify regular expression to only run tests matching regex

#$ENV{TEST_METHOD}= qr/.*list_coll.*/i;


Test::Class->runtests;
