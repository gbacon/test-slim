#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Test::Slim' ) || print "Bail out!
";
}

diag( "Testing Test::Slim $Test::Slim::VERSION, Perl $], $^X" );
