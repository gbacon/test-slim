package Fitnesse::Fixtures::HashFixture;

sub new {
  my($class) = @_;
  bless { HASH => undef } => $class;
}

sub hash {
  my($self) = @_;
  $self->{HASH};
}

sub send_as_hash {
  my($self,$hash) = @_;
  $self->{HASH} = $hash;
}

1;
