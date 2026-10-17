#! perl

use strict;
use warnings;

use IO::Socket::INET;
use IPC::Open3;
use POSIX qw(WNOHANG);
use Symbol qw(gensym);
use Test::More;

sub unused_port {
  my $socket = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1', LocalPort => 0,
    Proto => 'tcp', Listen => 1, ReuseAddr => 1,
  ) or die "allocate test port: $!";
  my $port = $socket->sockport;
  close $socket;
  return $port;
}

my $error = gensym;
my $pid = open3(my $input,my $output,$error,
  $^X,'-Ilib','-It/lib','bin/perl-slim','-x','1');
close $input;
my $stdout = do { local $/; <$output> // '' };
my $stderr = do { local $/; <$error> // '' };
waitpid($pid,0);
ok(($? >> 8) != 0,'unknown runner flags are rejected');
like($stderr,qr/Usage: .*perl-slim/,'invalid invocation explains supported arguments');
is($stdout,'','invalid invocation writes no protocol bytes to stdout');

for my $arguments (['-s','0','1'],['-s','1'],['-s','1','-s','2','1']) {
  $error = gensym;
  $pid = open3($input,$output,$error,
    $^X,'-Ilib','-It/lib','bin/perl-slim',@$arguments);
  close $input;
  my $invalid_error = do { local $/; <$error> // '' };
  waitpid($pid,0);
  isnt($? >> 8,0,'invalid -s argument is rejected');
  like($invalid_error,qr/Usage: .*perl-slim/,'invalid -s argument reports usage');
}

my $port = unused_port();
$error = gensym;
$pid = open3($input,$output,$error,
  $^X,'-Ilib','-It/lib','bin/perl-slim','-v','-s','1',"$port");
binmode $_ for ($input,$output,$error);
my $socket;
my $deadline = time + 5;
while (time < $deadline) {
  $socket = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1', PeerPort => $port, Proto => 'tcp', Timeout => 0.2,
  );
  last if $socket;
  select undef,undef,undef,0.02;
}
ok($socket,'-v -s 1 port starts a TCP listener');
if ($socket) {
  local $/ = "\n";
  is(<$socket>,"Slim -- V0.5\n",'TCP listener sends the pinned FitNesse v0.5 greeting');
  syswrite($socket,'000003:bye');
  close $socket;
}
kill 'TERM',$pid;
waitpid($pid,0);
is($? & 127,15,'TCP CLI process is explicitly reaped after handshake verification');

done_testing;
