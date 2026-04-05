package Fitnesse::Fixtures::EchoFixture;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub echo {
  my($self,$arg) = @_;
  $arg;
}

1;
