package Fitnesse::Slim::Test::TestQuery;

sub new {
  my($class,$n) = @_;
  bless {n => $n} => $class;
}

sub clone_symbol {
  my($self,$symbol) = @_;
  $symbol;
}

sub echo {
  my($self,$string) = @_;
  $string;
}

sub free_symbol {
  my($self,$symbol) = @_;
  $symbol;
}

sub query {
  my($self) = @_;
#   [
#     [[n => 1],  ["2n" => 2]],
#     [[n => 2],  ["2n" => 4]],
#   ];
  [ map { [[n => $_], ["2n" => 2 * $_]] } 1 .. $self->{n} ];
}

1;
