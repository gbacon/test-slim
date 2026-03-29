#! perl

use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 3;

BEGIN {
  use_ok "Test::Slim::StatementExecutor"
    or BAIL_OUT "Cannnot use Test::Slim::StatementExecutor!";

  use_ok "Test::Slim::Statement"
    or BAIL_OUT "Cannnot use Test::Slim::Statement!";
}

my $executor = Test::Slim::StatementExecutor::->new;

is_deeply(
  Test::Slim::Statement::->execute($executor, "i1", "import", "fitnesse.slim.test"),
  ["i1" => "OK"],
  "import fitnesse.slim.test"
);
