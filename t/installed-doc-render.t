use strict;
use warnings;

use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use lib "$Bin/lib";
use Test::More;
use Test::Slim::InstallDocumentation qw(render_installed_pod);

my $private = tempdir('test-slim-private-pod-XXXXXX', TMPDIR => 1, CLEANUP => 1);
chmod 0700, $private or die "chmod private POD root: $!";
my $module_dir = "$private/lib/perl5/Test";
make_path($module_dir);
my $installed_pod = "$module_dir/Slim.pm";
copy("$Bin/../lib/Test/Slim.pm", $installed_pod)
  or die "copy POD into private installation prefix: $!";
chmod 0644, $installed_pod or die "chmod installed POD: $!";

my $rendered = eval { render_installed_pod($installed_pod) };
ok(defined $rendered, 'Pod::Text renders documentation in a private install prefix')
  or diag $@;
like($rendered, qr/FitNesse/, 'rendered text comes from installed Test::Slim POD');

my $missing = "$module_dir/Missing.pm";
my $ok = eval { render_installed_pod($missing); 1 };
ok(!$ok, 'missing installed documentation is rejected');
like($@, qr/installed POD file is missing/, 'missing documentation has a distinct diagnostic');

done_testing;
