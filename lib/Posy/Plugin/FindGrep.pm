package Posy::Plugin::FindGrep;
use strict;

=head1 NAME

Posy::Plugin::FindGrep - Posy plugin to find files using grep.

=head1 VERSION

This describes version B<0.20> of Posy::Plugin::FindGrep.

=cut

our $VERSION = '0.20';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core
		  ...
		  Posy::Plugin::FindGrep
		  ...);
    @actions = qw(init_params
	    ...
	    head_template
	    findgrep_set
	    head_render
	    ...
	);

=head1 DESCRIPTION

This plugin checks the 'find' parameter, and uses the 'grep' program
to find files which match the given regular expression.
This requires a version of 'grep' which accepts the '-l' and '-r'
arguments, which means that this plugin will not work on all
systems even if they have a 'grep' command.

This fills in a few variables which can be used withing your
flavour templates.

=over

=item $flow_findgrep_form

Contains a search-form definition for setting the 'find' parameter.

=item $flow_find

Contains the search parameter only if a search was done -- that is, the
I<legal> search parameter.  This may be preferred to be used rather than
$param_find in your flavour template files.

=item $flow_num_found

The number of entries which were found which matched the search parameter.

=back

=head2 Activation

This plugin needs to be added to the plugins list and the actions list.
Since this overrides the 'select_by_path' method, care needs to be
taken with other plugins if they override the same method.

In the actions list 'findgrep_set' needs to go somewhere after
B<head_template> and before B<head_render>, since this needs
to set values before the head is rendered.

=head2 Configuration

This expects configuration settings in the $self->{config} hash,
which, in the default Posy setup, can be defined in the main "config"
file in the config directory.

=over

=item B<findgrep_use_egrep>

Use egrep instead of grep. (default: false)

=back

=cut

=head1 OBJECT METHODS

Documentation for developers and those wishing to write plugins.

=head2 init

Do some initialization; make sure that default config values are set.

=cut
sub init {
    my $self = shift;
    $self->SUPER::init();

    # set defaults
    $self->{config}->{findgrep_use_egrep} = 0
	if (!defined $self->{config}->{findgrep_use_egrep});
} # init

=head1 Flow Action Methods

Methods implementing actions.

=head2 select_by_path

$self->select_by_path($flow_state);

If there is a 'find' parameter set, checks and uses the value as a regular
expression to grep for files.  Uses the category directory given
in the path as the directory to start from.
Sets $flow_state->{find} if the find parameter is legal.
Sets $flow_state->{num_found} to the number of matching entries.

Otherwise, just selects entries by looking at the path information.

Assumes that no entries have been selected before.  Sets
$flow_state->{entries}.  Assumes it hasn't already been set.

=cut
sub select_by_path {
    my $self = shift;
    my $flow_state = shift;

    if ($self->param('find'))
    {
	my $find_param = $self->param('find');
	$find_param =~ /([^`'"]+)/; # untaint
	my $find_regex = $1;
	if ($find_regex)
	{
	    $flow_state->{find} = $find_regex;
	    $flow_state->{entries} = [];
	    $self->{path}->{cat_id} =~ m#([-_.\/\w]+)#;
	    my $path = $1; # untaint
	    $path = '' if (!$self->{path}->{cat_id});
	    my $fullpath = File::Spec->catdir($self->{data_dir}, $path);
	    my $progname = ($self->{config}->{findgrep_use_egrep}
		? 'egrep' : 'grep');
	    open FROMGREP, "-|" or exec $progname, '-rl', $find_regex, $fullpath or die "grep failed: $!\n";
	    while (my $ffile = <FROMGREP>)
	    {
		chomp $ffile;
		my ($ff_nobase, $suffix) = $ffile =~ /^(.*)\.(\w+)$/;
		my $fpath = File::Spec->abs2rel($ff_nobase,
		    $self->{data_dir});
		my @path_split = File::Spec->splitdir($fpath);
		my $file_id = join('/', @path_split);
		if (exists $self->{files}->{$file_id})
		{
		    push @{$flow_state->{entries}}, $file_id;
		}
	    }
	    close(FROMGREP);
	    # if more than one entry was found
	    # then change the path parsing to a 'category' path.
	    if (@{$flow_state->{entries}} > 1)
	    {
		$self->{path}->{type} =~ s/entry/category/;
		$self->{path}->{file_key} = $self->{path}->{cat_id};
		$self->{path}->{ext} = '';
		$self->{path}->{data_file} = '';
	    }
	    my $num_found = @{$flow_state->{entries}};
	    $flow_state->{num_found} = $num_found;
	}
	else
	{
	    $self->SUPER::select_by_path($flow_state);
	}
    }
    else
    {
	$self->SUPER::select_by_path($flow_state);
    }
} # select_by_path

=head2 findgrep_set

$self->findgrep_set($flow_state)

Sets $flow_state->{findgrep_form} 
(aka $flow_findgrep_form)
to be used inside flavour files.

=cut
sub findgrep_set {
    my $self = shift;
    my $flow_state = shift;

    my $search_label = 'Search';
    if ($self->{path}->{cat_id} eq '')
    {
	$search_label = 'Search Site';
    }
    else
    {
	$search_label = 'Search Here';
    }
    my $action = $self->{url} . $self->{path}->{info};
    my $form = join('', '<form style="display: inline; margin:0; padding:0;" method="get" action="', $action, '">',
	'<input type="submit" value="', $search_label, '"/>',
	'<input type="text" name="find"/>',
	'</form>');
    $flow_state->{findgrep_form} = $form;
    1;
} # findgrep_set

=head1 REQUIRES

    Test::More
    grep

=head1 SEE ALSO

perl(1).
Posy

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 by Kathryn Andersen

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Posy::Plugin::FindGrep
__END__
