package Search::Utils;

use Debug::DUtils;
use Search::Document::ISO8859_1_Map;
use Utils;

use File::Basename;
my $LOCATION = dirname(__FILE__);
$gPtLibMiscDir = $LOCATION . '/misc';
$gDd        = $gPtLibMiscDir . '/MBooksXPatDataDictionary.xml';
$gMdpTags   = $gPtLibMiscDir . '/mdp-regions.tags';


# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub HighlightMultipleQs
{
    my ($C, $parsedQsCgi, $textRef, $partial) = @_;

    my $hitFound = highlight_hit($C, $parsedQsCgi, $textRef, $partial);
}

# ----------------------------------------------------------------------
# NAME         : highlight_hit
# PURPOSE      : highlight hits in full page and KWICs
# INPUT        :
# RETURNS      :
# NOTES        : Perl 5.8.0 tr/// is buggy for some translations so
#                highlighting of certain strings from non western
#                languages currently fails.  This is the exception.
#
#                NOTE: KWICs have had CARRIAGE_RETURN replaced by SPACE
# ----------------------------------------------------------------------
sub highlight_hit
{
    my ($C, $parsedQsCgi, $s_ref, $partial) = @_;

    # flag to return: false if no hits found, true if hits found
    my $hitFound = 0;

    # Input string can have multiple spaces that XPAT space
    # compression algorithms collapse to a single space.  Emulate that
    # here to make the highlighting regexps match.  We don't use \s
    # because that also matches CARRIAGE_RETURN needed downstream to
    # format the OCR into lines when dealing with a full page. Must be
    # performed on input to preserve offsets.
    $$s_ref =~ s,( [ ]+), ,g;

    # Create a working buffer to match q's within, If encoding of
    # incoming data is UTF-8 the UTF-8 flag will have been set by in
    # XPat::Simple to make Perl treat the string as characters instead
    # of bytes.
    my $buf = $$s_ref;

    # Change all chars between '<' amd '>' and leading and trailing
    # half-tags to ' ' inclusive to avoid matching q's within tags
    # while maintaining character offsets into original data

    # leading half-tags
    $buf =~ s,(^[^<]*>),' ' x length( $1 ),es;
    # trailing half-tags
    $buf =~ s,(<[^>]*)$,' ' x length( $1 ),es;
    # within tags
    $buf =~ s,(<.*?>),' ' x  length( $1 ),ges;

    # Build translation tables
    my ( $fromRef, $toRef ) = BuildCharacterMap($C);

    DEBUG('highm',
          sub
          {
              my ( $f, $t ) = ( $$fromRef, $$toRef );
              $f =~ tr/\b\n\r\t/    /; $t =~ tr/\b\n\r\t/    /;
              my $s .= qq{<pre>Fm=$f</pre><br />};
              $s .= qq{<pre>To=$t</pre>\n};
              return $s;
          });

    # No highlighting if maps fail to build
    return if ( ! ( $$fromRef && $$toRef ) );

    # Apply translation map to data copy. Perl translation tables are
    # built at compile-time so we have to eval the tr/// to compile
    # the table.
    my $msg = "Translation table compilation failure in highlight_hit";
    eval "\$buf =~ tr/$$fromRef/$$toRef/;";
    ASSERT( ( ! $@ ), $msg  );

    DEBUG('highb', qq{<h2>Buffer after translation:</h2><p>|$buf|</p>\n});

    # Get all words searched for into one array -- remove trailing
    # spaces and apply translation map. Special handling for '*': It
    # might be present, it might be mapped to anything including
    # another '*' or space.  But other terminal chars might be mapped
    # to '*' or space as well. Handle all these cases.

    my $i = 0;
    my %qvalsHash;
    foreach my $q ('q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q8', 'q9')
    {
        my @qvals = $parsedQsCgi->param( $q );
        if ( $qvals[0] )
        {
            foreach my $qv ( @qvals )
            {
                $i++;

                # cut trailing whitespace
                $qv =~ s,(.*?) +$,$1,;
                my $asterisk = $qv =~ s,\*$,,;
                # cut trailing whitespace exposed by removing possible asterisk
                $qv =~ s,(.*?) +$,$1,;
                # if the hit was solely an asterisk: nothing to highlight
                next if ( ! $qv );

                # otherwise push it through the map
                eval "\$qv =~ tr/$$fromRef/$$toRef/;";

                # If mapping produces an empty or whitespace string
                # there's nothing to highlight
                if ( $qv && ( $qv !~ m,^\s+$, ) )
                {
                    $qvalsHash{$qv}{'idx'} = $i;
                    $qvalsHash{$qv}{'wildcard'} = $asterisk;
                    $qvalsHash{$qv}{'truncatable'} = alphabet_is_truncatable($C, \$qv);
                    DEBUG('highq', qq{|$qv|, truncatable=$qvalsHash{$qv}{'truncatable'}<br/>\n});
                }
            }
        }
    }
    
    return \%qvalsHash if ( $partial );

    # Sort hits in descending order by length of word/phrase so that
    # we can prevent highlighting of substrings within a longer hit
    # string in cases involving data e.g. containing "I will send you
    # a rebel flag", and also "send" elsewhere that within this phrase
    # where the query terms are "I will send you a rebel flag" and
    # "send". See _exclude_substring_match() below.

    # Loop over the data copy recording the offsets of the matches for
    # each potential hit.
    my %hitList;
    foreach my $hit ( sort { length( $b ) <=> length( $a ) } keys %qvalsHash )
    {
        # Use \Q\E to allow for metachars introduced by the character
        # translation mapping. If the hit has an asterisk appended
        # (wildcard) allow chars to appear after the hit up to a word
        # boundary, otherwise delimit the hit with a word boundary
        # immediately following it.

        my $wildcard = $qvalsHash{$hit}{'wildcard'};
        my $truncatable = $qvalsHash{$hit}{'truncatable'};
        my $RE;
        if ( $truncatable )
        {
            if ( $wildcard )
            {   $RE = "\\b(\Q$hit\E.*?)\\b";   }
            else
            {   $RE = "\\b(\Q$hit\E)\\b";   }
        }
        else
        {
            # non-truncatable terms are essentially not wildcardable
            # and not delimited by word boundaries
            $RE = "(\Q$hit\E)";
        }

        my $compRE = qr/$RE/; # compile the pattern
        my $matching = 1;
        while ( $matching )
        {
            if ( $buf =~ m,$compRE,g )
            {
                # Save offset of char following the match and the
                # length of the match to get the match's begin pos.
                # Do not record this match if its start pos is within
                # that of a longer match already recorded because that
                # would amount to highlighting a substring within a
                # larger, already to-be-highlighted string match.
                my $length = length( $1 );
                my $trailingPos = pos($buf);
                my $startPos = $trailingPos - $length;

                DEBUG('highq', qq{<font color="red">match</font>=|$1|, length=$length, startPos=$startPos, trailPos=$trailingPos <br />\n});

                if ( ! _exclude_substring_match( $startPos, $trailingPos, \%hitList ) )
                {
                    $hitList{$trailingPos}{'trail'} = $length;
                    $hitList{$trailingPos}{'idx'} = $qvalsHash{$hit}{'idx'};
                    $hitFound++;
                }
            }
            else
            {   $matching = 0;   }
        }
    }

    return $hitFound  if ( ! $hitFound );
    
    # Markup for XML vs. HTML and for multicoloring.
    my ( $sMarkup, $eMarkup ) =
        (q{<Highlight class="hilite@" seq="_%%">}, q{</Highlight>});

    my ( $sDefaultMarkupLen, $eMarkupLen ) =
        ( length( $sMarkup ), length( $eMarkup ) );


    # Now we have the offsets at which we need to insert the
    # highlighting markup around the hits in the original data.
    # Copy from the original source to the destination buffer.  Note
    # we reuse the buffer now that the offset list has been built to
    # take advantage of its original memory allocation.

    # leading offsets ----------v----------------v
    # Original string: |--------y( q1 hit )x-----y( q2   hit )x-----|
    #        trailing offsets -------------^------------------^
    #                  lengths ->|   l1   |<-   ->|    l2    |<-

    my $len;
    my $leadOff;
    my ( $srcStart, $destStart ) = ( 0, 0 );

    # Empty the buffer.
    $buf='';

    foreach my $trailOff ( sort { $a <=> $b } keys %hitList )
    {
        my $hitLen = $hitList{$trailOff}{'trail'};
        my $idx = $hitList{$trailOff}{'idx'};

        # copy the substring before a hit from src to destination
        $leadOff = $trailOff - $hitLen;
        $len = $leadOff - $srcStart;
        substr( $buf, $destStart, $len ) = substr( $$s_ref, $srcStart, $len );
        $srcStart += $len;
        $destStart += $len;

        # insert the beginning hit markup into the destination
        # multicolof
        $sMarkup =~ s,@,$idx,;

        # Set correct length for double digit idx= 10, 11, 12, ...
        my $sMarkupLen = $sDefaultMarkupLen + int( $idx / 10 );

        substr( $buf, $destStart, $sMarkupLen ) = $sMarkup;
        $destStart += $sMarkupLen;

        # multicolor
        $sMarkup =~ s,$idx,@,;

        # copy the hit from src to destination
        substr( $buf, $destStart, $hitLen ) = substr( $$s_ref, $srcStart, $hitLen );
        $srcStart += $hitLen;
        $destStart += $hitLen;

        # insert the ending hit markup into the destination
        substr( $buf, $destStart, $eMarkupLen ) = $eMarkup;
        $destStart += $eMarkupLen;
    }

    # copy the substring following the last hit
    substr( $buf, $destStart ) = substr( $$s_ref, $srcStart );

    # supply highlighted terms with sequential attribute values
    my $seq = 1;
    while ( $buf =~ s,seq="_%%",seq="$seq",s )
    {     $seq++;     }

    # If highlighting tag insertion severs an & char from its CER text
    # or the text from its terminal semi-colon, delete it and its
    # text.
    $buf =~ s,&(<Highlight[^>]+>)[a-z]+,$1,g;
    $buf =~ s,&[a-z]+(<Highlight[^>]+>),$1,g;

    # point at new data
    $$s_ref = $buf;

    return $hitFound;
}

