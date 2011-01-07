package TestSlim;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub setStringx {
  my($self,$string) = @_;
  $self->{STRING} = $string;
}

sub getStringArg {
  my($self,$string) = @_;
  $self->{STRING};
}

sub echoString {
  my($self,$string) = @_;
  $string;
}

1;
