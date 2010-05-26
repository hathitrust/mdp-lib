package MirlynGlobals;

# Copyright 2006 The Regents of The University of Michigan, All Rights Reserved
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# ---------------------------------------------------------------------
# Mirlyn host configuration dev vs. prod
#
$gUseMirlynDevServer = $ENV{'HT_DEV'} ? 0 : 0;

$gMirlynDevHost  = q{http://dev.mirlyn.lib.umich.edu:8998};
$gMirlynProdHost = q{http://mirlyn-aleph.lib.umich.edu};

$gMirlynHost = $gUseMirlynDevServer ? $gMirlynDevHost : $gMirlynProdHost;
                

# ---------------------------------------------------------------------
# Mirlyn base URLs sys & xserver
#
$gMirlynXservBaseUrl = $gMirlynHost . q{/X};
$gMirlynSysBaseUrl   = $gMirlynHost . q{/F};


# ----------------------------------------------------------------------
#  Mirlyn catalog link
#  --------------------------------------------------------------
#  NOTE: this needs to have &amp; used since Mirlyn cannot handle
#  semicolons and, since this string appears in the output XML
#  file, it can't have plain &s
#
$gMirlynUrlParams = 
    q{?func=find-b&amp;find_code=MDN&amp;local_base=MIU01_PUB&amp;request=};
$gMirlynLinkStem = $gMirlynSysBaseUrl . $gMirlynUrlParams;


# ----------------------------------------------------------------------
#  Mirlyn metadata fetch
#  --------------------------------------------------------------
#  NOTE: this script wraps a system script that takes parameters:
#  schema=oai_marc|marcxml (default is oai_marc) no_meta=1 (will only
#  return the document number)
#
$gMirlynMetadataScriptQuery = 
    q{/cgi-bin/bc2meta?id=__METADATA_ID__;schema=oai_marc};
$gMirlynMetadataURL = $gMirlynHost . $gMirlynMetadataScriptQuery;

# ----------------------------------------------------------------------
#  Mirlyn patron record fetch
#  --------------------------------------------------------------
#  NOTE: this XServer call returns the patron record
#
$g_ssd_access_query_str = 
    q{?op=bor-info&bor_id=__UNIQNAME__&verification=__UNIQNAME__&loans=Y&cash=N&hold=N};
$g_ssd_access_url = $gMirlynXservBaseUrl . $g_ssd_access_query_str;


# ------------------------------------------------------------
1;
