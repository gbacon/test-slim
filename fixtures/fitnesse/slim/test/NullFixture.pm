package NullFixture;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub getNull { undef }

sub getBlank { "" }

1;
