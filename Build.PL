use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::Slim',
    dist_abstract       => 'Perl implementation of the FitNesse SLiM protocol',
    license             => 'perl',
    dist_author         => q{Greg Bacon <gbacon@gbacon.com>},
    dist_version_from   => 'lib/Test/Slim.pm',
    configure_requires => {
        'Module::Build' => '0.20',
    },
    requires => {
        'perl'              => '5.10.0',
        'HTML::TreeBuilder' => '5.07',
    },
    build_requires => {
        'Test::More'          => '0.88',
        'Test::Exception'     => '0',
        'Test::Pod'           => '1.22',
        'Test::Pod::Coverage' => '1.08',
        'Pod::Text'           => '0',
        'HTTP::Tiny'          => '0.070',
    },
    script_files        => ['bin/perl-slim'],
    meta_add => {
        resources => {
            repository => 'https://github.com/gbacon/test-slim',
        },
    },
    add_to_cleanup      => [ 'test-slim-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
