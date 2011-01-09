package TestSlim;

use strict;
use warnings;

sub new {
  my($class,$arg) = @_;
  bless { ARG => $arg } => $class;
}

sub echoInt {
  my($self,$i) = @_;
  $i;
}

sub returnConstructorArg {
  my($self) = @_;
  $self->{ARG};
}

sub setString {
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
