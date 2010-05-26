package MdpGlobals;

# Copyright 2007 The Regents of The University of Michigan, All Rights Reserved
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

$gMirlynErrorReportingEnabled = 1;

# Set path to feedback cgi as a function of development state and auth state.
my $cgi_path_component = ($ENV{'AUTH_TYPE'} eq 'shibboleth') ? '/shcgi' : '/cgi';
my $protocol  = defined($ENV{'AUTH_TYPE'}) ? 'https://' : 'http://';
my $host = $ENV{'HTTP_HOST'};

my $dev_feedback_url = $protocol . $host . $cgi_path_component . q{/f/feedback/feedback};
# Prod feedback cgi path or host may need to change when shib is in production
my $prod_feedback_url = q{http://quod.lib.umich.edu/cgi/f/feedback/feedback};

$gFeedbackCGIUrl = $ENV{'HT_DEV'} ? $dev_feedback_url : $prod_feedback_url;

# General configuration
$adminLink  = q{mailto:dlps-help@umich.edu};
$adminText  = q{UMDL Help};
