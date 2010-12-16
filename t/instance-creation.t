#! perl -T

use strict;
use warnings;

use lib "t/lib";

use File::Spec;
use Module::Build;
use Test::More tests => 10;

BEGIN {
  use_ok("Test::Slim::StatementExecutor")
    || BAIL_OUT("Cannnot use Test::Slim::StatementExecutor!");

  use_ok("Test::Slim::Statement") || BAIL_OUT("Cannnot use Test::Slim::Statement!");
}

{
  my $caller = Test::Slim::StatementExecutor->new;

  my $response = $caller->create("x", "TestModule::TestSlim", []);
  is($response, "OK", "create an instance");

  my $x = $caller->instance("x");
  is(ref($x), "TestModule::TestSlim");
}

{
  my $caller = Test::Slim::StatementExecutor->new;

  my $response = $caller->create("x", "TestModule::TestSlimWithArguments", [3]);
  is($response, "OK", "create an instance with arguments");

  my $x = $caller->instance("x");
  is($x->arg, 3);
}

{
  my $caller = Test::Slim::StatementExecutor->new;
  $caller->set_symbol("X", 3);

  my $response = $caller->create("x", "TestModule::TestSlimWithArguments", ['$X']);
  is($response, "OK", "create an instance with arguments that are symbols");

  my $x = $caller->instance("x");
  is($x->arg, 3);
}

{
  my $caller = Test::Slim::StatementExecutor->new;

  my $response = $caller->create("x", "TestModule::TestSlim", ["noSuchArgument"]);
  like($response, qr/^\Q${Test::Slim::Statement::EXCEPTION_TAG}\Emessage:<<COULD_NOT_INVOKE_CONSTRUCTOR TestModule::TestSlim\[1]/);
}

{
  my $caller = Test::Slim::StatementExecutor->new;

  my $result = $caller->create("x", "TestModule::NoSuchClass", []);
  like($result, qr/\Q${Test::Slim::Statement::EXCEPTION_TAG}\Emessage:<<COULD_NOT_INVOKE_CONSTRUCTOR TestModule::NoSuchClass\b/,
    "can't create an instance if there is no class");
}
