use Utils::Sort;


# ---------------------------------------------------------------------

=item get_sorting_href

Get the URL to sort a column of the collection lists

XXX tbw copied from List_Coll consider moving to Common but this needs
additional parameter "c" that List_Coll doesnt

XXX changed to base cgi
on current cgi rather than empty one.  Don't know why List_Colls uses
empty on, but maybe it has fewer possible parameters

=cut

# ---------------------------------------------------------------------
sub get_sorting_href
{
    my ($C, $sortkey) = @_;

    my $cgi = $C->get_object('CGI');
    my $temp_cgi = new CGI($cgi);
    my $a = $cgi->param('a');
    $temp_cgi->param('a',"$a");
    # Whenever we sort set current page to beginning of list i.e. page 1
    $temp_cgi->param('pn', '1');


    my $current_sortkey = Utils::Sort::get_sort_from_sort_param( $cgi->param('sort'));
    my $current_direction = Utils::Sort::get_dir_from_sort_param( $cgi->param('sort'));
    my $next_direction;
#XXX  we probably don't need this!  Check and then resolve code here with PIFiller/ListColls!!
    if ($sortkey eq 'rel')
    {
        # relevance should always be descending i.e. most relevant on top
        $next_direction = 'd';
    }
    elsif ($current_sortkey eq $sortkey)
    {
        $next_direction = ($current_direction eq 'a') ? 'd' : 'a';
    }
    else
    {
        $next_direction = 'a';
    }
    my $new_sort = $sortkey . '_' . $next_direction;
    $temp_cgi->param('sort', $new_sort);
    return CGI::self_url($temp_cgi);
}


# ---------------------------------------------------------------------

=item PT_HREF_helper

Does path mapping to support development vs. production path elements
and to support The Shibboleth Dirty Hack: /shcgi/

=cut

# ---------------------------------------------------------------------
sub PT_HREF_helper {
    my ($C, $extern_id, $which) = @_;

    my $temp_cgi = new CGI('');
    $temp_cgi->param('id', $extern_id);
    $temp_cgi->param('debug', CGI::param('debug'));

    if ($which eq 'pt_search') {
        my $cgi = $C->get_object('CGI');
        my $q1 = $cgi->param('q1');
        $temp_cgi->param('q1', $q1);
    }

    my $config = $C->get_object('MdpConfig');
    my $key;
    if ($which eq 'pt_search') {
        $key = 'pt_search_script';
    }
    else {
        $key = 'pt_script';
    }
    my $pt_script = $config->get($key);

    # The Shibboleth Dirty Hack
    my $shib = $C->get_object('Auth')->auth_sys_is_SHIBBOLETH($C);
    if ($shib) {
        $pt_script =~ s,/cgi/,/shcgi/,;
    }
    my $href = Utils::url_to($temp_cgi, $pt_script);

    return $href;
}

#======================================================================
#
#                        P I    H a n d l e r s
#
#======================================================================

# ---------------------------------------------------------------------

=item handle_COLLECTION_OWNER_PI

PI Handler for the COLLECTION_OWNER processing instruction.

=cut

# ---------------------------------------------------------------------
sub handle_COLLECTION_OWNER_PI
    : PI_handler(COLLECTION_OWNER)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $coll_owner = $act->get_transient_facade_member_data($C, 'coll_owner_display');
    $coll_owner = get_owner_string($C, $coll_owner);

    return $coll_owner;
}

# ---------------------------------------------------------------------

=item handle_COLLECTION_NAME_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_COLLECTION_NAME_PI
    : PI_handler(COLLECTION_NAME)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');
    my $co = $act->get_transient_facade_member_data($C, 'collection_object');
    my $coll_name = $co->get_coll_name ($coll_id);

    return ($coll_name);
}

# ---------------------------------------------------------------------

