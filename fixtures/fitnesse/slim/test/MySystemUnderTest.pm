package MySystemUnderTest;

use strict;
use warnings;

sub new {
  my($class) = @_;
  my $self = {
    CALLED => 0,
  };
  bless $self => $class;
}

sub bar {
  my($self) = @_;
  $self->{CALLED} = 1;
}

sub systemUnderTestCalled {
  my($self) = @_;
  $self->{CALLED} ? "true" : "false";
}

1;
