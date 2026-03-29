package Test::Slim::List;

use strict;
use warnings;

use Encode qw/ is_utf8 encode decode /;

sub _utf16_code_units_length {
  my($s) = @_;
  my $utf16be = encode("UTF-16BE", $s);
  use bytes;
  return length($utf16be) / 2;
}

sub _take_utf16_units {
  my ($s, $units) = @_;
  my $out = "";
  my $count = 0;

  while (length $s) {
    my $ch = substr($s, 0, 1, "");
    my $u = _utf16_code_units_length($ch);
    last if $count + $u > $units;
    $out .= $ch;
    $count += $u;
    last if $count == $units;
  }

  die "syntax error: no item of length $units ($out$s)"
    unless $count == $units;

  return ($out, $s);
}

sub new {
  my($this,$l) = @_;
  my $class = ref($this) || $this;
  if (ref $l) {
    return bless { LIST => [ @$l ] } => $class;
  }
  else {
    return bless { RAW => $l } => $class;
  }
}

sub list {
  my($self) = @_;
  return @{ $self->{LIST} } if $self->{LIST};

  local $_ = $self->{RAW};
  die "cannot deserialize undefined value" unless defined $_;
  die "cannot deserialize empty string"    unless length $_;
  defined eval { $_ = decode "UTF-8", $_, 1 unless is_utf8 $_ }
    or die "cannot deserialize non-UTF-8 encoding";

  die "syntax error: missing open bracket ($_)"
    unless s/^\[//;
  die "syntax error: missing close bracket ($_)"
    unless s/\]$//;

  die "syntax error: missing list-length ($_)"
    unless s/^([0-9]{6})://;

  my @l;
  for (my $length = $1; $length > 0; --$length) {
    die "syntax error: missing item-length ($_)"
      unless s/^([0-9]{6})://;

    (my $item_len = $1) =~ s/^0+//;
    $item_len = 0 if $item_len eq "";

    my($item,$rest) = _take_utf16_units $_, $item_len;
    die "syntax error: no item of length $item_len ($_)"
      unless substr($rest, 0, 1) eq ":";
    $_ = substr $rest, 1;

    unless (defined eval { push @l, [ $self->new($item)->list ] }) {
      push @l, is_utf8($item) ? $item : decode("UTF-8", $item, 1);
    }
  }

  die "syntax error: trailing ($_)" if $_ ne "";

  @{ $self->{LIST} = \@l };
}

sub length_string {
  my($self,$length) = @_;
  sprintf "%06d:", $length;
}

sub serialize {
  my($self) = @_;
  return $self->{RAW} if $self->{RAW};
  my @l = $self->list;

  my $result = "[" . $self->length_string(scalar @l);
  for (@l) {
    my $item;
    my $length;
    if (defined $_) {
      if (ref $_) {
        $item = $self->new($_)->serialize;
        $length = _utf16_code_units_length $item;
      }
      elsif (is_utf8($_) || defined eval { $_ = decode("utf8", $_, 1) }) {
        $item = $_;
        $length = _utf16_code_units_length $item;
      }
      else {
        $item = $_;
        $length = _utf16_code_units_length $item;
      }
    }
    else {
      $item = "null";
      $length = length $item;
    }

    $result .= $self->length_string($length) . $item . ":";
  }
  $result .= "]";

  $self->{RAW} = $result;
}

1;
