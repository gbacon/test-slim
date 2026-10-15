package Fitnesse::Slim::Test::EchoScript;

use strict;
use warnings;
use Encode qw(encode_utf8);

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub echo {
  my($self,$s) = @_;
  $s;
}

sub echo_to_stdout {
  my($self,$s) = @_;
  print encode_utf8($s), "\n";
  return $s;
}

sub echo_to_stderr {
  my($self,$s) = @_;
  print STDERR encode_utf8($s), "\n";
  return $s;
}

1;
