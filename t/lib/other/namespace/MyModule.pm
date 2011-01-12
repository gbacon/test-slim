package MyModule;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub sayHi { "hello" }

1;
