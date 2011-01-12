#! perl -T

use strict;
use warnings;

my @cases;
BEGIN {
  @cases = (
    [ qw/ slim_to_perl_class   MyPackage.MyClass   MyPackage::MyClass / ],
    [ qw/ slim_to_perl_class   this.that::TheOther this::that::TheOther / ],
  );
}

use Test::More tests => @cases + 1;

BEGIN {
  use_ok("Test::Slim::Statement") || BAIL_OUT("Cannot use Test::Slim::Statement!");
}

for (@cases) {
  my($method,$arg,$expected) = @$_;

  my $statement = Test::Slim::Statement->new;
  is($statement->$method($arg), $expected, "$arg -> $expected");
}
