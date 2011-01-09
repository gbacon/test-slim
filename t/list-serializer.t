#! perl -T

use strict;
use utf8;
use warnings;

my @tests;
BEGIN {
  @tests = (
    [ "serialize an empty list",
      [],
      "[000000:]",
    ],

    [ "serialize a one-item list",
      ["hello"],
      "[000001:000005:hello:]",
    ],

    [ "serialize a two-item list",
      [qw/ hello world /],
      "[000002:000005:hello:000005:world:]",
    ],

    [ "serialize a nested list",
      [["element"]],
      "[000001:000024:[000001:000007:element:]:]",
    ],

    [ "serialize a list with a non-string",
      [1],
      "[000001:000001:1:]",
    ],

    [ "serialize an undefined element",
      [undef],
      "[000001:000004:null:]",
    ],

    [ "serialize a string with multibyte chars",
      ["Köln"],
      "[000001:000004:K\303\266ln:]",
    ],

    [ "serialize a string with UTF8",
      ["Espa\303\261ol"],
      "[000001:000007:Espa\303\261ol:]",
    ],

    [ "serialize a string with a trailing newline",
      ["foo\n"],
      "[000001:000004:foo\n:]",
    ],

    [ "nested list with multibyte characters",
      [[qw/ decisionTable_28_9 Köln /]],
      "[000001:000047:[000002:000018:decisionTable_28_9:000004:Köln:]:]",
    ],
  );
}

use Test::More tests => @tests + 1;

BEGIN { use_ok("Test::Slim::List") || BAIL_OUT("Cannot use Test::Slim::List!") }

for (@tests) {
  use bytes;
  my($test_name,$input,$expected) = @$_;
  ok(Test::Slim::List->new($input)->serialize eq $expected, $test_name);
}
