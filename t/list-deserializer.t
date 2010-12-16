#! perl -T

use strict;
use utf8;
use warnings;

use Encode qw/ decode is_utf8 /;

use Test::More tests => 13;

my $have_test_exception;
BEGIN {
  use_ok("Test::Slim::List") || BAIL_OUT("Cannot use Test::Slim::List!");
  eval "use Test::Exception";
  $have_test_exception = $@ ? 0 : 1;
}

SKIP: {
  skip "Test::Exception not installed", 5 unless $have_test_exception;

  throws_ok { Test::Slim::List->new(undef)->list }
    qr/cannot deserialize undefined value/, "can't deserialize undefined value";

  throws_ok { Test::Slim::List->new("")->list }
    qr/cannot deserialize empty string/, "can't deserialize empty string";

  throws_ok { Test::Slim::List->new("hello")->list }
    qr/syntax error\b.*missing open bracket/,
    "can't deserialize string that doesn't start with an open bracket";

  throws_ok { Test::Slim::List->new("[000000:")->list }
    qr/syntax error\b.*missing close bracket/,
    "can't deserialize string that doesn't end with a bracket";

  throws_ok { Test::Slim::List->new(<<EOF)->list }
[000002:000119:[000006:000015:scriptTable_3_0:000004:call:000016:scriptTableActor:000005:setTo:000015:System\\Language:000007:Espa\361ol:]:000033:[000002:000005:hello:000003:bob:]:]
EOF
    qr/cannot deserialize non-UTF-8 encoding/,
    "bad Unicode character";
}

sub check_round_trip {
  my($l,$name) = @_;
  @$l = map is_utf8($_) ? $_ : decode("UTF-8", $_, 1), @$l;
  my $serialized = Test::Slim::List->new($l)->serialize;
  my $deserialized = [ Test::Slim::List->new($serialized)->list ];
  is_deeply $deserialized, $l, $name;
}

check_round_trip [], "empty list";

check_round_trip ["hello"], "one-element list";

check_round_trip [qw/ hello bob /], "two-element list";

check_round_trip ["hello", [qw/ bob micah /], "today"], "sublists";

check_round_trip ["Köln"], "deserialize list with multibyte char";

check_round_trip ["Kö"],
  "deserialize list with string that ends with multibyte char";

check_round_trip ["123456789012345", "Espa\303\261ol"],
  "deserialize list with UTF-8";
