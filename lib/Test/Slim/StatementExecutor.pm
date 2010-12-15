package Test::Slim::StatementExecutor;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub path_to_class {
  my($self,$name) = @_;
  $name =~ s!::!/!g;
  $name . ".pm";
}

sub require {
  my($self,$class) = @_;

  defined eval { require $self->path_to_class($class) }
    or die "message:<<COULD_NOT_INVOKE_CONSTRUCTOR $class: $@>>";
}

1;
