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

1;
