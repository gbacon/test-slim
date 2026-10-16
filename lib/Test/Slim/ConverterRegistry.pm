package Test::Slim::ConverterRegistry;

use strict;
use warnings;
use overload ();
use Scalar::Util qw(blessed);
use Test::Slim::MapResult;

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  $self->reset;
  return $self;
}

sub reset {
  my ($self) = @_;
  $self->{converters} = {
    'java.lang.String' => bless({}, 'Test::Slim::ConverterRegistry::String'),
    'java.lang.Boolean' => bless({}, 'Test::Slim::ConverterRegistry::Boolean'),
    'boolean' => bless({}, 'Test::Slim::ConverterRegistry::PrimitiveBoolean'),
    'java.lang.Integer' => bless({}, 'Test::Slim::ConverterRegistry::Integer'),
    int => bless({}, 'Test::Slim::ConverterRegistry::PrimitiveInteger'),
    'java.lang.Long' => bless({}, 'Test::Slim::ConverterRegistry::Long'),
    long => bless({}, 'Test::Slim::ConverterRegistry::PrimitiveLong'),
    'java.lang.Double' => bless({}, 'Test::Slim::ConverterRegistry::Double'),
    double => bless({}, 'Test::Slim::ConverterRegistry::PrimitiveDouble'),
    'void' => bless({}, 'Test::Slim::ConverterRegistry::Void'),
    'java.util.List' => Test::Slim::ConverterRegistry::List->new($self),
    'java.util.Collection' => Test::Slim::ConverterRegistry::List->new($self),
  };
  return $self;
}

sub add_converter {
  my ($self, $type, $converter) = @_;
  die "converter must implement from_string and to_string\n"
    unless ref($converter)
      && $converter->can('from_string')
      && $converter->can('to_string');
  $self->{converters}{$type} = $converter;
  $converter->set_registry($self) if $converter->can('set_registry');
  return;
}

sub remove_converter {
  my ($self, $type) = @_;
  return delete $self->{converters}{$type};
}

sub get_converter {
  my ($self, $type) = @_;
  return unless defined $type;
  return $self->{converters}{$type} if exists $self->{converters}{$type};
  return $self->{converters}{'java.util.List'}
    if $type =~ /\Ajava\.util\.(?:ArrayList|LinkedList|Collection)\z/;
  return $self->{converters}{'java.lang.String'} if $type eq 'String';
  return $self->{converters}{'java.util.List'} if $type eq 'List';
  return;
}

sub converter_for_runtime_value {
  my ($self, $value) = @_;
  return unless ref $value;
  my $class = ref $value;
  return $self->get_converter($class) if $class ne 'ARRAY';
  return $self->get_converter('java.util.ArrayList');
}

sub element_to_string {
  my ($self, $value) = @_;
  return 'null' unless defined $value;
  return "$value" unless ref $value;

  my $converter = $self->converter_for_runtime_value($value);
  return $converter->to_string($value) if $converter;
  return Test::Slim::MapResult->convert($value) if ref($value) eq 'HASH';
  return $value->to_string if blessed($value) && $value->can('to_string');
  return $value->toString if blessed($value) && $value->can('toString');
  return "$value" if blessed($value) && overload::Method($value, '""');

  die 'Cannot convert reference value of type ' . ref($value);
}

sub convert_arguments {
  my ($self, $signature, $method, @args) = @_;
  my $types = $signature->{parameters} || [];
  for my $index (0 .. $#args) {
    next if !defined $args[$index] || ref $args[$index];
    my $type = $types->[$index];
    next unless defined $type;
    my $converter = $self->get_converter($type);
    die "message:<<NO_CONVERTER_FOR_ARGUMENT_NUMBER $type.>>\nTried to invoke: $method\n"
      unless $converter;
    my $converted = eval { $converter->from_string($args[$index]) };
    if ($@) {
      my $error = $@;
      chomp $error;
      $error =~ s/\Amessage:<<//;
      $error =~ s/>>\z//;
      die "message:<<$error>>\nTried to invoke: $method\n";
    }
    $args[$index] = $converted;
  }
  return @args;
}

sub convert_result {
  my ($self, $signature, $value) = @_;
  return ($value, 0) unless $signature && defined $signature->{return};

  my $type = $signature->{return};
  return ($value, 0)
    if $type eq 'java.util.List' && ref($value) eq 'ARRAY';

  my $converter = $self->get_converter($type);
  $converter ||= $self->converter_for_runtime_value($value);
  return ($value, 0) unless $converter;
  return ($converter->to_string($value), 1);
}