=item handle_EDIT_COLLECTION_WIDGET_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_EDIT_COLLECTION_WIDGET_PI
    : PI_handler(EDIT_COLLECTION_WIDGET)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $auth = $C->get_object('Auth');
    my $user_id = $auth->get_user_name($C);

    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');

    my $co = $act->get_transient_facade_member_data($C, 'collection_object');

    my $coll_owned_by_user = "no";
    # what if the call fails? do we really want it set to no if call failed?
    if ($co->coll_owned_by_user($coll_id, $user_id))
    {
        $coll_owned_by_user = "yes" ;
    }
    my $status =  $co->get_shared_status($coll_id);
    my $coll_name = $co->get_coll_name($coll_id);
    my $spaced_coll_name = getSpacedCollName($coll_name,16);

    my $coll_desc = $co->get_description($coll_id);

    my $s = "";
    $s .= wrap_string_in_tag($coll_id, 'CollId');
    $s .= wrap_string_in_tag($coll_name, 'CollName');
    $s .= wrap_string_in_tag($spaced_coll_name, 'SpacedCollName');
    $s .= wrap_string_in_tag($coll_desc, 'CollDesc');
    $s .= wrap_string_in_tag($status, 'Status');
    $s .= wrap_string_in_tag($coll_owned_by_user, 'OwnedByUser');
    $s .= wrap_string_in_tag($status, 'PublicStatus');

    return $s;
}

# ---------------------------------------------------------------------
sub getSpacedCollName
{
    my $coll_name = shift;
    my $max_len = shift;
    my @spaced_words;
    my @words=split(/\s+/,$coll_name,1000);

    foreach my $word (@words)
    {
        my $l = length($word);
        if ($l > $max_len)
        {
            my $first = substr($word,0,$max_len);
            my $last = substr($word,$max_len);
            my $spaced = $first . " " . $last;
            push (@spaced_words,$spaced);
        }
        else
        {
            push (@spaced_words,$word);
        }
    }
    my $out = join(" ",@spaced_words);
    return $out;
}

# ---------------------------------------------------------------------

=item handle_SORT_WIDGET_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_SORT_WIDGET_PI
    : PI_handler(SORT_WIDGET)
{
    #foobar
    my ($C, $act, $piParamHashRef) = @_;
    my $cgi = $C->get_object('CGI');
    my $a = $cgi->param('a');

    my @sortkeys = ('title_a','title_d','auth_a','auth_d','date_d','date_a');
    my $label_hashref = {
                         'title_a' => 'Title A-Z',
                         'auth_a'  => 'Author A-Z',
                         'date_a'  => 'Date Ascending ',
                         'rel_a'   => 'Least Relevant',
                         'title_d' => 'Title Z-A',
                         'auth_d'  => 'Author Z-A',
                         'date_d'  => 'Date Descending',
                         'rel_d'   => 'Most Relevant'
                        };

    # set default for sort part of sortkey if there is no sort param coming in
    my $concat_sortkey = $cgi->param('sort');
    my $current_sortkey = MBooks::Utils::Sort::get_sort_from_sort_param( $concat_sortkey);
    my $current_direction = MBooks::Utils::Sort::get_dir_from_sort_param( $concat_sortkey);

    my $default;
    if (!defined($concat_sortkey))
    {
        $default = 'title';
        if ($a eq "listsrch")
        {
            $default = 'rel';
        }
    }
    else
    {
        $default = $current_sortkey;# sort part of $concat_sortkey
    }
    if ($a eq "listsrch")
    {
        push (@sortkeys,'rel_a','rel_d');
    }

    # set dir part of sortkey if there is no cgi sort param coming in
    my $dir;
    if (defined($concat_sortkey))
    {
        $dir = $current_direction
    }
    elsif ($a eq 'listsrch')
    {
        $dir='d';
    }
    else
    {
        # default direction for anything but search results is ascending
        $dir='a';
    }

    # concatenat sort and dir components
    my $default = $current_sortkey . '_' . $dir;
    my $name = 'sort';
    my $pulldown = Utils::build_HTML_pulldown_XML($name, \@sortkeys, $label_hashref, $default);

    my $s;
    $s .= wrap_string_in_tag($pulldown, 'SortWidgetSort');
    return $s;
}


