package SystemUnderTest;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub sut_method { "hi from the sut" }

1;
