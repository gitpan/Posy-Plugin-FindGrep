package Posy::Plugin::FindGrep;
use strict;

=head1 NAME

Posy::Plugin::FindGrep - Posy plugin to find files using grep.

=head1 VERSION

This describes version B<0.23> of Posy::Plugin::FindGrep.

=cut

our $VERSION = '0.23';

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

=head2 Cautions

This plugin does not work if you have a hybrid site (partially
static-generated, partially dynamic) and also use the
Posy::Plugin:;Canonical plugin, since the Canonical plugin will redirect
your search query.  Also, if you have a hybrid site, don't forget to set
the L</findgrep_url> config variable.

=head2 Activation

This plugin needs to be added to the plugins list and the actions list.
Since this overrides the 'select_entries' method, care needs to be
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

=item B<findgrep_url>

The URL to use for the "action" part of the search form.
This defaults to the global $self->{url} value, but may
need to be overridden for things like a hybrid static/dynamic site.
This is because the global $self->{url} for static generation
needs to hide the name of the script used to generate it,
but this plugin needs to know the path to the CGI script.

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
    $self->{config}->{findgrep_url} = ''
	if (!defined $self->{config}->{findgrep_url});
} # init

=head1 Flow Action Methods

Methods implementing actions.

=head2 select_entries

$self->select_entries($flow_state);

If there is a 'find' parameter set, checks and uses the value as a regular
expression to grep for files.  Uses the category directory given
in the path as the directory to start from.
Sets $flow_state->{find} if the find parameter is legal.
Sets $flow_state->{num_found} to the number of matching entries.

Otherwise, just selects entries by looking at the path information.

Assumes that no entries have been selected before.  Sets
$flow_state->{entries}.  Assumes it hasn't already been set.

=cut
sub select_entries {
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
	    $self->SUPER::select_entries($flow_state);
	}
    }
    else
    {
	$self->SUPER::select_entries($flow_state);
    }
} # select_entries

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
    my $action = ($self->{config}->{findgrep_url}
	? $self->{config}->{findgrep_url} : $self->{url});
    # Set the path as a separate parameter
    my $path = $self->{path}->{info};
    my $form = join('', '<form style="display: inline; margin:0; padding:0;" method="get" action="', $action, '">',
	'<input type="submit" value="', $search_label, '"/>',
	'<input type="text" name="find"/>',
	'<input type="hidden" name="path" value="', $path, '"/>',
	'</form>');
    $flow_state->{findgrep_form} = $form;
    1;
} # findgrep_set

=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::FindGrep

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules, and the PATH variable to find the scripts (posy_one,
posy_static).

Therefore you will need to change:
your path, to include /home/fred/perl/script (where the script will be)

	PATH=/home/fred/perl/script:${PATH}

the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

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
