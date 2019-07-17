# ---------------------------------------------------------------------

=item handle_JUMP_TO_COLL_WIDGET_PI

Retrieves a list of collections owned by the current $user_id (according to Auth) and populates a javascript array 
with the collection names

=cut

# ---------------------------------------------------------------------
sub  handle_JUMP_TO_COLL_WIDGET_PI
    : PI_handler(JUMP_TO_COLL_WIDGET)
{
    my ($C, $act, $piParamHashRef) = @_;
    my $cs = $act->get_transient_facade_member_data($C, 'collection_set_object');
    my $owner = $C->get_object('Auth'); # ->get_user_name($C);
    my $coll_hashref = $cs->get_coll_data_from_user_id($owner);
    my $cgi = $C->get_object('CGI');
    my $coll_id = $cgi->param('c');

    #my $ary_hashref = $CS->get_coll_data_from_user_id($user_id); returns
    #reference to an array of hashrefs with the keys being MColl_ID and
    #collname returns undef if bad user_id
    my $label_hashref={};
    
    # we need a hashref with key = id value = collname
    foreach my $row (@{$coll_hashref})
    {
        $label_hashref->{$row->{'MColl_ID'}}= $row->{'collname'}
    }

    # we need list of ids sorted by coll_name
    my @sorted_ids =  sort { lc($label_hashref->{$a}) cmp lc($label_hashref->{$b})} (keys %{$label_hashref});
    
    my $name='c';
    my $default=$label_hashref->{$coll_id};
    unshift (@sorted_ids,"label");
    $label_hashref->{'label'}="Jump to a Collection";
    
    my $list_ref = \@sorted_ids;
    my $pulldown = Utils::build_HTML_pulldown_XML($name, $list_ref, $label_hashref, $default);
    return $pulldown;
}

1;
