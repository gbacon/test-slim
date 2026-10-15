package Test::Slim::SlimHelperLibrary;

use strict;
use warnings;

sub new {
  my($class,$instances) = @_;
  bless {
    instances => $instances,
    stack     => [],
  } => $class;
}

sub get_fixture {
  my($self) = @_;
  my $fixture = $self->{instances}{scriptTableActor};
  die "NO_INSTANCE scriptTableActor." unless defined $fixture;
  $fixture;
}

sub push_fixture {
  my($self) = @_;
  push @{ $self->{stack} }, $self->get_fixture;
  return;
}

sub pop_fixture {
  my($self) = @_;
  die "EmptyStackException" unless @{ $self->{stack} };
  $self->{instances}{scriptTableActor} = pop @{ $self->{stack} };
  return;
}

1;
