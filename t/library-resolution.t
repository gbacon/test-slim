#! perl

use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 5;

BEGIN {
  use_ok "Test::Slim::StatementExecutor"
    or BAIL_OUT "Cannot use Test::Slim::StatementExecutor!";

  use_ok "Test::Slim::Statement"
    or BAIL_OUT "Cannot use Test::Slim::Statement!";
}

my $executor = Test::Slim::StatementExecutor->new;
$executor->add_import("fitnesse.slim.test");
$executor->add_import("fitnesse.fixtures");

is_deeply(
  Test::Slim::Statement->execute($executor, "m1", "make", "actor", "TestSlim"),
  [ "m1" => "OK" ],
  "make actor"
);

is_deeply(
  Test::Slim::Statement->execute($executor, "m2", "make", "library1", "EchoFixture"),
  [ "m2" => "OK" ],
  "make library fixture"
);

is_deeply(
  Test::Slim::Statement->execute($executor, "c1", "call", "actor", "echo", "hello"),
  [ "c1" => "hello" ],
  "call resolves through library fixture when actor lacks method"
);
