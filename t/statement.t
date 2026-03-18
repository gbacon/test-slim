#! perl -T

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
  use_ok("Test::Slim::Statement") || BAIL_OUT("Cannot use Test::Slim::Statement!");
}
