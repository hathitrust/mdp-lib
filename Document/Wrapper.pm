package Document::Wrapper;

=head1 NAME

Document::Wrapper

=head1 DESCRIPTION

This class defines a sub to wrap multiple instances of Lucene document
content produced by a Document subclass.  

The Document::Generator generate_next() method is typically called in
a loop for a given document_id.  The loop result can be many Solr
documents (D=<doc>...</doc>). It is more efficient to package up
several document and wrap them with a single <add>D D D D D...</add>
element.

The caller of Document::Generator and Document::Wrapper can control
the size of the <add>.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


1;

sub wrap {
    my $C = shift;
    my $solr_doc_arr_ref = shift;
    
    my $wrapped_doc = '<add>' . join('', map { ${$_} } @$solr_doc_arr_ref) . '</add>';
    
    return \$wrapped_doc;
}


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