# ---------------------------------------------------------------------

=item handle_TITLE_SORT_HREF_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_TITLE_SORT_HREF_PI
    : PI_handler(TITLE_SORT_HREF)
{
    my ($C, $act, $piParamHashRef) = @_;
    return get_sorting_href($C, 'title')
}

# ---------------------------------------------------------------------

=item handle_AUTHOR_SORT_HREF_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_AUTHOR_SORT_HREF_PI
    : PI_handler(AUTHOR_SORT_HREF)
{
    my ($C, $act, $piParamHashRef) = @_;
    return get_sorting_href($C, 'auth')
}

# ---------------------------------------------------------------------

=item handle_DATE_SORT_HREF_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_DATE_SORT_HREF_PI
    : PI_handler(DATE_SORT_HREF)
{
    my ($C, $act, $piParamHashRef) = @_;
    return get_sorting_href($C, 'date')
}


# ---------------------------------------------------------------------

=item handle_SELECT_COLLECTION_WIDGET_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_SELECT_COLLECTION_WIDGET_PI
    : PI_handler(SELECT_COLLECTION_WIDGET)
{
    my ($C, $act, $piParamHashRef) = @_;
    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');

    # XXX tbw  Hack for use by LS.
    # original code gets data from action where operation put it but LS doesnt do that
    #    my $coll_hashref =
    #        $act->get_transient_facade_member_data($C, 'list_items_owned_collection_data');
    # is there a co on the ls action yes!
    my $co = $act->get_transient_facade_member_data($C, 'collection_object');
    my $owner = $co->get_user_id;
    my $CS = $act->get_transient_facade_member_data($C, 'collection_set_object');
    my $coll_hashref = $CS->get_coll_data_from_user_id($owner);
    # end hack

    my $s = '';
    foreach my $row (@{$coll_hashref})
    {
         # don't list current collection
        if ($row->{'MColl_ID'} != $coll_id)
        {
            my $collinfo = '';
            $collinfo .= wrap_string_in_tag($row->{'MColl_ID'}, 'collid');
            $collinfo .= wrap_string_in_tag($row->{'collname'}, 'CollName');
            $s .= wrap_string_in_tag($collinfo, 'Coll');
        }
    }

    return $s;
}


# ---------------------------------------------------------------------

=item handle_PAGING_PI

Description

=cut

