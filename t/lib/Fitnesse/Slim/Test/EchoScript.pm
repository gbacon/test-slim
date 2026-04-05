package Fitnesse::Slim::Test::EchoScript;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub echo {
  my($self,$s) = @_;
  $s;
}

1;
