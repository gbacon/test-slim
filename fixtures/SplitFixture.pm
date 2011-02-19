package SplitFixture;

use strict;
use warnings;

sub new {
  my($class,$schema) = @_;
  bless { _lines => [ split /;/, $schema ] } => $class;
}

sub query {
  my($self) = @_;

  my @table;
  for (@{ $self->{_lines} }) {
    my @words = split /,/;
    push @table, [ map [ $_+1, $words[$_] ] => 0 .. $#words ];
  }

  \@table;
}

1;