# ---------------------------------------------------------------------
sub handle_PAGING_PI
    : PI_handler(PAGING)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $pager = $act->get_transient_facade_member_data($C, 'pager');
    ASSERT(defined($pager),qq{pager not defined });

    my $cgi = $C->get_object('CGI');
    my $current_page = $cgi->param('pn');
    my $current_sz = $cgi->param('sz');

    my $temp_cgi = new CGI($cgi);


    # set action in temp_cgi used to generate links
    if ($cgi->param('a') eq 'listsrchm')
    {
        $temp_cgi->param('a', 'srchm'); #need to do new search!
    }
    elsif (($cgi->param('a') eq 'listsrch')||($cgi->param('a') eq 'listsrch'))
    {
        $temp_cgi->param('a', 'listsrch');
    }
    else
    {
        $temp_cgi->param('a', 'listis');
    }

    # Point to either solr or non-solr make href function
    my $make_page_href_function = sub{};

    if ($cgi->param('a') eq 'listsrchm')
    {
        $make_page_href_function=\&make_solr_page_href;
    }
    else
    {
        $make_page_href_function=\&make_item_page_href;
    }

    my $num_records = $pager->total_entries;

    # spit out links for each page with the page range i.e href to
    # page2 label 11-20
    my $pagelinks ='';
    my $start_pagelinks = "None";
    my $middle_pagelinks = "None";
    my $end_pagelinks = "None";
    my $start;
    my $end;

    my $MAX_PAGE_LINKS = 8; #Set this so page links fit on one line
    my $NUM_END_LINKS = 2 ;

    if ($pager->last_page <= $MAX_PAGE_LINKS)
    {
        # if there aren't too many just spit out all the page links
        $start= 1;
        $end = $pager->last_page;
        $pagelinks = get_pagelinks($start,$end,$pager,$temp_cgi,$make_page_href_function,$current_page);
    }
    else
    {
        if ($current_page < $pager->last_page - ($MAX_PAGE_LINKS -1))
        {
            $start = $current_page;
            $end = $current_page +(($MAX_PAGE_LINKS - $NUM_END_LINKS) -1);
            $end_links_start = $pager->last_page - ($NUM_END_LINKS -1);
            $end_links_end = $pager->last_page;
            $start_pagelinks = get_pagelinks($start,$end, $pager,$temp_cgi,$make_page_href_function,$current_page);
        }
        else
        {
            # just output last $MAX_PAGE_LINKS links
            $start_pagelinks="Some";
            $end_links_start = $pager->last_page - (($MAX_PAGE_LINKS)-1);
            $end_links_end = $pager->last_page;
            # reset pager
            $pager->current_page($current_page);

        }
        $end_pagelinks = get_pagelinks($end_links_start,$end_links_end, $pager,$temp_cgi,$make_page_href_function,$current_page);

    }

    #-------
    # Make links for current page, next page, and previous page

    # reset pager to correct current page
    $pager->current_page($current_page);

    my $current_page_href=$make_page_href_function->($pager->current_page, $temp_cgi,$pager->first);

    my $previous_page_href;
    my $previous_page;
    my $previous_page_number = $pager->previous_page;

    if (defined ($previous_page_number))
    {
        # set pager current page to previous_page_number so that
        # $pager->first gives correct first record number for that
        # page
        $pager->current_page($previous_page_number);
        $previous_page_href = $make_page_href_function->($pager->current_page, $temp_cgi,$pager->first);
        $previous_page = wrap_string_in_tag($previous_page_href, 'Href');
    }
    else
    {
        $previous_page = "None";
    }

    # reset pager to correct current page
    $pager->current_page($current_page);

    my  $next_page_href;
    my  $next_page;
    my $next_page_number = $pager->next_page;


    if (defined ($next_page_number))
    {
        #set pager current page to next_page_number
        $pager->current_page($next_page_number);
        $next_page_href = $make_page_href_function->($pager->current_page, $temp_cgi, $pager->first);
        $next_page = wrap_string_in_tag($next_page_href, 'Href');
    }
    else
    {
        $next_page =  'None';
    }


    # Wrap output in XML
    my $s = '';
    $s .= wrap_string_in_tag($pagelinks, 'PageLinks');
    $s .= wrap_string_in_tag($current_page_href, 'CurrentPageHref');
    $s .= wrap_string_in_tag($previous_page, 'PrevPage');
    $s .= wrap_string_in_tag($next_page, 'NextPage');
    $s .= wrap_string_in_tag($start_pagelinks, 'StartPageLinks');
    $s .= wrap_string_in_tag($middle_pagelinks, 'MiddlePageLinks');
    $s .= wrap_string_in_tag($end_pagelinks, 'EndPageLinks');


    $s .= wrap_string_in_tag($pager->last_page, 'TotalPages');
    $s .= wrap_string_in_tag($pager->entries_on_this_page, 'NumRecsOnThisPage');
    $s .= wrap_string_in_tag($pager->entries_per_page, 'RecsPerPage');
    $s .= wrap_string_in_tag($pager->first, 'FirstRecordNumber');
    $s .= wrap_string_in_tag($pager->last, 'LastRecordNumber');
    $s .= wrap_string_in_tag($pager->total_entries, 'TotalRecords');# this will be affected by any limit!

    my $config = $C->get_object('MdpConfig');
    my $default_recs_per_page = $config->get('default_records_per_page');
    my $current_value = $default_recs_per_page;

    if (defined ($current_sz))
    {
        $current_value = $current_sz
    }

    my @values= $config->get('slice_sizes');
    $s .= wrap_string_in_tag(make_slice_size_widget($current_value,\@values), 'SliceSizeWidget');

    return $s;
}


