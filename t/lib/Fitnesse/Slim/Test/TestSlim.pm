package Fitnesse::Slim::Test::TestSlim;

use strict;
use utf8;
use warnings;

sub new {
  my($class,@args) = @_;
  my $self = bless {
    STRING => undef,
    CTRARG => 0,
  } => $class;

  return $self unless @args;

  if (@args == 1) {
    my($n) = @args;
    $self->{CTRARG} = $n;
    return $self;
  }
  elsif (@args == 2) {
    my($n,$other) = @args;
    $self->{CTRARG} = $n;
    $self->{STRING} = ref($other) ? $other->{STRING} : undef;
    return $self;
  }

  die "unexpected number of arguments (" . scalar(@args) . ")";
}

sub create_test_slim_with_string {
  my($self,$str) = @_;
  my $testslim = ref($self)->new;
  $testslim->set_string($str);
  $testslim;
}

sub get_string_from_other {
  my($self,$other) = @_;
  $other->get_string_arg;
}

sub return_constructor_arg {
  my($self) = @_;
  $self->{CTRARG};
}

sub return_value { "arg" }

sub one_arg {
  my $args = @_ - 1;
  die "unexpected number of argments ($args)"
    unless @_ == 2;
}

# sub echo { @_[1 .. $#_] }

sub echo_int {
  my($self,$i) = @_;
  $i;
}

sub echo_string {
  my($self,$string) = @_;
  $string;
}

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

sub is_same {
  my($self,$other) = @_;
  return "false" unless ref $other;
  $other == $self ? "true" : "false";
}

1;
