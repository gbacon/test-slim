package MyFixture;

use strict;
use warnings;

our $Greeting = "howdy!";

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub sayHello { $Greeting }

1;
