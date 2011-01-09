package TestModule::LibraryNew;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub method_on_library_new { "library_new method" }

sub a_method { "a_method in library_new" }

1;
