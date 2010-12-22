#! perl -T

use strict;
use threads;
use threads::shared;
use utf8;
use warnings;

use Test::More tests => 2;

use Socket;
use Time::HiRes qw/ usleep /;

BEGIN {
  use_ok "Test::Slim::SocketService"
    or BAIL_OUT "cannot use Test::Slim::SocketService";
}

my $port;
my $ss;
my $connections : shared;

sub test(&) {
  my($block)= @_;

  $port = 1024 + int rand 64_000;
  $ss = Test::Slim::SocketService->new;
  $connections = 0;

  $block->();
}

sub talk {
  my($port) = @_;

  socket my $s, PF_INET, SOCK_STREAM, getprotobyname "tcp"
    or die "$0: socket: $!";

  connect $s, sockaddr_in $port, inet_aton "localhost"
    or die "$0: connect: $!";

  usleep 100_000;

  close $s
    or die "$0: close: $!";
}

test {
  $ss->serve($port, sub { ++$connections });
  talk $port;
  $ss->close;
  is($connections, 1, "single connection");
};

test {
  $ss->serve($port, sub { ++$connections });
  #talk $port for 1 .. 10;
  #talk $port;
  talk $port;
  $ss->close;
  is($connections, 10, "ten connections");
}
