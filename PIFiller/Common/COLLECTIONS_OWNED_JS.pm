
# ---------------------------------------------------------------------

=item handle_COLLECTIONS_OWNED_JS_PI

Retrieves a list of collections owned by the current $user_id
(according to Auth) and populates a javascript array with the
collection names

=cut

# ---------------------------------------------------------------------
sub  handle_COLLECTIONS_OWNED_JS_PI
    : PI_handler(COLLECTIONS_OWNED_JS)
{
    my ($C, $act, $piParamHashRef) = @_;
    my $cs = $act->get_transient_facade_member_data($C, 'collection_set_object');
    my $owner = $C->get_object('Auth')->get_user_name($C);
    my $coll_hashref = $cs->get_coll_data_from_user_id($owner);
    
    my @coll_names;
    foreach my $row (@{$coll_hashref})
    {
        push(@coll_names, $row->{'collname'});
    }
    @coll_names = sort {lc($a) <=> lc($b)} @coll_names;
    push(@coll_names, 'Select Collection');
    
    my $js = Utils::Js::build_javascript_array('getCollArray', 'COLL_NAME', \@coll_names);
    
    return $js;
}

1;
