package Test::Slim::Statement;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub slim_to_perl_class {
  my($self,$name) = @_;
  join "::" => map "\u$_", split /\.|::/, $name;
}

sub slim_to_perl_method {
  my($self,$name) = @_;
  $name =~ s/([A-Z])/_\l$1/g;
  $name;
}

1;