package Test::Slim::ConverterRegistry::String;
use strict;
use warnings;
sub from_string { $_[1] }
sub to_string { $_[1] }

package Test::Slim::ConverterRegistry::Boolean;
use strict;
use warnings;
sub from_string {
  return undef unless defined $_[1];
  return undef if $_[1] =~ /\A\s*\z/;
  return $_[1] =~ /\A(?:true|yes)\z/i ? 1 : 0;
}
sub to_string {
  return undef unless defined $_[1];
  return $_[1] ? 'true' : 'false';
}

package Test::Slim::ConverterRegistry::PrimitiveBoolean;
use strict;
use warnings;
our @ISA = ('Test::Slim::ConverterRegistry::Boolean');
sub from_string {
  my ($self, $value) = @_;
  return $self->SUPER::from_string($value) // 0;
}
sub to_string {
  return undef unless defined $_[1];
  return $_[1] ? 'true' : 'false';
}

package Test::Slim::ConverterRegistry::Integer;
use strict;
use warnings;
sub from_string {
  my ($self, $value) = @_;
  return undef unless defined $value && $value !~ /\A\s*\z/;
  die "message:<<Can't convert $value to integer.>>" unless $value =~ /\A[+-]?[0-9]+\z/;
  my $digits = $value;
  $digits =~ s/\A[+-]//;
  $digits =~ s/\A0+(?=.)//;
  my $negative = $value =~ /\A-/;
  my $limit = $negative ? '2147483648' : '2147483647';
  die "message:<<Can't convert $value to integer.>>"
    if length($digits) > length($limit)
      || (length($digits) == length($limit) && $digits gt $limit);
  return 0 + $value;
}
sub to_string { defined $_[1] ? "$_[1]" : undef }

package Test::Slim::ConverterRegistry::PrimitiveInteger;
use strict;
use warnings;
our @ISA = ('Test::Slim::ConverterRegistry::Integer');
sub from_string { $_[0]->SUPER::from_string($_[1]) // 0 }

package Test::Slim::ConverterRegistry::Long;
use strict;
use warnings;
sub from_string {
  my ($self, $value) = @_;
  return undef unless defined $value && $value !~ /\A\s*\z/;
  die "message:<<Can't convert $value to long.>>" unless $value =~ /\A[+-]?[0-9]+\z/;
  my $digits = $value;
  $digits =~ s/\A[+-]//;
  $digits =~ s/\A0+(?=.)//;
  my $negative = $value =~ /\A-/;
  my $limit = $negative ? '9223372036854775808' : '9223372036854775807';
  die "message:<<Can't convert $value to long.>>"
    if length($digits) > length($limit)
      || (length($digits) == length($limit) && $digits gt $limit);
  return 0 + $value;
}
sub to_string { defined $_[1] ? "$_[1]" : undef }

package Test::Slim::ConverterRegistry::PrimitiveLong;
use strict;
use warnings;
our @ISA = ('Test::Slim::ConverterRegistry::Long');
sub from_string { $_[0]->SUPER::from_string($_[1]) // 0 }

package Test::Slim::ConverterRegistry::Double;
use strict;
use warnings;
sub from_string {
  my ($self, $value) = @_;
  return undef unless defined $value && $value !~ /\A\s*\z/;
  die "message:<<Can't convert $value to double.>>"
    unless $value =~ /\A[+-]?(?:(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)\z/;
  return 0 + $value;
}
sub to_string {
  my ($self, $value) = @_;
  return undef unless defined $value;
  my $string = "$value";
  $string .= '.0' unless $string =~ /[.eE]/;
  return $string;
}

package Test::Slim::ConverterRegistry::PrimitiveDouble;
use strict;
use warnings;
our @ISA = ('Test::Slim::ConverterRegistry::Double');
sub from_string { $_[0]->SUPER::from_string($_[1]) // 0 }

package Test::Slim::ConverterRegistry::Void;
use strict;
use warnings;
sub from_string { undef }
sub to_string { '/__VOID__/' }

package Test::Slim::ConverterRegistry::List;
use strict;
use warnings;
sub new { bless { registry => $_[1] }, $_[0] }
sub from_string {
  my ($self, $arg) = @_;
  return undef unless defined $arg && $arg !~ /\A\s*\z/;
  $arg =~ s/^\[//;
  $arg =~ s/\]$//;
  return [] if $arg =~ /\A\s*\z/;
  return [map { s/^\s+|\s+$//gr } split /,/, $arg];
}
sub to_string {
  my ($self, $list) = @_;
  return undef unless defined $list;
  return '[' . join(', ', map { $self->{registry}->element_to_string($_) } @$list) . ']';
}

1;