# ---------------------------------------------------------------------
sub get_pagelinks
{

    my $start= shift;
    my $end = shift;
    my ($pager_in,$temp_cgi_in,$make_page_href,$current_page)= @_;
    my $temp_cgi = new CGI($temp_cgi_in);
    #instantiate new pager so we don't mess with member data of the global pager we got passed in
    my $pager = Data::Page->new($pager_in->total_entries, $pager_in->entries_per_page, $current_page);
    my $pagelinks;

    # sanity checks
    if ($end > $pager ->last_page)
    {
        $end =$pager->last_page;
    }
    if ($start < $pager->first_page)
    {
        $start = $pager->first_page;
    }
    ASSERT($start <= $end, qq{start = $start end=$end start must be less than end});
    my $pagelinks ='';
    for my $page ($start..$end)
    {
        $pagelinks .= make_pagelink($pager,$page,$temp_cgi,$make_page_href,$current_page);
    }
    return $pagelinks;
}

# ---------------------------------------------------------------------
sub make_pagelink
{
    my $pager = shift;
    my $page = shift;
    my $temp_cgi = shift;
    my $make_page_href = shift;
    my $current_page = shift;
    my $href;

    my $DISPLAY= "page" ;    # set to page|records

    $pager->current_page($page);
    $href = $make_page_href->($page, $temp_cgi, $pager->first);

    my $content;
    if ($DISPLAY eq "page")
    {
        $content = $page;
    }
    else
    {
        $content = $pager->first . "-" . $pager->last ;
        if ($pager->first == $pager->last)
        {
            $content = $pager->first;
        }
    }
    if ($pager->current_page eq $current_page)
    {
        $content = '<CurrentPage>'. $content .  '</CurrentPage>';
    }

    my $url;
    $url .= wrap_string_in_tag($href, 'Href');
    $url .= wrap_string_in_tag($content, 'Content');
    my $pagelink = wrap_string_in_tag($url, 'PageURL');
    return $pagelink;
}

# ---------------------------------------------------------------------

=item make_item_page_href

Description

=cut

# ---------------------------------------------------------------------
sub make_item_page_href
{
    my $page_number = shift;
    my $in_cgi = shift;
    my $start_rec_number = shift; # don't use this for item href
    # create clone of input temp_cgi so we don't affect it
    my $temp_cgi = new CGI($in_cgi);
    $temp_cgi->param('pn', $page_number);
    my $href = CGI::self_url($temp_cgi);

    return $href;

}

# ---------------------------------------------------------------------

=item make_solr_page_href

Description

=cut

# ---------------------------------------------------------------------
sub make_solr_page_href
{
    my $page_number = shift;
    my $in_cgi = shift;
    my $start_rec_number = shift;
    # create clone of input temp_cgi so we don't affect it
    my $temp_cgi = new CGI($in_cgi);

    if (defined ($start_rec_number ))
    {
        $start_rec_number =  $start_rec_number - 1;
    }
    else
    {
        $start_rec_number = 0;
    }

    $temp_cgi->param('start', $start_rec_number);
    $temp_cgi->param('pn', $page_number);
    my $href = CGI::self_url($temp_cgi);

    return $href;

}
# ---------------------------------------------------------------------

=item make_slice_size_widget

Description

=cut

# ---------------------------------------------------------------------
sub make_slice_size_widget

{
    my $default = shift;
    my $list_ref = shift;
    my $label_hashref={};
    my $name="sz";

    foreach my $value (@{$list_ref})
    {
        $label_hashref->{$value} = qq{$value per page};
    }
    my $pulldown =
        Utils::build_HTML_pulldown_XML($name, $list_ref, $label_hashref, $default);

    return $pulldown;
}


# ---------------------------------------------------------------------

=item handle_SEARCH_WIDGET_PI

Description

Right now the search widget pi only adds AllItemsIndexed flag
Rest of widget is in the XSL

