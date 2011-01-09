package PageDriver;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class
}

sub sendAsHash {
  my($self,$hash) = @_;
  $self->{HASH} = $hash;
}

sub hashIs {
  my($self,$key) = @_;
  return $self->{HASH}{$key};
}

1;
