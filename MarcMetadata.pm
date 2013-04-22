package MarcMetadata;


=head1 NAME

MarcMetadata

=head1 DESCRIPTION

This class packages functionality related to retrieving MARCXML from
Solr and extracting metadata fields therefrom.

It maintains a pointer to the metadata for client use.  It stores the
DOM root for field parsing. The DOM root will be invalidated in case
of caching.

Uses some code from obsolete modules Utils::Date and Utils::Serial
which have been deleted from the repository but which include some
legacy code from Tim Prettyman which may be useful for normalizing
dates from MARCXML or determining the format book v. serial v. ... of
an item.  [git checkout ...]

=head1 SYNOPSIS

my $mmdo = new MarcMetadata($C, $id);

my $marcxml_ref = $mmdo->get_metadata();

my $title = $mmdo->get_title();
my $author = $mmdo->get_author();
my $publisher = $mmdo->get_publisher();
my $vol = $mmdo->get_enumcron();


=head1 METHODS

=over 8

=cut

use strict;
use warnings;

use XML::LibXML;

use Context;
use Identifier;
use Search::Searcher;
use Search::Result::SLIP_Raw;

my $DEBUG = 0;

sub new {
    my $class = shift;
    my $self = {};
    
    $self = bless $self, $class;
    $self->__initialize(@_);

    return $self;
}

# ---------------------------------------------------------------------

=item __initialize

Initialize object.

=cut

# ---------------------------------------------------------------------
sub __initialize {
    my $self = shift;
    my ($C, $id) = @_;

    $self->{_id} = $id;

    my $root;
    my $marcxml_ref;

    if ($self->{_initialized}) {
        # restore root if object is being restored from cache (implied
        # by having already been initialized)
        $marcxml_ref = $self->{_marcxmlref};
        $root = $self->__get_document_root($marcxml_ref);
    }
    else {
        $marcxml_ref = $self->__get_solr_result($C, $id);
        if ($marcxml_ref && $$marcxml_ref) {
            $$marcxml_ref = Encode::decode_utf8($$marcxml_ref);

            $root = $self->__get_document_root($marcxml_ref);
            if ($root) {
                my $marcxml = $root->serialize();
                $marcxml_ref = \$marcxml;
                $self->{_initialized} = 1;
            }
        }
    }
    
    if ($self->{_initialized}) {
        $self->{_root} = $root;
        $self->{_marcxmlref} = $marcxml_ref;
    }
    else {
        $self->{_metadatafailure} = 1;
    }
}

# ---------------------------------------------------------------------

=item __get_d_root

Public method called after a restore from cache must restore the
document root so the (cached) xpaths will work.

=cut

# ---------------------------------------------------------------------
sub __get_d_root {
    my $self = shift;

    unless ($self->{_root}) {
        $self->__get_document_root($self->{_marcxmlref});
    }
    return $self->{_root};
}



# ---------------------------------------------------------------------

=item __get_solr_result

Description

=cut

# ---------------------------------------------------------------------
sub __get_solr_result {
    my $self = shift;
    my ($C, $id) = @_;

    print STDERR "__get_solr_result (metadata)" if ($DEBUG);
    
    my $engine_uri = $C->get_object('MdpConfig')->get('engine_for_vSolr');
    my $searcher = new Search::Searcher($engine_uri);
    my $rs = new Search::Result::SLIP_Raw();

    my $safe_id = Identifier::get_safe_Solr_id($id);
    my $query_string = qq{q=ht_id:$safe_id&start=0&rows=1&fl=fullrecord};
    $rs = $searcher->get_Solr_raw_internal_query_result($C, $query_string, $rs);

    my $responseOk = $rs->http_status_ok;

    if ($responseOk) {
        my $metadata_arr_ref = $rs->get_result_docs;
        if ($metadata_arr_ref) {
            return \$metadata_arr_ref->[0];
        }
    }

    return undef;
}

# ---------------------------------------------------------------------

=item __get_document_root

 <datafield tag="974" ind1=" " ind2=" ">
      <subfield code="z">DOC 7466 1920</subfield>
      <subfield code="u">mdp.39015062267532</subfield>
      <subfield code="r">pd</subfield>
      <subfield code="p">566</subfield>
      <subfield code="d">20120825</subfield>
 </datafield>

=cut