=cut

# ---------------------------------------------------------------------
sub handle_SEARCH_WIDGET_PI
    : PI_handler(SEARCH_WIDGET)
{
    my ($C, $act, $piParamHashRef) = @_;
    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');

    my $co = $act->get_transient_facade_member_data($C, 'collection_object');
    $C->set_object('Collection', $co);
    ASSERT(defined($C->get_object('Collection')),qq{failure to set object collection});

    my $all_indexed = "FALSE";
    my $ix = new MBooks::Index;
    my ($solr_all_indexed) = $ix->get_coll_id_all_indexed_status($C,$coll_id);
    if ($solr_all_indexed)
    {
        $all_indexed="TRUE";
    }
    $s .= wrap_string_in_tag($all_indexed, 'AllItemsIndexed');
    return $s;
}


# ---------------------------------------------------------------------

=item handle_OPERATION_RESULTS_PI

Description

=cut


# ---------------------------------------------------------------------
sub handle_OPERATION_RESULTS_PI
    : PI_handler(OPERATION_RESULTS)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $copy_items_hashref =
        $act->get_persistent_facade_member_data($C, 'copy_items_data');

    # do we need these or can the xsl get it from the globals?
    my $cgi = $C->get_object('CGI');

    my $coll_id = $cgi->param('c');
    my $coll_href = make_coll_href($cgi,$coll_id);

   # Generate href for the link to the collection things were copied/moved to
    # This should always be a list items
    my $to_coll_id = $copy_items_hashref->{'to_coll_id'};
    my $to_coll_href = make_coll_href($cgi,$to_coll_id);

    # get coll_name and to_coll_name
    my $co = $act->get_transient_facade_member_data($C, 'collection_object');
    my $coll_name = $co->get_coll_name ($coll_id);
    my $to_coll_name;

    if (defined ($to_coll_id))
    {
        $to_coll_name = $co->get_coll_name ($to_coll_id);
    }

    my $s;

    $s .= wrap_string_in_tag($coll_name, 'CollName');
    $s .= wrap_string_in_tag($coll_href, 'CollHref');
    $s .= wrap_string_in_tag($to_coll_name, 'ToCollName');
    $s .= wrap_string_in_tag($to_coll_id, 'ToCollID');
    $s .= wrap_string_in_tag($to_coll_href, 'ToCollHref');

    # get counts and info on items operated on

    my $valid_ids_ref = $copy_items_hashref->{'valid_ids'};
    my $action_type = $copy_items_hashref->{'action'};

    my $already_in_coll2_ref = $copy_items_hashref->{'already_in_coll2'};
    my $key = "";
    my $valid_count = 0;
    my $already_count = 0;
    my $id = "";

    foreach $id (@{$valid_ids_ref})
    {
        $valid_count++;
        $s .= wrap_string_in_tag($id, 'ValidId');
    }

    foreach $id (@{$already_in_coll2_ref})
    {
        $already_count++;
        $s .= wrap_string_in_tag($id, 'AlreadyInColl2');
    }

    $s .= wrap_string_in_tag($valid_count, 'IdsAdded');
    $s .= wrap_string_in_tag($already_count, 'AlreadyInColl2Count');
    $s .= wrap_string_in_tag($action_type, 'CopyActionType');

    my $delete_items_hashref = $act->get_persistent_facade_member_data($C, 'delete_items_data');
    my $del_from_id = $delete_items_hashref->{'coll_id'};
    my $del_from_name = '';
    if (defined ($del_from_id))
    {
        $del_from_name = $co->get_coll_name ($del_from_id);
    }

    my $del_action_type = $delete_items_hashref->{'action'};
    my $del_valid_ids = $delete_items_hashref->{'valid_ids'};
    my $del_valid_count = 0;

    # set view if this is from a search result!  XXX start with undo
    # param being a param for action where do we get it if this is a
    # redirect list rather than the initial action?  i.e. delit is
    # followed by redirect to listit or listsrch Generalized undo
    # would have to have the action or op put something in the
    # persistent data, probably somewhere in execute operation so that
    # a redirect UI action could then retrieve it.

    my $undo_cgi = new CGI($cgi);
    $undo_cgi->param('undo','delit');
    $undo_cgi->param('a','copyit');
    $undo_cgi->param('c2',"$del_from_id");
    # delete any ids in cgi
    $undo_cgi->delete('iid');
    # add back ids that were deleted from collection
    $undo_cgi->param('iid', @{$del_valid_ids});
    # if the items were deleted from a search result set
    # page=srchresult (otherwise copyit will go to list items instead
    # of back to search results)
    if ($cgi->param('a') eq 'listsrch')
    {
        $undo_cgi->param('page','srch');
    }

    my $undo_del_href = CGI::self_url($undo_cgi);


    my $d = '';
    $d .= wrap_string_in_tag($del_action_type, 'DelActionType');
    $d .= wrap_string_in_tag($del_from_id, 'DeleteFromCollId');
    $d .= wrap_string_in_tag($del_from_name, 'DeleteFromCollName');
    foreach $id (@{$del_valid_ids})
    {
        $del_valid_count++;
        $d .= wrap_string_in_tag($id, 'DelValidId');
    }

    $d .= wrap_string_in_tag($del_valid_count, 'DelValidCount');
    $d .= wrap_string_in_tag($undo_del_href, 'UndoDelHref');
    $s .= wrap_string_in_tag($d, 'DeleteItemsInfo');

    # check to see copy items was called with an undo param
    my $undo_op = $copy_items_hashref->{'undo_op'};

    $s .= wrap_string_in_tag($undo_op, 'UndoOp');

    return $s;
}
# ---------------------------------------------------------------------
# make_coll_href
# helper for PI OPERATION_RESULTS
# ---------------------------------------------------------------------
sub make_coll_href
{
    my $cgi = shift;
    my $coll_id = shift;

    my $temp_cgi = new CGI ({}) ;

    $temp_cgi->param('c', $coll_id);
    $temp_cgi->param('a', 'listis');
    $temp_cgi->param('sz',$cgi->param('sz'));
    $temp_cgi->param('debug', $cgi->param('debug'));
    if (! $cgi->param('sort') =~m,rel,)
    {
        $temp_cgi->param('sort',$cgi->param('sort'));
    }
    my $coll_href = CGI::self_url($temp_cgi);

    return $coll_href;
}

