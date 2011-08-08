package Search::Utils;

use Utils;
use Debug::DUtils;

# ---------------------------------------------------------------------

=item clean_user_query_string

Remove reserved chars of Lucene query syntax. We support words and
double quoted phrases in Phase one.

+ - && || ! ( ) { } [ ] ^ " ~ * ? : \

Note this process preserves double quote chars (") to support a
mixture of quoted strings (phrases) and single terms

2) asterisk chars (*) 

Downstream processing deals with unbalanced double quotes and
misplaced asterisks.

=cut

# ---------------------------------------------------------------------
sub clean_user_query_string {
    my $s_ref = shift;

    # Remove Lucene metacharacters
    $$s_ref =~ s,([\*|&+^!)(}{:\\?\[\]~-]), ,g;

    Utils::trim_spaces($s_ref);
}

# ---------------------------------------------------------------------

=item limit_operand_length

This may be un-necessary for Solr but it can't hurt

=cut

# ---------------------------------------------------------------------
sub limit_operand_length {
    my $op_ref = shift;
    if (length($$op_ref) > 256) {
        $$op_ref = substr($$op_ref, 0, 255);
    }
}

# ---------------------------------------------------------------------

=item ParseSearchTerms

Prepare user input to send to Solr. Adhere to
http://lucene.apache.org/java/2_4_0/queryparsersyntax.html  

Lucene/Solr wildcard searching does not go through the analyzer and so
is case sensitive.  We could downcase query terms but Lucene gives a
constant score to wild-carded terms.  That would push them to the end
of the relevance list.  Useless. We are giving up on wildcard support.

=cut

# ---------------------------------------------------------------------
sub ParseSearchTerms {
    my ($C, $s_ref) = @_;

    my $parsed_terms_arr_ref = [];

    clean_user_query_string($s_ref);
    
    # yank out quoted terms
    my @quotedTerms = ( $$s_ref =~ m,\"(.*?)\",gis );
    $$s_ref =~ s,\"(.*?)\", ,gis;
    # replace other punctuation in phrases with SPACE
    @quotedTerms = map { ($_ =~ s/\p{Punctuation}/ /g, $_) } @quotedTerms;
    # remove empty strings between quotes
    @quotedTerms = grep( !/^\s*$/, @quotedTerms );
    
    # remove leftover double quotes; they're unpaired
    $$s_ref =~ s,\",,gs;

    # yank out single word terms
    my @singleWords = split(/\s+/, $$s_ref);
    # Default item-level search is OR.  Remove AND so default OR
    # search will not be over-ridden by accidental occurrence of AND
    # (outside of a phrase) in user's query
    @singleWords = grep(! /^AND$/, @singleWords);

    foreach my $sTerm (@singleWords) {
        # Remove punctuation in the term to prevent searches on the
        # null string when term is only punctuation.
        $sTerm =~ s,^\p{Punctuation}*$, ,g;

        # if the term is empty, remove it
        next 
          if ($sTerm =~ m,^\s*$,);

        limit_operand_length(\$sTerm);

        push(@$parsed_terms_arr_ref, $sTerm); 
    }

    foreach my $qTerm (@quotedTerms) {
        limit_operand_length(\$qTerm);
        push(@$parsed_terms_arr_ref, qq{"$qTerm"});
    }

    DEBUG('query,all',
          sub
          {
              my $s = join(' ', @$parsed_terms_arr_ref);
              return qq{<h3>CGI after parsing into separate terms: $s</h3>};
          });

    return $parsed_terms_arr_ref;
}


1;
