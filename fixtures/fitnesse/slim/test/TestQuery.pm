package TestQuery;

use strict;
use warnings;

sub new {
  my($class,$n) = @_;
  bless { n_ => $n }, $class;
}

sub n {
  my($self) = @_;
  $self->{n_};
}

sub query {
  my($self) = @_;
  my $n = $self->n;

  [ map [ [ "n", $_ ], [ "2n", 2 * $_ ] ], 1 .. $n ];
}

1;
