package Utils::Js;


=head1 NAME

Utils::Js

=head1 DESCRIPTION

This package contains utilities for building javascript data structures

=head1 VERSION

$Id: Js.pm,v 1.1 2008/03/11 18:30:00 pfarber Exp $

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut

BEGIN
{
    if ($ENV{'HT_DEV'})
    {
        require "strict.pm";
        strict::import();
    }
}

# ---------------------------------------------------------------------

=item build_javascript_array 

generate the following javascript

  function getCollArray()
  {
    var COLL_NAME = new Array(3)
    COLL_NAME[0]="Select Collection";
    COLL_NAME[1]="Auto Illustrations";
    COLL_NAME[2]="Favorites";
    
    etc ...
  }	

=cut

# ---------------------------------------------------------------------
sub build_javascript_array {
    my ($js_function_name, $arr_name, $arr_vals_arr_ref) = @_;
    
    my $arr_size = scalar(@$arr_vals_arr_ref);
    my $js;
    $js .= qq{function $js_function_name()\n};
    $js .= qq{\{\n};
    $js .= qq{var $arr_name = new Array($arr_size);\n};

    for (my $i=0; $i < $arr_size; $i++) {
        use HTML::Entities;
        # Protect against XSS attack.  Must encode twice to fully suppress the double quote in this attack string:
        # https://babel.hathitrust.org/cgi/mb?cn=test23a04f"%3Balert(1)%3B%2F%2F5e123664cee;desc=rw;shrd=0;colltype=priv;a=addc     
        my $safe_js_val = HTML::Entities::encode_entities($$arr_vals_arr_ref[$i]);
        $safe_js_val = HTML::Entities::encode_entities($safe_js_val);

        $js .= qq{$arr_name\[$i\] = "$safe_js_val";\n};
    }
    $js .= qq{return $arr_name;\n};
    $js .= qq{\}\n};

    return $js;
}
        
# ---------------------------------------------------------------------

=item build_javascript_assoc_array 

generate the following javascript

  function getCollSizeArray()
  {
    var COLL_NAME = new Array()
    COLL_NAME[2342340]=45;
    COLL_NAME[456456456]=16;
    COLL_NAME[23456345634]=1001;
    
    etc ...
  }	

=cut

# ---------------------------------------------------------------------
sub build_javascript_assoc_array
{
    my ($js_function_name, $arr_name, $hashref) = @_;
    
    my $js;
    $js .= qq{function $js_function_name()\n};
    $js .= qq{\{\n};
    $js .= qq{var $arr_name = new Array();\n};

    foreach my $key (keys %$hashref) {
        my $value = $hashref->{$key} || 0;
        $js .= qq{$arr_name\[$key\] = $value;\n};
    }
    $js .= qq{return $arr_name;\n};
    $js .= qq{\}\n};

    return $js;
}
        
# ---------------------------------------------------------------------

=item build_javascript_var

generate the following javascript

  function getCollScalar()
  {
    var COLL_NAME = 1;
    return COLL_NAME;
  }	

=cut

# ---------------------------------------------------------------------
sub build_javascript_var
{
    my ($js_function_name, $var_name, $var_val) = @_;
    
    my $js;
    $js .= qq{function $js_function_name()\n};
    $js .= qq{\{\n};
    $js .= qq{var $var_name = $var_val;\n};
    $js .= qq{return $var_name;\n};
    $js .= qq{\}\n};

    return $js;
}
        




1;

__END__

=head1 AUTHOR

Phillip Farber, University of Michigan, pfarber@umich.edu

=head1 COPYRIGHT

Copyright 2007 ©, The Regents of The University of Michigan, All Rights Reserved

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
