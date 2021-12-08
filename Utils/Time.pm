package Utils::Time;

=head1 NAME

Utils::Time

=head1 DESCRIPTION

This non OO package contains routines to handle times.

=head1 SYNOPSIS

Coding example

=head1 SUBROUTINES

=over 8

=cut

use Date::Parse;
use Date::Calc;
use Time::HiRes;

use base qw(Exporter);
our @EXPORT = qw( unix_Time iso_UTC_Time iso_Time friendly_iso_Time days_Until );

use Utils;

my %MONTHS =
(0=>'Jan',1=>'Feb',2=>'Mar',3=>'Apr',4=>'May',5=>'Jun',6=>'Jul',7=>'Aug',8=>'Sep',9=>'Oct',10=>'Nov',11=>'Dec');

# ---------------------------------------------------------------------

=item unix_Time

Description

=cut

# ---------------------------------------------------------------------
sub unix_Time {
    my $isoTime = shift;

    # handle 0 SQL to 0 UTC
    return 0
        if (($isoTime eq '0000-00-00 00:00:00') # MySQL
            ||
            ($isoTime eq '00000000'));          # VuFind Solr

    return Date::Parse::str2time($isoTime);
}


# ---------------------------------------------------------------------

=item friendly_iso_Time

Description

=cut

# ---------------------------------------------------------------------
sub friendly_iso_Time {
    my $isoTime = shift;
    my $fmt = shift;

    my $output;
    my ($ss, $mm, $hh, $day, $mon, $yr, $zone) = Date::Parse::strptime($isoTime);

    my $month = $MONTHS{$mon};
    my $year = 1900 + $yr;
    my $hour = ($hh % 12);
    my $ampm = ($hh > 12) ? 'p.m.' : 'a.m.';
    $day =~ s,^0,,;

    if ($fmt eq 'date') {
        $output = qq{$month $day, $year};
    }
    elsif ($fmt eq 'time') {
        $output = qq{$hour:$mm:$ss $ampm};
    }
    else {
        $output = qq{$month $day, $year @ $hour:$mm:$ss $ampm};
    }

    return $output;
}

# ---------------------------------------------------------------------

=item iso_UTC_Time

Takes a unix time like from unix_Time() above which assumes the system
time zone and returns a human readable string localized to the UTC
time zone, e.g. 2010-09-28 18:43 UTC

=cut

# ---------------------------------------------------------------------
sub iso_UTC_Time {
    my $time = shift;

    my @time = gmtime($time);

    #  0    1    2     3     4    5     6     7     8
    # ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
    my $yea = sprintf("20%02d", $time[5] - 100);
    my $mon = $time[4] + 1;
    my $day = $time[3];
    my $hou = $time[2];
    my $min = $time[1];
    my $sec = $time[0];

    my $isoUTCtime = sprintf("%4d-%02d-%02d %02d:%02d UTC", $yea, $mon, $day, $hou, $min);

    return $isoUTCtime;
}

# ---------------------------------------------------------------------

=item iso_Time

Description: time formatted especially to work as a MySQL
timestamp. Only works for years in the 21st century.

=cut

# ---------------------------------------------------------------------
sub iso_Time {
    my $num_args = scalar(@_);

    my ($what, $time);

    if ($num_args == 0) {
        $what = 'datetime';
    }
    elsif ($num_args == 1) {
        $what = shift;
    }
    elsif ($num_args == 2) {
        ($what, $time) = @_;
    }

    $time = time if (! defined($time));
    my @time = localtime($time);
    #  0    1    2     3     4    5     6     7     8
    # ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
    my $zon = $time[8] ? 'EDT' : 'EST';
    my $yea = sprintf("20%02d", $time[5] - 100);
    my $mon = $time[4] + 1;
    my $day = $time[3];
    my $hou = $time[2];
    my $min = $time[1];
    my $sec = $time[0];

    my $include_zone = 0;
    if ($what =~ m,^z,) {
        $include_zone = 1;
        $what =~ s,^z,,;
    }

    my $isoTime;
    if ($what eq 'date') {
        $isoTime = sprintf("%4d-%02d-%02d", $yea, $mon, $day);
    }
    elsif ($what eq 'time') {
        $isoTime = sprintf("%02d:%02d:%02d", $hou, $min, $sec);
        $isoTime .= " $zon" if ($include_zone);
    }
    elsif ($what eq 'hhmm') {
        $isoTime = sprintf("%02d:%02d", $hou, $min);
        $isoTime .= " $zon" if ($include_zone);
    }
    elsif ($what eq 'hour') {
        $isoTime = sprintf("%02d", $hou);
        $isoTime .= " $zon" if ($include_zone);
    }
    elsif  ($what eq 'datetime') {
        $isoTime = sprintf("%4d-%02d-%02d %02d:%02d:%02d", $yea, $mon, $day, $hou, $min, $sec);
        $isoTime .= " $zon" if ($include_zone);
    }
    elsif  ($what eq 'sdt') {
        $isoTime = sprintf("%4d-%02d-%02d_%02d:%02d:%02d", $yea, $mon, $day, $hou, $min, $sec);
        $isoTime .= "_$zon" if ($include_zone);
    }
    elsif  ($what eq 'filename') {
        $isoTime = sprintf("%4d-%02d-%02d_%02d-%02d-%02d", $yea, $mon, $day, $hou, $min, $sec);
        $isoTime .= "_$zon" if ($include_zone);
    }

    return $isoTime;
}

# ---------------------------------------------------------------------

=item expired

Given iso date and expriation date return true if iso date has
expired.

=cut

# ---------------------------------------------------------------------
sub expired {
    my $expiration_date = shift;

    my $unix_now = time();
    my $unix_expiration_date = unix_Time($expiration_date);

    return ($unix_now > $unix_expiration_date);
}

# ---------------------------------------------------------------------

=item days_Until

count days from "now" until date passed in.
Format of input param (YYYY, M[M], D[D]), i.e. (2010, 4, 17).

=cut

# ---------------------------------------------------------------------
sub days_Until {
    my @untilDate = @_;

    my @today = (localtime)[5,4,3];
    $today[0] += 1900;
    $today[1]++;

    my $num_date_elems = scalar @untilDate;
    ASSERT( ($num_date_elems == 3), qq{invalid "until" date. num elems must be 3: seen=$num_date_elems} );

    my $daysUntil = Date::Calc::Delta_Days(@today, @untilDate);

    return $daysUntil;
}

# ---------------------------------------------------------------------

=item get_elapsed

Description

=cut

# ---------------------------------------------------------------------
sub get_elapsed {
    my $since = shift;

    my ($user, $system) = times;
    my $now = Time::HiRes::time;
    my $elapsed  = $now - (defined($since) ? $since : $main::realSTART);

    my $t = qq{elapsed=$elapsed sys=$system user=$user};

    return $t;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2008-10 ©, The Regents of The University of Michigan, All Rights Reserved

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
