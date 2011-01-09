package EchoFixture;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class
}

sub echo {
  my($self,$s) = @_;
  $s;
}

sub setName {
  my($self,$name) = @_;
  $self->{NAME} = $name;
}

sub name {
  my($self) = @_;
  $self->{NAME};
}

1;
