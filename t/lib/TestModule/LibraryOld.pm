package TestModule::LibraryOld;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub method_on_library_old { "library_old method" }

sub a_method { "a_method in library_old" }

1;
