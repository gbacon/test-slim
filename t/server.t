#! perl

use strict;
use utf8;
use warnings;

use IO::Handle;
use Socket;

use Test::More tests => 8;

BEGIN {
  use_ok "Test::Slim::Server"
    or BAIL_OUT "cannot use Test::Slim::Server";
}

my($slim,$fitnesse);
my $server;
sub test (&) {
  my($block) = @_;

  socketpair $slim, $fitnesse, AF_UNIX, SOCK_STREAM, PF_UNSPEC
    or BAIL_OUT "socketpair failed: $!";

  $_->autoflush(1) for $slim, $fitnesse;

  $server = Test::Slim::Server->new
    or BAIL_OUT "failed to instantiate server";

  $block->();

  for ($slim, $fitnesse) {
    close $_;
    undef $_;
  }
}

test {
  print $fitnesse "000003:bye";
  $fitnesse->flush;

  $server->process($slim);

  my $reply = <$fitnesse>;
  is $reply, "Slim -- V0.3\n", "proper Slim greeting";
};

test {
  my $import = "000074:[000001:000057:[000003:000010:import_0_0:000006:import:000008:MyModule:]:]";

  print $fitnesse $import . "000003:bye";
  $fitnesse->flush;

  $server->process($slim);

  my @replies = <$fitnesse>;

  my $ok = Test::Slim::List->new([qw/ import_0_0 OK /])->serialize;
  my @expected = (
    "Slim -- V0.3\n",
    "000054:[000001:000037:[000002:000010:import_0_0:000002:OK:]:]",
    #sprintf("%06d:%s", length $ok, $ok),
  );
  is_deeply \@replies, \@expected, "process import command";
};

test {
  my $badmake = "000102:[000001:000085:[000004:000015:scriptTable_1_0:000004:make:000016:scriptTableActor:000009:MyFixture:]:]";

  print $fitnesse $badmake . "000003:bye";
  $fitnesse->flush;

  $server->process($slim);

  my @replies = <$fitnesse>;

  is $replies[0], "Slim -- V0.3\n";

  my @exception = Test::Slim::List->new(substr $replies[1], 7)->list;
  is   $exception[0][0], "scriptTable_1_0";
  like $exception[0][1], qr/^__EXCEPTION__:message:<<COULD_NOT_INVOKE_CONSTRUCTOR MyFixture\b.*>>$/;

  is scalar    @exception,      1, "length of exception list";
  is scalar @{ $exception[0] }, 2, "length of exception sublist";
};
