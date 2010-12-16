package TestModule::TestSlim;

sub new {
  die "no arguments allowed" if @_ > 1;
  my($class) = @_;
  bless {} => $class;
}

1;
