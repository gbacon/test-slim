package Test::Slim::HelperLibrary;

use strict;
use warnings;

use constant ACTOR_INSTANCE_NAME => "scriptTableActor";

sub new {
  my($class,$exec) = @_;
  bless { EXEC => $exec, FIXTURE => [] }, $class;
}

sub getFixture {
  my($self) = @_;
  $self->{EXEC}->instance(ACTOR_INSTANCE_NAME);
}

sub pushFixture {
  my($self) = @_;
  push @{ $self->{FIXTURE} }, $self->getFixture;
}

sub popFixture {
  my($self) = @_;
  my $actor = pop @{ $self->{FIXTURE} };
  $self->{EXEC}->set_instance(ACTOR_INSTANCE_NAME, $actor);
}

1;
