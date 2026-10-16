#! perl

use strict;
use warnings;

use File::Temp qw(tempfile);
use lib 'lib';

use Test::More tests => 5;
use Test::Slim::Server;

my $server = Test::Slim::Server->new;

sub read_framed_file {
  my ($wire) = @_;
  my ($fh) = tempfile();
  binmode $fh;
  print {$fh} $wire or die "write temporary frame: $!";
  seek $fh, 0, 0 or die "rewind temporary frame: $!";
  my $message = $server->_read_message($fh);
  close $fh;
  return $message;
}

is(read_framed_file('000006:hello!'), 'hello!', 'reads a standard six-digit frame');

my $long_payload = 'x' x 1_000_000;
my $long_message = read_framed_file('1000000:' . $long_payload);
is(length($long_message), 1_000_000, 'reads a frame with a seven-digit byte length');
is(substr($long_message, 0, 1), 'x', 'long frame begins with its payload');
is(substr($long_message, -1), 'x', 'long frame contains the complete payload');

my $short = eval { read_framed_file('00001:x'); 1 };
ok(!$short && $@ =~ /at least six digits/, 'rejects a frame header shorter than six digits');

