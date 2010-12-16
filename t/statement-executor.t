#! perl -T

use strict;
use warnings;

use Test::More tests => 3;

my $have_test_exception;
BEGIN {
  use_ok("Test::Slim::StatementExecutor")
    || BAIL_OUT("Cannot use Test::Slim::StatementExecutor!");
  eval "use Test::Exception";
  $have_test_exception = $@ ? 0 : 1;
}

my $executor = Test::Slim::StatementExecutor->new;

is($executor->path_to_class("Foo::Bar::Baz"), "Foo/Bar/Baz.pm", "path_to_class");

SKIP: {
  skip "Text::Exception not installed", 1 unless $have_test_exception;

  throws_ok { $executor->require("Foo::Bar::Baz") }
    qr/message:<<COULD_NOT_INVOKE_CONSTRUCTOR Foo::Bar::Baz\b/,
    "require a class";
}