# ---------------------------------------------------------------------
sub __get_document_root {
    my $self = shift;
    my $marcxml_ref = shift || $self->{_marcxmlref};

    return undef if ($self->{_metadatafailure});

    return $self->{_root} if ($self->{_root});

    # Strip Solr markup and convert contained XML within XML to just XML
    $$marcxml_ref =~ s,&lt;,<,gos,;
    $$marcxml_ref =~ s,&gt;,>,gos,;
    $$marcxml_ref =~ s,&amp;amp;,&amp;,gos,;

    # <doc><str name="fullrecord"><?xml version="1.0" encoding="UTF-8"?><collection xmlns="http://www.loc.gov/MARC21/slim">
    $$marcxml_ref =~ s,^.*?<collection[^>]*>(.*?)</collection>.*$,<collection>$1</collection>,s;

    my $root;
    my $parser = XML::LibXML->new();
    eval {
        my $tree = $parser->parse_string($$marcxml_ref);
        $root = $tree->getDocumentElement();
    };
    if ($@) {
        return undef;
    }

    # Remove unwanted elements, esp. serial item records not matching
    # our id.
    my $id = $self->{_id};
    my ($record) = $root->findnodes("//record");

    my @datafield = $root->findnodes("//datafield[\@tag='974']");

    foreach my $datafield (@datafield) {
        my ($subfield_u) = $datafield->findnodes("subfield[\@code='u']");
        if ($subfield_u) {
            my $subfield_id = $subfield_u->textContent;
            if ($subfield_id ne $id) {
                $record->removeChild($datafield);
            }
        }
    }

    foreach my $tag (qw(852 970 972 973)) {
        my @datafield = $root->findnodes("//datafield[\@tag='$tag']");
        foreach my $datafield (@datafield) {
            $record->removeChild($datafield);
        }
    }

    print STDERR "__get_document_root (refresh)" if ($DEBUG);
    
    return $self->{_root} = $root;
}


# ---------------------------------------------------------------------

=item metadata_failure

Description

=cut

# ---------------------------------------------------------------------
sub metadata_failure {
    my $self = shift;
    return $self->{_metadatafailure};
}

# ---------------------------------------------------------------------

=item delete_document_root

Description

=cut

# ---------------------------------------------------------------------
my $_preserved_root;
sub delete_document_root {
    my $self = shift;
    $_preserved_root = delete $self->{_root};
}

# ---------------------------------------------------------------------

=item restore_document_root

Description

=cut

# ---------------------------------------------------------------------
sub restore_document_root {
    my $self = shift;
    $self->{_root} = $_preserved_root;
}

# ---------------------------------------------------------------------

=item get_marcxml

Description

=cut

# ---------------------------------------------------------------------
sub get_metadata {
    my $self = shift;
    return undef if ($self->{_metadatafailure});
    return $self->{_marcxmlref};
}

# ---------------------------------------------------------------------

=item get_enumcron

Description

 <datafield id="MDP" i1=" " i2=" ">
    <subfield label="u">mdp.39015055275872</subfield> (always unless serious error)
    <subfield label="z">v.2 1901</subfield> (optional -> serial or multi-vol work)
    <subfield label="h">N 1 .M42</subfield> (optional call no -> shelf location, UM specific)
    <subfield label="b">BUHR</subfield> (sublibrary code -> which library -> SDR for wu)
    <subfield label="c">GRAD</subfield> (collection code -> wu for wu)
 </datafield>

=cut

