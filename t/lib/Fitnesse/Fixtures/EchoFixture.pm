package Fitnesse::Fixtures::EchoFixture;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub echo {
  my($self,$arg) = @_;
  $arg;
}

sub echo_string {
  my($self,$arg) = @_;
  "library:$arg";
}

1;
