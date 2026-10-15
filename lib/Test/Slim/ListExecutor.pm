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
  my $executor = $self->executor;
  my @results;
  for my $statement (@statements) {
    last if $executor->stop_requested;
    push @results, Test::Slim::Statement->execute($executor, @$statement);
  }
  $executor->reset_stop_requested;
  @results;
}

1;