# ---------------------------------------------------------------------
sub get_enumcron {
    my $self = shift;

    return '' if ($self->{_metadatafailure});
    return $self->{_enumcron} if (defined $self->{_enumcron});

    my $root = $self->__get_d_root();

    my $enumcron;
    my ($node) = $root->findnodes(qq{//datafield[\@tag='974']});
    if ($node) {
        ($enumcron) = $node->findvalue(qq{subfield[\@code='z']});
    }

    return $self->{_enumcron} = $enumcron;
}


# ---------------------------------------------------------------------

=item get_title

Description

=cut

# ---------------------------------------------------------------------
sub get_title {
    my $self = shift;

    return '' if ($self->{_metadatafailure});
    return $self->{_title} if (defined $self->{_title});

    my $root = $self->__get_d_root();

    my @tmp = ();
    my ($node) = $root->findnodes(qq{//datafield[\@tag='245']});
    if ($node) {
        foreach my $code (qw(a b c)) {
            my ($value) = $node->findvalue(qq{subfield[\@code='$code']});
            if ($value) {
                push @tmp, $value;
            }
        }
    }

    my $title = join(' ', @tmp);
    $title =~ s,\s+, ,gsm;

    my $enumcron = $self->get_enumcron();
    if ($enumcron) {
        $title .= " " . $enumcron;
    }

    return $self->{_title} = $title;
}

# ---------------------------------------------------------------------

=item get_author

Description

=cut

# ---------------------------------------------------------------------
sub get_author {
    my $self = shift;

    return '' if ($self->{_metadatafailure});
    return $self->{_author} if (defined $self->{_author});

    my $root = $self->__get_d_root();

    my @values = ();
    foreach my $node ($root->findnodes(qq{//datafield[\@tag='100']})) {
        # a - Personal name
        # b - Numeration
        # c - titles associated with name
        # e - relator term
        # q - fuller form of name
        # d - dates associated with name
        my @tmp = ();
        foreach my $code (qw(a b c e q d)) {
            my ($value) = $node->findvalue("subfield[\@code='$code']");
            if ($value) {
                push @tmp, $value;
            }
        }
        push @values, join(" ", @tmp) if (scalar @tmp);
    }

    foreach my $node ($root->findnodes(qq{//datafield[\@tag='110']})) {
        my ($value) = $node->findvalue("subfield[\@code='a']");      # corporate name
        if ($value) {
            push @values, $value;
        }
        if ($node->exists("subfield[\@code='b']")) {                 # subordinate unit
            ($value) = $node->findvalue("subfield[\@code='c']");     # location of meeting?
            if ($value) {
                push @values, $value;
            }
        }
    }

    foreach my $node ($root->findnodes(qq{/datafield[\@tag='111']})) {
        my ($value) = $node->findvalue("subfield[\@code='a']");      # meeting name
        if ($value) {
            push @values, $value;
        }
    }

    return $self->{_author} = join('; ', @values);
}

# ---------------------------------------------------------------------

=item get_publisher

Description

=cut

# ---------------------------------------------------------------------
sub get_publisher {
    my $self = shift;

    return '' if ($self->{_metadatafailure});
    return $self->{_publisher} if (defined $self->{_publisher});

    my $root = $self->__get_d_root();

    my ($node) = $root->findnodes(qq{//datafield[\@tag='260']});
    my @tmp = ();
    if ($node) {
        foreach my $code (qw(a b c d)) {
            my ($value) = $node->findvalue("subfield[\@code='$code']");
            if ($value) {
                push @tmp, $value;
            }
        }
    }

    my $publisher = join(' ', @tmp);
    $publisher =~ s,\s+, ,gsm;

    return $self->{_publisher} = $publisher;
}

# ---------------------------------------------------------------------

=item __get_bib_fmt

Tim Prettyman

rec_type is LDR/byte6, bib_level is LDR/byte7 (0-offset)

=cut

# ---------------------------------------------------------------------
sub __get_bib_fmt {
    my $rec_type = shift;
    my $bib_level = shift;

    $rec_type =~ /[abcdefgijkmoprt]/
      or do {
          return '';
      };

    $bib_level =~ /[abcdms]/
        or do {
            return '';
        };

    $rec_type =~ /[at]/   and $bib_level =~ /[acdm]/   and return "BK";
    $rec_type =~ /[m]/    and $bib_level =~ /[abcdms]/ and return "CF";
    $rec_type =~ /[gkor]/ and $bib_level =~ /[abcdms]/ and return "VM";
    $rec_type =~ /[cdij]/ and $bib_level =~ /[abcdms]/ and return "MU";
    $rec_type =~ /[ef]/   and $bib_level =~ /[abcdms]/ and return "MP";
    $rec_type =~ /[a]/    and $bib_level =~ /[bs]/     and return "SE";
    $rec_type =~ /[bp]/   and $bib_level =~ /[abcdms]/ and return "MX";
    # no match  --error

    return '';
}

# ---------------------------------------------------------------------

=item get_format

Parse <leader>00000nam a22002531 4500</leader> bytes and call
__get_bib_fmt.  Below rec_type is byte6, bib_level is byte7 (0-offset)

=cut

# ---------------------------------------------------------------------
sub get_format {
    my $self = shift;

    return '' if ($self->{_metadatafailure});    
    return $self->{_format} if (defined $self->{_format});

    my $root = $self->__get_document_root();

    my ($leader) = $root->findnodes(qq{//leader});

    my $LDR = $leader->textContent;
    my $rec_type = substr($LDR, 6, 1);
    my $bib_level = substr($LDR, 7, 1);

    my $format = __get_bib_fmt($rec_type, $bib_level);

    return $self->{_format} = $format;
}


1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2012 ©, The Regents of The University of Michigan, All Rights Reserved

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