# ---------------------------------------------------------------------

=item handle_LIMIT_TO_FULL_TEXT_PI

Description

=cut

# ---------------------------------------------------------------------
sub  handle_LIMIT_TO_FULL_TEXT_PI
    : PI_handler(LIMIT_TO_FULL_TEXT)
{
    my ($C, $act, $piParamHashRef) = @_;

    my $cgi = $C->get_object('CGI');
    my $all_temp_cgi = new CGI($cgi);
    my $full_text_temp_cgi = new CGI($cgi);
    my $limit_text = "";

    my $num_full_text = $act->get_transient_facade_member_data($C, 'full_text_count');
    my $num_all = $act->get_transient_facade_member_data($C, 'all_count');
    my $isLimitOn="NO";

    if ($cgi->param('lmt') eq 'ft')
    {
        $isLimitOn="YES";
    }

    $full_text_temp_cgi->param('lmt', 'ft');
    my $full_text_href = $full_text_temp_cgi->self_url();

    $all_temp_cgi->delete('lmt');
    my $all_href = $all_temp_cgi->self_url();

    my $s = "";
    $s .= wrap_string_in_tag($isLimitOn, 'Limit');
    $s .= wrap_string_in_tag($all_href, 'AllHref');
    $s .= wrap_string_in_tag($full_text_href, 'FullTextHref');
    $s .= wrap_string_in_tag($num_full_text, 'FullTextCount');
    $s .= wrap_string_in_tag($num_all, 'AllItemsCount');


    return $s;
}

#----------------------------------------------------------------------
1;
