package TestModule::TestSlimWithArguments;

sub new {
  my($class,$arg) = @_;
  bless { ARG => $arg } => $class;
}

sub arg {
  my($self) = @_;
  $self->{ARG};
}

1;
