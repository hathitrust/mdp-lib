package Utils::Sort;

use Utils;


# ---------------------------------------------------------------------
# Helpers for getting  sort and dir from the now combined sort parameter
# ---------------------------------------------------------------------
sub get_dir_from_sort_param
{
    my $sort_param =  shift;
    my ($sort,$dir)=__get_dir_sort_from_sort_param($sort_param);
    return $dir;
}

sub get_sort_from_sort_param
{
    my $sort_param = shift;
    my ($sort,$dir)=__get_dir_sort_from_sort_param($sort_param);
    return ($sort);
}

sub __get_dir_sort_from_sort_param
{
    my $sort_param = shift;
    my ($sort,$dir)=split(/\_/,$sort_param);
    ASSERT ($dir eq 'a' ||$dir eq 'd',qq{dir = $dir sort_param = $sort_param dir component of sort_param must be either _a or _d});
    return ($sort,$dir);
            
}

1;
