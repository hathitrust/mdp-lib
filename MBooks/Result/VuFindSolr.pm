package MBooks::Result::VuFindSolr;


=head1 NAME

Result::VuFindSolr (rs)

=head1 DESCRIPTION

This class d encapsulates the VuFind Solr search response data.

=head1 SYNOPSIS

Coding example

=head1 METHODS

=over 8

=cut


use strict;

use base qw(Search::Result);
use XML::LibXML;


# ---------------------------------------------------------------------

=item AFTER_initialize

Subclass Initialize Result::vSolr object.

=cut

# ---------------------------------------------------------------------
sub AFTER_Result_initialize {
    my $self = shift;
    my $C = shift;
    my $id_ary_ref = shift;
    
    # get context object or id array ref here
    $self->{'parser'} = XML::LibXML->new();
    $self->__set_fieldmap();
    $self->__set_ids($id_ary_ref);
    
}

# ---------------------------------------------------------------------

=item __get_parser

Description

=cut

# ---------------------------------------------------------------------
sub __get_parser {
    my $self = shift;
    return $self->{'parser'};
}

# ---------------------------------------------------------------------

=item AFTER_ingest_Solr_search_response

Example Solr result is:
   <response>
      <lst name="responseHeader">
         <int name="status">0</int>
         <int name="QTime">2</int>
         <lst name="params">
            <arr name="fl">
               <str>ht_id_display</str>
               <str>ht-id_update</str>
            </arr>
            <str name="start">0</str>
            <str name="q">ht_id_update:[20090723 TO *]</str>
            <str name="rows">25000</str>
         </lst>
      </lst>
      <result name="response" numFound="697" start="0">
         <doc>
            <arr name="ht_id_display">
               <str>mdp.39015024227566|20090723|</str>
            </arr>
         </doc>
         <doc>
            <arr name="ht_id_display">
               <str>mdp.39015003428037|20090723|</str>
               <str>mdp.39015006021433|20090723|</str>
               <str>uc1.b4532220|20090723|</str>
            </arr>
         </doc>
         <doc>
            <arr name="ht_id_display">
               <str>mdp.39015059701311|20090723|v.2 1836 Mar-Sep</str>
            </arr>
         </doc>

etc.

=cut

# ---------------------------------------------------------------------
sub AFTER_ingest_Solr_search_response
{
    my $self = shift;
    my $Solr_response_ref = shift;

    my $parser = $self->__get_parser();
    my $doc = $parser->parse_string($$Solr_response_ref);
    my $xpath_doc = q{/response/result/doc};
    
    my $ary_metadata_hash=[];
    my $ids_in_query = $self->__get_ids();
    
    my $ids_seen = {}; #for multivolume/serials
    foreach my $id (@{$ids_in_query})
    {
        $id =~ s,^\s+,,g;
        $id =~ s,\s+$,,g;
        $ids_seen->{$id} = 0;
    }
    
    my $doc_node_count = 0;
    foreach my $doc_node ($doc->findnodes($xpath_doc)) 
    {
        my $metadata_hash ={};
        $doc_node_count++;
        foreach my $node ($doc_node->childNodes()) 
        {
            # NAME ::= arr|str
            my $name = $node->nodeName();
            # FIELD_NAME ::= <NAME name="FIELD_NAME>
            my $anode = $node->getAttributeNode('name');
            my $field_name = $anode->textContent();

            # FIELD_VAL ::= <NAME name="FIELD_NAME>FIELD_VAL</>
            if ($name eq 'arr') {
                foreach my $str_node ($node->childNodes()) {
                    my $text_node = $str_node->firstChild();
                    # Sometimes a field is empty
                    if ($text_node) {
                        my $field_val = $text_node->toString();
                        push(@{$metadata_hash->{$field_name}}, $field_val);                     
                    }
                }
            }
            else {
                my $text_node = $node->firstChild();
                # Sometimes a field is empty
                if ($text_node) {
                    my $field_val = $text_node->toString();
                    push(@{$metadata_hash->{$field_name}}, $field_val);                     
                }
            }
        }
        
        my $converted_hash;
        
        my $iteminfo_aryref = $metadata_hash->{'ht_id_display'};
        if (scalar(@{$iteminfo_aryref}) == 1)
        {
           my  ($id, $volume_info) = $self->__get_id_and_volume_info($iteminfo_aryref->[0]);
           $metadata_hash->{'volume'} = $volume_info;
           $metadata_hash->{'ht_id_display'} = $id;
           $converted_hash = $self->process_metadata($metadata_hash);
           push(@{$ary_metadata_hash}, $converted_hash);
        }
        else
        {
            # its a serial or multivolume set
            # There are more than one items for this bib record
            # we need to add a separate metadata record for any items that were in the query ids
            # along with the appropriate id and volume info
            # $ids_seen contains the query ids as keys

            my ($vufind_id_aryref,$volid_hashref) = $self->__extract_volume_metadata($iteminfo_aryref);
            
            foreach my $item_id (@{$vufind_id_aryref})
            { 
                next if (!exists($ids_seen->{$item_id})); # skip any ids that weren't in the query
                if ($ids_seen->{$item_id} == 0)
                {
                    $ids_seen->{$item_id}++;
                    $metadata_hash->{'volume'} = $volid_hashref->{$item_id};
                    $metadata_hash->{'ht_id_display'} = $item_id;
                    $converted_hash = $self->process_metadata($metadata_hash);
                    push (@{$ary_metadata_hash}, $converted_hash);
                }
            }
        }
    } # end foreach my docnode
    $self->__set_complete_result($ary_metadata_hash);
}    
# ---------------------------------------------------------------------
sub process_metadata
{       
    my $self = shift;
    my $metadata_hash = shift;

    my $cleaned_hash = $self->__clean_metadata($metadata_hash);
    my $converted_hash = $self->__convert_fieldnames($cleaned_hash);
    $converted_hash = $self->__convert_arrays_to_strings($converted_hash);
    return $converted_hash
}


