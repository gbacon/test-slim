package PingFixture;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub canPing {
  my($self,$host) = @_;

  return "no" unless defined $host && length $host;

  my $pid = open my $fh, "-|";
  if (defined $pid) {
    if ($pid == 0) {
      open STDERR, ">&=", \*STDOUT or print("open: $!"), exit 1;
      exec "ping", "-c", 1, "-q", $host;
    }
    else {
      my $output = join "", <$fh>;
      close $fh ? "yes" : "no: $output";
    }
  }
  else {
    die "fork: $!";
  }
}

1;
