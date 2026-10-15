#! perl

use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 9;

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

is_deeply(
  Test::Slim::Statement->execute($executor, "c2", "call", "actor", "echo_string", "actor"),
  [ "c2" => "actor" ],
  "actor method takes precedence over a library method"
);

is_deeply(
  Test::Slim::Statement->execute($executor, "m3", "make", "library2", "NewEchoFixture"),
  [ "m3" => "OK" ],
  "make a second library fixture"
);

is_deeply(
  Test::Slim::Statement->execute($executor, "c3", "call", "actor", "echo", "newest"),
  [ "c3" => "new:newest" ],
  "most recently registered library takes precedence"
);

is_deeply(
  Test::Slim::Statement->execute($executor, "c4", "call", "actor", "no_such_method"),
  [ "c4" => "__EXCEPTION__:message:<<NO_METHOD_IN_CLASS no_such_method[0] Fitnesse::Slim::Test::TestSlim>>" ],
  "missing method reports the actor class after searching libraries"
);
