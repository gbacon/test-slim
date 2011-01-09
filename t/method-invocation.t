#! perl

use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 16;

BEGIN {
  use_ok "Test::Slim::StatementExecutor"
    or BAIL_OUT "Cannot use Test::Slim::StatementExecutor!";

  use_ok "Test::Slim::Statement"
    or BAIL_OUT "Cannot use Test::Slim::Statement!";
}

my $executor;

sub test(&) {
  my($block) = @_;

  $executor = Test::Slim::StatementExecutor->new;
  $executor->create("test_slim",   "TestModule::TestSlim",   []);
  $executor->create("library_old", "TestModule::LibraryOld", []);
  $executor->create("library_new", "TestModule::LibraryNew", []);

  $block->();
}

test {
  eval { $executor->call("test_slim", "no_args") };
  is($@, "", "can call a method with no arguments");
};

test {
  my $result = $executor->call("test_slim", "no_such_method");
  like($result, qr/\Q$Test::Slim::Statement::EXCEPTION_TAG\E
                   message:<<NO_METHOD_IN_CLASS  \s+
                   no_such_method\[0]            \s+
                   TestModule::TestSlim>>/x,
    "can't call a method that doesn't exist");
};

test {
  is($executor->call("test_slim", "return_value"), "arg", "can call a method that returns a value");
};

TODO: {
  local $TODO = "FIXME";

  test {
    my $val = $executor->call("test_slim", "return_unicode_value");
    { use bytes;
      ok($val eq "Espa\357\277\275ol", "can call a method that returns a Unicode value");
    }
  };
}

test {
  eval { $executor->call("test_slim", "one_arg", "arg") };
  is($@, "", "can call a method that takes one argument");
};

test {
  my $result = eval { $executor->call("test_slim", "one_arg", qw/ 1 2 /) };
  is($@, "", "executor call should trap exceptions");
  like($result, qr/\Q$Test::Slim::Statement::EXCEPTION_TAG/,
    "exception in method should become SLiM exception");
};

test {
  my $result = $executor->call("no_such_instance", "no_such_method", "arg");
  like($result,
       qr/\Q$Test::Slim::Statement::EXCEPTION_TAG\E
          message:<<NO_INSTANCE  \s+  no_such_instance>>/x,
       "can't call a method on an instance that doesn't exist");
};

test {
  $executor->set_symbol("v", "bob");
  is($executor->call("test_slim", "echo", 'hi $v.'), "hi bob.",
    "can replace symbol expressions with their values");
};

test {
  is($executor->call("test_slim", "sut_method"), "hi from the sut",
     "can call a method on the system under test");
};

test {
  is($executor->call("test_slim", "method_on_library_old"),
     "library_old method",
     "call a specific method on library_old");
};

test {
  is($executor->call("test_slim", "method_on_library_new"),
     "library_new method",
     "call a specific method on library_new");
};

test {
  is($executor->call("test_slim", "a_method"),
     "a_method in library_new",
     "prefer methods in library_new");
};

test {
  is($executor->call("bogus_instance", "a_method"),
     "a_method in library_new",
     "can call library method with null instance");
};
