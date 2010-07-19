=head1 NAME

RECENTLY_ADDED.pm

=head1 DESCRIPTION

This a single PI package which consists of "packageless" shared
methods that become methods in the package into which they are
"require"d.

=head1 SYNOPSIS

BEGIN
{
    require "PIFiller/Common/RECENTLY_ADDED.pm";
}

see also package with the naming convention Group_*.pm

=head1 METHODS

=over 8

=cut




# ---------------------------------------------------------------------

=item handle_RECENTLY_ADDED_PI :  PI_handler(RECENTLY_ADDED)

List of public collections recently created or modified

=cut

# ---------------------------------------------------------------------
sub handle_RECENTLY_ADDED_PI
    : PI_handler(RECENTLY_ADDED)
{
    my ($C, $act, $piParamHashRef) = @_;
    
    my $config = $C->get_object('MdpConfig');
    my $list_size = $$piParamHashRef{'list_size'};
    
    my $co = $act->get_transient_facade_member_data($C, 'collection_object');
    my $coll_arr_ref = $co->collnames_recently_added($list_size);
    
    my $temp_cgi = new CGI('');
    $temp_cgi->param('a', 'listis');
    
    my $Content;
    foreach my $coll (@$coll_arr_ref)
    {
        $temp_cgi->param('c', $$coll{'MColl_ID'});
        my $href = Utils::url_to($temp_cgi);
        
        my $item = 
            wrap_string_in_tag($$coll{'collname'}, 'Name') 
                . wrap_string_in_tag($href, 'Href');

        $Content .= wrap_string_in_tag($item, 'Item');
    }

    return $Content;
}



1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2009 ©, The Regents of The University of Michigan, All Rights Reserved

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
