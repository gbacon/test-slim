package TestSlim;

use strict;
use warnings;

use Scalar::Util qw/ refaddr /;
use overload '""' => \&toString;

sub new {
  my($class,$arg,$other) = @_;
  my $self = bless { ARG => $arg || 0 } => $class;
  $self->setString($other->getStringArg) if defined $other;
  $self;
}

sub echoInt {
  my($self,$i) = @_;
  $i;
}

sub returnConstructorArg {
  my($self) = @_;
  $self->{ARG};
}

sub setString {
  my($self,$string) = @_;
  $self->{STRING} = $string;
}

sub getStringArg {
  my($self,$string) = @_;
  $self->{STRING};
}

sub echoString {
  my($self,$string) = @_;
  $string;
}

sub concatenateThreeArgs {
  my($self,$a,$b,$c) = @_;
  join " " => $a, $b, $c;
}

sub createTestSlimWithString {
  my($self,$string) = @_;
  my $other = TestSlim->new;
  $other->setString($string);
  $other;
}

sub isSame {
  my($self,$other) = @_;
  ref $self && ref $other && refaddr($self) == refaddr($other)
    ? "true" : "false";
}

sub getStringFromOther {
  my($self,$other) = @_;
  $other->getStringArg;
}

sub toString {
  my($self) = @_;

  my($i,$s) = map { my $val = $self->$_();
                    defined $val ? $val : "<undefined>" }
              qw/ returnConstructorArg getStringArg /;

  "TestSlim: $i, $s";
}

sub echoBoolean {
  my($self,$bool) = @_;
  die "value should be true or false"
    unless $bool eq "true" || $bool eq "false";
  $bool;
}

1;
