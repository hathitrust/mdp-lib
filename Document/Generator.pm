package Document::Generator;

=head1 NAME

Document::Generator;

=head1 DESCRIPTION

This class defines a generator for subclasses of Document.

It expects a Context and a document id. Which Socument subclass to
generate is stored in config data. That subclass must implement the
Document abstract interface.

Document::Generator will instantiate the document class when it itself
is instantiated.

The generate_next() method will create the document content that
expresses the schema of the document subclass.  A given document id
may equate to one or more instances of document content that adhere to
the configured Document subclass' schema.

The Document subclass must maintain a state variable so that the
generator can tell when all the document content instances have been
generated.

The state variable should increment each time it is queried.
"Increment" can mean simply adding 1 to a scalar or advancing a
complex pointer as in a tree traversal.  Depends on the structure of
the Document data.


=head1 SYNOPSIS

my $RUN = 1;
my $C = new Context;

my $config = SLIP_Utils::Common::gen_run_config($RUN);
$C->set_object('MdpConfig', $config);

my $db = new Database($config);
$C->set_object('Database', $db);
my $id_arr_ref = ['mdp.39015015823563'];

foreach my $id (@$id_arr_ref) {

    my $dGen = new Document::Generator($C, $id);

    my $doc;
    while ( $doc = $dGen->generate_next($C) ) {
        my ($data_status, $metadata_status) = $doc->get_document_status();
        my $lucene_doc = $doc->get_document_content();
    }
}

=head1 METHODS

=over 8

=cut

use Context;
use Document::Doc;


sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;
    $self->_initialize(@_);

    return $self;
}


# ---------------------------------------------------------------------

=item _initialize

Initialize object.

=cut

# ---------------------------------------------------------------------
sub _initialize {
    my $self = shift;
    my $C = shift;
    my $document_id = shift;

    my $doc = new Document::Doc($C, $document_id);
    
    $self->{G_document} = $doc;
    $self->{G_state_variable} = $doc->get_state_variable($C);
}

sub __get_genv {
    my $self = shift;
    my $key = shift;
    return $self->{$key};
}


# ---------------------------------------------------------------------

=item generate_next

Description

=cut

# ---------------------------------------------------------------------
sub generate_next {
    my $self = shift;
    my $C = shift;

    my $doc = $self->__get_genv('G_document');

    my $stateV = $self->__get_genv('G_state_variable');
    my $state = $stateV->();

    if (defined($state)) {
        $doc->build_document($C, $state);
    }
    else {
        $doc->finish_document($C);
        undef $doc;
    }

    return $doc;
}

1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2011 ©, The Regents of The University of Michigan, All Rights Reserved

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


