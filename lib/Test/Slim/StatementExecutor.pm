package Test::Slim::StatementExecutor;

use strict;
use warnings;

use Test::Slim::Statement;

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
  eval { require $self->path_to_class($class) };
  return $class unless $@;
  die "message:<<COULD_NOT_INVOKE_CONSTRUCTOR $class: $@>>";
}

sub create {
  my($self,$id,$class,$args) = @_;

  eval {
    $self->require($class);
    $self->construct_instance($id,$class,$args);
  };
  return "OK" unless $@;

  $Test::Slim::Statement::EXCEPTION_TAG . $@;
}

sub construct_instance {
  my($self,$id,$class,$args) = @_;

  eval {
    $self->{instance}{$id} = $class->new($self->replace_symbols(@$args));
  };
  return $self->{instance}{$id} unless $@;

  my $n = @$args;
  die "message:<<COULD_NOT_INVOKE_CONSTRUCTOR $class\[$n]: $@>>";
}

sub replace_symbols {
  my($self,@args) = @_;
  map /^\$(\w+)$/ ? $self->get_symbol($1) : $_, @args;
}

sub instance {
  my($self,$id) = @_;

  $self->{instance}{$id};
}

sub set_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol} = $value;
}

sub get_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol};
}

1;
