package Test::Slim::List;

use strict;
use warnings;

use Encode qw/ is_utf8 encode decode /;
use Text::CharWidth qw/ mbswidth /;

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
    unless s/^(\d{6})://;

  my @l;
  for (my $length = $1; $length > 0; --$length) {
    die "syntax error: missing item-length ($_)"
      unless s/^(\d{6})://s;

    (my $length = $1) =~ s/^0+//;
    my $item = qr/(.{$length}):/;
    die "syntax error: no item of length $length ($_)"
      unless s/^$item//;

    $item = $1;
    unless (defined eval { push @l, [ $self->new($item)->list ] }) {
      push @l, $item;
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
        use bytes;
        $item = $self->new($_)->serialize;
        $length = length $item;
      }
      elsif (is_utf8($_) || defined eval { $_ = decode("utf8", $_, 1) }) {
        # work around weirdness in mbswidth with respect to TAB, CR, and NL
        $length = mbswidth($_) + 2 * tr/\r\n\t//;
        $item = encode "UTF-8", $_, 1;
      }
      else {
        use bytes;
        $length = length $_;
        $item = $_;
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
