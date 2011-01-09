package SpecialEchoSupport;

sub new {
  my($class) = @_;
  bless { ECHO_CALLED => 0 } => $class;
}

sub echo {
  my($self) = @_;
  $self->{ECHO_CALLED} = 1;
}

sub specialEchoSupportCalled {
  my($self) = @_;
  $self->{ECHO_CALLED} ? "true" : "false";
}

1;