# ======================================================================
#
#         H i t   H i g h t l i g h t i n g   F u n c t i o n s
#
# ======================================================================
# ---------------------------------------------------------------------

=item alphabet_is_truncatable

Consult list of scripts that do not use whitespace to delimit words to
affect stemming and highlighting. Steming does not work in e.g. CJK
alphabets because in transforming "term" into "term " the original
term will not be found due to the absence if spaces in CJK.


=cut

# ---------------------------------------------------------------------
sub alphabet_is_truncatable
{
    my $C = shift;
    my $s_ref = shift;

    my $truncatable = 1;
    my @characters = split(//, $$s_ref);
    
    my $config = $C->get_object('MdpConfig');
    my @noStemScripts = $config->get('hilite_nostem_scripts');
    
    foreach my $c (@characters)
    {
        if (ord($c) > 0xFF)
        {
            foreach my $alphabet (@noStemScripts)
            {
                if ( $c =~ m,\p{$alphabet},)
                {
                    $truncatable = 0;
                    last;
                }
            }
        }
    }

    return $truncatable;
}



# ----------------------------------------------------------------------
# NAME         : _build_char_map
# PURPOSE      : parse collname.dd or DefaultCharacterMap.xml to construct
#                the list of "from" and "to" characters needed to
#                drive a perl tr/// command emulating the mapping performed
#                by XPAT at index-time and run-time
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------

my %charHash = (
                "a" => "&",
                "b" => "\b",
                "g" => ">",
                "l" => "<",
                "n" => "\n",
                "r"  => "\r",
                "t"  => "\t",
               );

#
# Takes a string containing one character or the ordinal value of a
# character in string form and returns a CHARACTER.  NB this routine
# returns two '\' characters, i.e. '\\\\' if the input is '\' because
# the output is used directly in a tr/// operator string and we don't
# want to escape the following character in the "from" or "to" strings
#
sub _numStr2Char
{
    my $s = shift;

    # parse metachar like "&tab." using just first letter
    if ( $s =~ m,^&([abglnrt]),o )
    {   return $charHash{$1};   }
    # Unicode notation: \x{XXXX} notation
    elsif ( $s =~ s,^U\+,,o )
    {   return chr( hex( $s ) );   }
    # octal notation: convert to \x{XXXX} notation except for '\'
    elsif ( $s =~ m,^\\$,o )
    {   return '\\\\';   }
    elsif ( $s =~ s,^\\,,o )
    {   return chr( oct( $s ) );   }
    # ASCII character
    else
    {   return $s;   }
}

my %gCharMapCache;
sub BuildCharacterMap
{   
    my $charMapFile = $gDd;
    my $dd = 'default';

    DEBUG('highq,highm', qq{<br/>Need map for $dd<br/>\n});

    # Check the cache to see if we have already a map fro this dd.
    if ( $gCharMapCache{$dd})
    {
        DEBUG('highq,highm', qq{Returned chached map for $dd<br/>\n});
        return ( $gCharMapCache{$dd}{'fromref'}, $gCharMapCache{$dd}{'toref'} );
    }

    local $/ = '</Mappings>';

    open( CHARMAP, '<:utf8', "$charMapFile" ) || return ( undef, undef );
    my $map = <CHARMAP>;
    close( CHARMAP );

    # Eliminate record separators, formatting
    # to make the patterns below more robust
    $map =~ s,[\r\n\t],,g;

    my @rawFrom = $map =~ m,<From>(.*?)</From>,g;
    my @rawTo = $map =~ m,<To>(.*?)</To>,g;

    my ( $fromMap, $toMap );
    for ( my $i=0; $i < scalar( @rawFrom ); $i++ )
    {
        # parse e.g. <From><CharRange><First>A</First><Last>Z</Last></CharRange></From>
        # "from" and "to" ranges are guaranteed to be the same size at index time and
        # are assumed to be contiguous.
        if ( $rawFrom[$i] =~ m,Char, )
        {
            my ( $firstFrom, $lastFrom ) =
                $rawFrom[$i] =~ m,<CharRange><First>(.*?)</First><Last>(.*?)</Last>,o;
            my ( $firstTo, $lastTo ) =
                $rawTo[$i] =~ m,<CharRange><First>(.*?)</First><Last>(.*?)</Last>,o;

            my ( $from, $to ) =
                ( ord( _numStr2Char( $firstFrom ) ), ord( _numStr2Char( $firstTo ) ) );
            my $last_from = ord( _numStr2Char( $lastFrom ) );

            while( $from <= $last_from )
            {
                $fromMap .= chr( $from ); $from++;
                $toMap   .= chr( $to ); $to++;
            }
        }
        else
        {
            $fromMap .= _numStr2Char( $rawFrom[$i] );

            # If 'from' is mapped to NULL (<From>x</From><To></To>)
            # make the 'to' be the same as the 'from' to keep the
            # from/to arrays parallel
            $toMap   .= _numStr2Char( $rawTo[$i] ? $rawTo[$i] : $rawFrom[$i] );
        }
    }

    # Cache the map
    $gCharMapCache{$dd}{'fromref'} = \$fromMap;
    $gCharMapCache{$dd}{'toref'} = \$toMap;

    DEBUG('highq,highm', qq{Returned (and cached) newly built map for $charMapFile<br/>\n});

    return ( \$fromMap, \$toMap );
}

# ---------------------------------------------------------------------
# Test the start and end position of a hit to see if either is within the
# start position + length of an already recorded hit match to prevent the
# highlighting of substrings within an already to-be-highlighted hit
# matches.
# ---------------------------------------------------------------------
sub _exclude_substring_match
{
    my ( $startPos, $trailingPos, $hitListHashRef ) = @_;

    foreach my $testtrailingPos ( keys % { $hitListHashRef } )
    {
        my $len = $$hitListHashRef{$testtrailingPos}{'trail'};
        my $teststartPos = $testtrailingPos - $len + 1;

        if (
            ( $startPos >= $teststartPos ) &&
            ( $startPos <= $testtrailingPos )
            ||
            ( $trailingPos >= $teststartPos ) &&
            ( $trailingPos <= $testtrailingPos )
           )
        {
            # DEBUG('highq', qq{<font color="blue">overlap</font>, startPos=$startPos, trailPos=$trailingPos <br />\n});
            # does startPos overlap?
            return 1;
        }
    }

    return 0;
}

# ---------------------------------------------------------------------

=item clean_user_query_string

Do several mappings to make the string compatible with XPAT query
syntax.

Note this process preserves double quotes to support a mixture of
quoted strings (phrases) and single terms all of which can then be
conjoined or disjoined in a web-style query

=cut

# ---------------------------------------------------------------------
sub clean_user_query_string
{
    my $s_ref = shift;

    # remove Perl metacharacters that interfere with the
    # regular expressions we build to highlight hits and to
    # parenthesize XPat queries.
    $$s_ref =~ s,[\\\(\)\[\]\?\$\^\+\|], ,g;

    # remove variations on wild card searches that resolve to
    # searching for the empty string to prevent runaway
    # searches
    $$s_ref =~ s,^\*+,,g;  # no leading '*'
    $$s_ref =~ s,\*+,*,g;  # only a single trailing '*'

    # We now support AND, OR operators in the Solr interface. Remove
    # those so they are not searched as words in the XPAT query.
    $$s_ref =~ s,(\s+AND\s+|\s+OR\s+), ,g;
    
    Utils::trim_spaces($s_ref);
}

# ---------------------------------------------------------------------

=item limit_operand_length

Description

=cut

# ---------------------------------------------------------------------
sub limit_operand_length {
    my $op_ref = shift;
    
    # XPAT accepts a maximum of 256 chars in a query operand.
    if (length($$op_ref) > 256)
    {
        $$op_ref = substr($$op_ref, 0, 255);
    }
}

# ----------------------------------------------------------------------
# NAME         :
# PURPOSE      :
# CALLS        :
# INPUT        :
# RETURNS      :
# GLOBALS      :
# SIDE-EFFECTS :
# NOTES        :
# ----------------------------------------------------------------------
sub ParseSearchTerms
{
    my ($C, $s_ref) = @_;

    clean_user_query_string($s_ref);

    my @finalQs;
    # fix unpaired double quotes

    # yank out quoted terms
    my @quotedTerms = ( $$s_ref =~ m,\"(.*?)\",gis );
    $$s_ref =~ s,\"(.*?)\",,gis;
    @quotedTerms = grep( !/^\s*$/, @quotedTerms );

    # yank out leftover single instance of double quote, if any
    $$s_ref =~ s,\",,gs;
    Utils::trim_spaces($s_ref);

    # yank out single word terms
    my @singleWords = split( /\s+/, $$s_ref );

    push( @finalQs, @quotedTerms, @singleWords );

    my $cgi = $C->get_object('CGI');
    my $parsedQsCgi = new CGI($cgi);

    my $numberOfCgiQs = 0;
    my $numberOfFinalQs = scalar( @finalQs );
    foreach ( my $i = 0; $i < $numberOfFinalQs; $i++ )
    {
        my $qTerm = $finalQs[$i];

        # Remove punctuation in the term usually mapped to ' ' by XPAT
        # causing searches on the null string (finds all pages) when
        # term is only punctuation. Preserve wildcard (*).
        my $wildcard = ($qTerm =~ m,.+\*$,);
        $qTerm =~ s,\p{Punctuation}, ,g;
        next 
          if ($qTerm =~ m,^\s*$,);
        $qTerm .= '*' 
          if ($wildcard);

        limit_operand_length(\$qTerm);
        Search::Document::ISO8859_1_Map::iso8859_1_mapping(\$qTerm);

        # if the term is empty, remove it
        if ( $qTerm &&
             $qTerm ne '*' )
        {
            my $qNumber = 'q' . ( $numberOfCgiQs + 1 );
            $numberOfCgiQs++;
            $parsedQsCgi->param($qNumber, $qTerm);
        }
    }

    # tack on $numberOfFinalTerms onto the transient cgi, so that it
    # will be available downstream
    $parsedQsCgi->param( 'numberofqs', $numberOfCgiQs );

    DEBUG('search,all',
          sub
          {
              my $s = $parsedQsCgi->as_string();
              return qq{<h3>CGI after parsing into separate terms: $s</h3>};
          });

    return ( $numberOfCgiQs, $parsedQsCgi );
}


1;