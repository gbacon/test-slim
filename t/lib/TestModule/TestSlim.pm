package TestModule::TestSlim;

use strict;
use utf8;
use warnings;

use SystemUnderTest;

sub new {
  die "no arguments allowed" if @_ > 1;
  my($class) = @_;
  bless { SUT => SystemUnderTest->new } => $class;
}

sub sut { $_[0]->{SUT} }

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

1;
