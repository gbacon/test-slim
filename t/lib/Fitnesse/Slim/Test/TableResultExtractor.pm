package Fitnesse::Slim::Test::TableResultExtractor;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub get_value_from_query_result_symbol {
  my($self,$symbol) = @_;
  $symbol;
}

sub get_value_from_table_result_symbol {
  my($self,$symbol) = @_;
  $symbol;
}

1;
