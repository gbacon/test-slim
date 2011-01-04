package Test::Slim::ListExecutor;

use strict;
use warnings;

use Test::Slim::Statement;
use Test::Slim::StatementExecutor;

sub new {
  my($class) = @_;
  my $executor = Test::Slim::StatementExecutor->new;
  bless { EXECUTOR => $executor } => $class;
}

sub executor { $_[0]->{EXECUTOR} }

sub execute {
  my($self,@statements) = @_;
  map Test::Slim::Statement->execute($self->executor, @$_), @statements;
}

1;
