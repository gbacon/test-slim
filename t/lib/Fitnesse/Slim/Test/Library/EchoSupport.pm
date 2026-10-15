package Fitnesse::Slim::Test::Library::EchoSupport;

sub new {
  my($class) = @_;
  bless { echo_called => 0 } => $class;
}

sub echo {
  my($self) = @_;
  $self->{echo_called} = 1;
  return;
}

sub echo_support_called {
  my($self) = @_;
  $self->{echo_called} ? "true" : "false";
}

1;
