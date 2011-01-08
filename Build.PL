use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::Slim',
    license             => 'perl',
    dist_author         => q{Greg Bacon <gbacon@dbresearch.net>},
    dist_version_from   => 'lib/Test/Slim.pm',
    build_requires => {
        'perl'              => '5.10.0',
        'Getopt::Long'      => 0,
        'HTML::TreeBuilder' => 0,
        'Module::Build'     => '>= 0.20',
        'Test::More'        => 0,
        'Text::CharWidth'   => 0,
    },
    add_to_cleanup      => [ 'test-slim-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
