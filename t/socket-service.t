#! perl -T

use strict;
use utf8;
use warnings;

use Encode qw/ is_utf8 /;

use Test::More tests => 9;

BEGIN {
  use_ok "Test::Slim::SocketService"
    or BAIL_OUT "cannot use Test::Slim::SocketService";
}

my $ss;
sub test (&) {
  my($block) = @_;
  $ss = Test::Slim::SocketService->new;
  $block->();
}

sub check_round_trip {
  my($original,$expected_bytes) = @_;

  my $encoded = $ss->utf8_encode($original);

  { use bytes;
    ok $encoded eq $expected_bytes, "$original: encode";
  }
  ok !is_utf8($encoded), "$original: UTF8 flag should be off after encoding";

  my $decoded = $ss->utf8_decode($encoded);
  is $decoded, $original, "$original: encode/decode round trip";
  ok is_utf8($decoded), "$original: UTF8 flag should be on after decoding";
}

test {
  check_round_trip "[000001:000004:Köln:]" =>
                   "[000001:000004:K\303\266ln:]";
};

test {
  check_round_trip "[000001:000007:Español:]" =>
                   "[000001:000007:Espa\303\261ol:]";
};
