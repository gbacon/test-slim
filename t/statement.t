#! perl -T

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
  use_ok("Test::Slim::Statement") || BAIL_OUT("Cannot use Test::Slim::Statement!");
}

my $statement = Test::Slim::Statement->new;
is "my_method", $statement->slim_to_perl_method("myMethod");
