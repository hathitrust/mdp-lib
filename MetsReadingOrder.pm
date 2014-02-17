package MetsReadingOrder;


=head1 NAME

MetsReadingOrder

=head1 DESCRIPTION

This module takes a METS DOM root and deduces the
reading/scanning order.

=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use XML::LibXML;

my $DEBUG = 0;

sub parse {
    my ( $root ) = @_;

    my ( $readingOrder, $scanningOrder ) = ( 'left-to-right', 'left-to-right' );

    my $techMD = ($root->findnodes(q{//METS:mdWrap[@LABEL="reading order"]}))[0];
    my $found_techMD = 0;
    if ( ref($techMD) ) {
        if ( $techMD->getAttribute('OTHERMDTYPE') eq 'Google' ) {
            $found_techMD = 1;
            $readingOrder = $techMD->findvalue('METS:xmlData/gbs:readingOrder');
            $scanningOrder = $techMD->findvalue('METS:xmlData/gbs:scanningOrder');
        }        
    }

    if ( ! $found_techMD || $readingOrder eq 'unknown' ) {
        my $structMap = ($root->findnodes(q{//METS:structMap[@TYPE='physical']/METS:div}))[0];
        my $check = $structMap->findvalue(q{METS:div[1]/@LABEL});
        if ( $check && $check =~ m,BACK_COVER, ) {
            # a terrible hack? correction heuristic in case the title/toc would be
            # located at the "back" of the book if the div's were reversed
            my $total = $structMap->findvalue(q{count(METS:div)});
            my $r = 1;
            my @features = $structMap->findnodes(q{METS:div[contains(@LABEL, 'TITLE')]});
            unless ( scalar @features ) {
                @features = $structMap->findnodes(q{METS:div[contains(@LABEL, 'TABLE_OF_CONTENTS')]});
            }
            unless ( scalar @features ) {
                @features = $structMap->findnodes(q{METS:div[contains(@LABEL, 'FIRST_CONTENT_CHAPTER_START')]});
            }
            if ( scalar @features ) {
                my $seq = $features[0]->getAttribute('ORDER');
                $r = ( $seq / $total );
            }

            if ( $r >= 0.75 ) {
                # title/toc is located at the "back" of the div's, meaning the front
                # when we reverse this for right-to-left
                $readingOrder = 'right-to-left';
                $scanningOrder = 'left-to-right';
            }

        }
    }

    return ( $readingOrder, $scanningOrder );

}

1;
