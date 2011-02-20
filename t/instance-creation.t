#! perl

use strict;
use warnings;

use lib "t/lib";

use File::Spec;
use Module::Build;
use Test::More tests => 14;

BEGIN {
  use_ok("Test::Slim::StatementExecutor")
    || BAIL_OUT("Cannnot use Test::Slim::StatementExecutor!");

  use_ok("Test::Slim::Statement")
    || BAIL_OUT("Cannnot use Test::Slim::Statement!");
}

my $caller;
sub test (&) {
  my($block) = @_;

  $caller = Test::Slim::StatementExecutor->new;

  $block->();
}

test {
  my $response = $caller->create("x", "TestModule::TestSlim", []);
  is($response, "OK", "create an instance");

  my $x = $caller->instance("x");
  is(ref($x), "TestModule::TestSlim");
};

test {
  my $response = $caller->create("x", "TestModule::TestSlimWithArguments", [3]);
  is($response, "OK", "create an instance with arguments");

  my $x = $caller->instance("x");
  is($x->arg, 3);
};

test {
  $caller->set_symbol("X", 3);

  my $response = $caller->create("x", "TestModule::TestSlimWithArguments", ['$X']);
  is($response, "OK", "create an instance with arguments that are symbols");

  my $x = $caller->instance("x");
  is($x->arg, 3);
};

test {
  $caller->set_symbol("X", "TestModule::TestSlim");
  is($caller->create("x", '$X', []), "OK", "create instance of class named in symbol");

  my $x = $caller->instance("x");
  is(ref $x, "TestModule::TestSlim", "created correct instance");
};

test {
  $caller->create("x", "TestModule::TestSlim", []);
  my $x = $caller->instance("x");

  $caller->set_symbol("X", $x);

  is($caller->create("y", '$X', []), "OK", "set actor from instance stored in symbol");

  my $y = $caller->instance("y");
  ok(defined $y && $y == $x, "x and y refer to same instance")
    or diag("x=$x; y=$y");
};

test {
  my $response = $caller->create("x", "TestModule::TestSlim", ["noSuchArgument"]);
  like($response, qr/^\Q${Test::Slim::Statement::EXCEPTION_TAG}\Emessage:<<COULD_NOT_INVOKE_CONSTRUCTOR TestModule::TestSlim\[1]/);
};

test {
  my $result = $caller->create("x", "TestModule::NoSuchClass", []);
  like($result, qr/\Q${Test::Slim::Statement::EXCEPTION_TAG}\Emessage:<<COULD_NOT_INVOKE_CONSTRUCTOR TestModule::NoSuchClass\b/,
    "can't create an instance if there is no class");
};
