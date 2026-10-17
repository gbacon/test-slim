package Test::Slim::ListExecutor;

use strict;
use warnings;

use Test::Slim::Statement;
use Test::Slim::StatementExecutor;

sub new {
  my($class,%options) = @_;
  my $executor = Test::Slim::StatementExecutor->new(%options);
  bless { EXECUTOR => $executor } => $class;
}

sub executor { $_[0]->{EXECUTOR} }

sub execute {
  my($self,@statements) = @_;
  $self->execute_with(undef, @statements);
}

sub execute_with {
  my($self,$after_statement,@statements) = @_;
  my $executor = $self->executor;
  my @results;
  for my $statement (@statements) {
    last if $executor->stop_requested;
    my $result = Test::Slim::Statement->execute($executor, @$statement);
    push @results, $result;
    $after_statement->($statement,$result) if $after_statement;
  }
  $executor->reset_stop_requested;
  @results;
}

1;
