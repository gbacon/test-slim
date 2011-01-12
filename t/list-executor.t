#! perl

use strict;
use utf8;
use warnings;

use File::Spec::Functions qw/ rel2abs /;
use Test::More tests => 40;

BEGIN {
  use_ok "Test::Slim::ListExecutor"
    or BAIL_OUT "Cannot use Test::Slim::ListExecutor!";

  use_ok "Test::Slim::StatementExecutor"
    or BAIL_OUT "Cannot use Test::Slim::StatementExecutor!";
}

my $executor;
my @statements;
my $table;
my @results;

sub add_statement { push @statements, [ @_ ] }

sub test(&) {
  my($block) = @_;

  $executor = Test::Slim::ListExecutor->new;
  @statements = ();
  $table = "<table><tr><td>name</td><td>bob</td></tr><tr><td>addr</td><td>here</td></tr></table>";
  add_statement "i1", "import", rel2abs "t/lib";
  add_statement "m1", "make", "test_slim", "TestModule::TestSlim";

  $block->();
}

sub get_result {
  my($id) = @_;
  my %resultof = map @$_, @results;
  $resultof{$id};
}

sub has_slim_exception {
  my($result,undef,$test_name) = @_;
  like($result, qr/^\Q$Test::Slim::Statement::EXCEPTION_TAG/, $test_name);
}

sub no_slim_exception {
  my($result,undef,$test_name) = @_;
  unlike($result, qr/\Q$Test::Slim::Statement::EXCEPTION_TAG/, $test_name);
}

sub expect_exception {
  my($pattern) = @_;

  sub {
    my($result,undef,$test_name) = @_;
    like($result,
         qr/\Q$Test::Slim::Statement::EXCEPTION_TAG\Emessage:<<$pattern/,
         $test_name);
  };
}

sub check_results {
  @results = $executor->execute(@statements);

  while (@_) {
    my($id,$expected,$test_name) = splice @_, 0, 3;

    my $check;
    if (ref $expected eq "ARRAY") {
      $check = \&is_deeply;
    }
    elsif (ref $expected eq "CODE") {
      $check = $expected;
    }
    else {
      $check = \&is;
    }

    $check->(get_result($id), $expected, $test_name);
  }
}

test {
  check_results "i1" => "OK", "can respond OK to import";
};

test {
  add_statement "inv1", "invalidOperation";

  my $invalid =
    expect_exception 'INVALID_STATEMENT: ' .
                     '\["inv1", "invalidOperation"]:.*>>$';

  check_results "inv1", $invalid, "can't execute an invalid operation";
};

test {
  # missing instance name after call instruction
  add_statement "id", "call", "notEnoughArguments";

  my $malformed =
    expect_exception "MALFORMED_INSTRUCTION " .
                     '\["id", "call", "notEnoughArguments"]>>';
  check_results "id" => $malformed, "can't execute a malformed instruction";
};

test {
  add_statement "id", "call", "no_such_instance", "no_such_method";
  my $no_instance = expect_exception 'NO_INSTANCE no_such_instance>>';
  check_results "id" => $no_instance, "can't call a method on an instance that doesn't exist";
};

test {
  my @results = $executor->execute();
  is(scalar(@results), 0, "should respond to an empty set of instructions with an empty set of results");
};

test {
  my @results = $executor->execute(["m1", "make", "instance", "testModule.TestSlim"]);
  is get_result("m1"), "OK", "can make an instance given a fully qualified name in dot format";
};

test {
  add_statement "id", "call", "test_slim", "return_string";
  check_results "m1" => "OK",     "construct instance for simple method",
                "id" => "string", "can call a simple method";
};

test {
  add_statement "id", "call", "test_slim", "return_unicode_value";
  check_results "m1" => "OK",      "make instance before utf8 call",
                "id" => "Español", "Unicode result"
};

test {
  add_statement "id", "call", "test_slim", "returnString";
  check_results "m1" => "OK",     "make for FitNesse-form call",
                "id" => "string", "can call a simple method in FitNesse form";
};

test {
  unshift @statements, ["i2", "import", "TestModule.ShouldNotFindTestSlimInHere"];
  add_statement "id", "call", "test_slim", "return_string";
  check_results "m1" => "OK",     "later-import make",
                "id" => "string", "later imports take precendence";
};

