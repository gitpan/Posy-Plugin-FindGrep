use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Posy::Plugin::FindGrep',
    license             => 'perl',
    dist_author         => 'Kathryn Andersen',
    dist_version_from   => 'lib/Posy/Plugin/FindGrep.pm',
	requires            => {
	'Posy' => 0.72,
	},
    build_requires => {
        'Test::More' => 0,
    },
);

$builder->create_build_script();