# ---------------------------------------------------------------------
sub __convert_arrays_to_strings
{
    my $self = shift;
    my $hash = shift;
    my $converted = {};
    foreach my $key (keys %{$hash})
    {
        # XXX title can have 2 strings where second string is 245 with initial article removed
        # we only want 1st string foobar
        if ($key eq "display_title" && ref($hash->{$key}) eq 'ARRAY')
        {
            $hash->{$key}=$hash->{$key}->[0];
        }
        else
        {
            $hash->{$key}= $self->__Arrayref_toString($hash->{$key});
        }
        
    }
    return $hash;
}

# ---------------------------------------------------------------------
sub __Arrayref_toString
{
    my $self = shift;
    my $couldBeArrayRef = shift;
    if (ref($couldBeArrayRef) eq 'ARRAY')
    {
        my $concatenated = join (" ", @{$couldBeArrayRef});
        return $concatenated;
    }
    return $couldBeArrayRef;
}

# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# This is a holding place for cleaning VuFind related issues.  General data cleanup
# is in AddMultipleItems::normalize_metadata
#
sub __clean_metadata
{
    my $self = shift;
    my $hash = shift;
    
    my $cleanhash = {};
    
    foreach my $key (keys %{$hash})
    {
        if ($key eq "title")
        {
            if (defined ($hash->{'volume'}))
            {
                # convert title array to string and add volume             
                if (ref($hash->{'title'}) eq 'ARRAY')
        {
                    $cleanhash->{'title'} = $hash->{'title'}->[0] . " $hash->{'volume'}";
        }
        else
        {
                    $cleanhash->{'title'} .= " $hash->{'volume'}";
                }
            }
        }
        #we already processed the title and we don't want the volume in the output cleaned hash
        if ($key ne "volume" && $key ne "title")
        {
            $cleanhash->{$key} = $hash->{$key};
        }
    }
    return $cleanhash;
}

# ---------------------------------------------------------------------

#  my ($vufind_id_aryref,$volid_hashref)=$self->__extract_volume_metadata($metadata_hash->{'ht_id_display'});
   
sub __extract_volume_metadata
{
    my $self = shift;
    my $aryref = shift;
    my $id_aryref = [];
    my $id_vol_hash = {};
    
    foreach my $string (@{$aryref})
    {
        my ($cleaned_id, $vol) = $self->__get_id_and_volume_info($string);
        push (@{$id_aryref}, $cleaned_id);
        if (defined($vol))
        {
            $id_vol_hash->{$cleaned_id} = $vol;
        }
    }
    return ($id_aryref,$id_vol_hash);    
}
# ---------------------------------------------------------------------
sub __get_id_and_volume_info
{
    my $self = shift;
    my $string = shift;
    my ($cleaned_id, $junk,$vol)=split (/\|/,$string);
    return ($cleaned_id,$vol);
}

# ---------------------------------------------------------------------
sub __convert_fieldnames
{
    my $self = shift;
    my $hash = shift;
    my $fieldmap = $self->__get_fieldmap();
    my $returnhash;
    foreach my $key (keys %{$hash})
    {
        my $newkey = $fieldmap->{$key};
        $returnhash->{$newkey}=$hash->{$key};
    }
    return $returnhash;
}

# ---------------------------------------------------------------------
sub __set_ids
{
    my $self = shift;
    my $id_ary_ref = shift;
    $self->{'ids'} = $id_ary_ref;
}

# ---------------------------------------------------------------------
sub __get_ids
{
    my $self = shift;
    return $self->{'ids'};
    
}

# ---------------------------------------------------------------------
sub __get_fieldmap
{
    my $self = shift;
    return $self->{'fieldmap'};
    
}
# ---------------------------------------------------------------------
sub __set_fieldmap
{
    my $self = shift;
    my $fieldmap = shift;
    
    #XXX replace this with something from a conf file in after_initialize
    # key = vuFindSolr field name from schema
    # value = MBooks CB field name
    my $fieldmap = { 'author'=>'author',
                     'title'=>'display_title',                     
                     'titleSort'=>'sort_title',
                     'publishDate'=>'date',
                     'ht_id_display'=>'extern_item_id',
                     'id'=>'bib_id',
                   };
    $self->{'fieldmap'}=$fieldmap;
    
}
# ---------------------------------------------------------------------
=item PRIVATE: __set_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub __set_result_ids
{
    my $self = shift;
    my $arr_ref = shift;
    $self->{'result_ids'} = $arr_ref;
}

# ---------------------------------------------------------------------

=item get_result_ids

Description

=cut

# ---------------------------------------------------------------------
sub get_result_ids
{
    my $self = shift;
    return $self->{'result_ids'};
}

# ---------------------------------------------------------------------

=item get_doc_node_count

Description

=cut

# ---------------------------------------------------------------------
sub get_doc_node_count
{
    my $self = shift;
    return $self->{'doc_node_count'};
}

# ---------------------------------------------------------------------

=item PRIVATE: __set_complete_result

Description

=cut

# ---------------------------------------------------------------------
sub __set_complete_result
{
    my $self = shift;
    my $arr_ref = shift;
    $self->{'complete_result'} = $arr_ref;
}

# ---------------------------------------------------------------------

=item get_complete_result

Description

=cut

# ---------------------------------------------------------------------
sub get_complete_result
{
    my $self = shift;
    return $self->{'complete_result'};
}

1;

__END__

=head1 AUTHOR

Tom Burton-West, University of Michigan, tburtonw@umich.edu

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