test {
  add_statement "m2", "make", "test_slim_2", "TestModule.TestSlimWithArguments", "3";
  add_statement "c1", "call", "test_slim_2", "arg";

  check_results "m2" => "OK", "make with arg for constructor",
                "c1" => "3",  "can pass arguments to constructor";
};

test {
  add_statement "m2", "make", "test_slim_2", "TestModule::TestSlimWithArguments", $table;
  add_statement "c1", "call", "test_slim_2", "name";
  add_statement "c2", "call", "test_slim_2", "addr";

  check_results "m2" => "OK",   "pass table to constructor",
                "c1" => "bob",  "call to name after passing table to constructor",
                "c2" => "here", "call to addr after passing table to constructor";
};

test {
  add_statement "m2", "make", "test_slim_2", "TestModule.TestSlimWithArguments", "nil";
  add_statement "c0", "call", "test_slim_2", "set_arg", $table;
  add_statement "c1", "call", "test_slim_2", "name";
  add_statement "c2", "call", "test_slim_2", "addr";

  check_results
    "m2" => "OK",                "table to func: constructor",
    "c0" => \&no_slim_exception, "table to func: no exception when passing table",
    "c1" => "bob",               "table to func: call name",
    "c2" => "here",              "table to func: call addr";
};

test {
  add_statement "c1", "call", "test_slim", "add", "x", "y";
  add_statement "c2", "call", "test_slim", "add", "a", "b";
  check_results "c1" => "xy", "first call to add",
                "c2" => "ab", "can call a function more than once";
};

test {
  add_statement "id1", "callAndAssign", "v", "test_slim", "add", "x", "y";
  add_statement "id2", "call", "test_slim", "echo", '$v';
  check_results "id1" => "xy", "callAndAssign returns assigned value",
                "id2" => "xy", "assign the return value to a symbol";
};

test {
  add_statement "id1", "callAndAssign", "v1", "test_slim", "echo", "Bob";
  add_statement "id2", "callAndAssign", "v2", "test_slim", "echo", "Martin";
  add_statement "id3", "call", "test_slim", "echo", 'name: $v1 $v2';
  check_results "id3" => "name: Bob Martin", "replace multiple symbols in a single argument";
};

test {
  add_statement "id3", "call", "test_slim", "echo", '$v1';
  check_results "id3" => '$v1', q(ignore '$' if what follows is not a symbol);
};

test {
  my $l = [ qw/ 1 2 / ];
  add_statement "id", "call", "test_slim", "echo", $l;
  check_results "id" => $l, "can pass and return a list";
};

test {
  add_statement "id1", "callAndAssign", "v", "test_slim", "echo", "x";
  add_statement "id2", "call", "test_slim", "echo", ['$v'];
  check_results "id2" => ["x"], "pass a symbol in a list";
};

test {
  add_statement "id", "call", "test_slim", "null";
  check_results "id" => undef, "can return the undefined value";
};

test {
  add_statement "id", "call", "test_slim", "die_inside";

  my $call_target_found = sub {
    my($result,undef,$test_name) = @_;
    unlike($result, qr/NO_METHOD_IN_CLASS/, $test_name);
  };

  check_results "id", \&has_slim_exception, "survive a call to die",
                "id", $call_target_found,   "make sure we find die_inside";
};

test {
  my $no_meth = sub {
    my($result,undef,$test_name) = @_;
    like($result, qr/NO_METHOD_IN_CLASS/, $test_name);
  };

  add_statement "id", "call", "test_slim", "does_not_exist";
  check_results "id", $no_meth, "should throw NO_METHOD_IN_CLASS";
};

sub no_invoke {
  my($result,undef,$test_name) = @_;
  like($result, qr/COULD_NOT_INVOKE_CONSTRUCTOR/, $test_name);
}

test {
  add_statement "id", "make", "my_inst", "testModule.TestSlim.Undef";
  check_results "id", \&no_invoke, "undefined result should throw exception";
};

test {
  my $correct_location = sub {
    my($result,undef,$test_name) = @_;
    like($result, qr/\bt\/lib\/TestModule\/TestSlim\/Die\.pm line 3\./, $test_name);
  };

  add_statement "id", "make", "my_inst", "TestModule.TestSlim.Die";
  check_results "id", \&no_invoke, "die in new should throw exception";
  check_results "id", $correct_location, "die in new should throw exception";
}
