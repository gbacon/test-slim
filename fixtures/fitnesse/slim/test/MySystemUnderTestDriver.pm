package MySystemUnderTestDriver;

use strict;
use warnings;

use MySystemUnderTest;

sub new {
  my($class) = @_;

  my $self = {
    CALLED => 0,
    SUT    => MySystemUnderTest->new,
  };

  bless $self => $class;
}

sub sut {
  my($self) = @_;
  $self->{SUT};
}

sub foo {
  my($self) = @_;
  $self->{CALLED} = 1;
}

sub driverCalled {
  my($self) = @_;
  $self->{CALLED} ? "true" : "false";
}

1;
