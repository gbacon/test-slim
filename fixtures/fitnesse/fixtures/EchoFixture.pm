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

1;
