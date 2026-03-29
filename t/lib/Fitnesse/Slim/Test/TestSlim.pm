package Fitnesse::Slim::Test::TestSlim;

use strict;
use utf8;
use warnings;

sub new {
  die "no arguments allowed" if @_ > 1;
  my($class) = @_;
  bless {} => $class;
}

sub return_value { "arg" }

sub one_arg {
  my $args = @_ - 1;
  die "unexpected number of argments ($args)"
    unless @_ == 2;
}

sub echo { @_[1 .. $#_] }

sub return_string { "string" }
*returnString = \&return_string;

sub utf8 { "Español" }

sub add { shift; join "", @_ }

sub null { undef }

sub die_inside { die "oops" }

sub set_string {
  my($self,$string) = @_;
  $self->{STRING} = $string;
}

sub get_string_arg {
  my($self) = @_;
  $self->{STRING};
}

1;
