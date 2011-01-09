package Test::Slim::List;

use strict;
use warnings;

use Text::CharWidth qw/ mbswidth /;

sub new {
  my($this,$l) = @_;
  my $class = ref($this) || $this;
  if (ref $l eq "ARRAY") {
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
  die "syntax error: missing open bracket ($_)"
    unless s/^\[//;
  die "syntax error: missing close bracket ($_)"
    unless s/\]$//;

  die "syntax error: missing list-length ($_)"
    unless s/^(\d{6})://;

  my @l;
  for (my $length = $1; $length > 0; --$length) {
    die "syntax error: missing item-length ($_)"
      unless s/^(\d{6})://;

    (my $length = $1) =~ s/^0{1,5}//;
    my $item = qr/(.{$length}):/s;
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
  my($self,$what) = @_;

  my $length;
  if (ref $what eq "ARRAY") {
    $length = scalar @$what;
  }
  else {
    # work around weirdness in mbswidth with respect to TAB, CR, and NL
    my $n = $what =~ tr/\r\n\t//;
    $length = mbswidth($what) + 2 * $n;
  }

  sprintf "%06d:", $length;
}

sub serialize {
  my($self) = @_;
  return $self->{RAW} if $self->{RAW};
  my @l = $self->list;

  my $result = "[" . $self->length_string(\@l);
  for (@l) {
    my $item;
    if (defined $_) {
      if (ref $_ eq "ARRAY") {
        $item = $self->new($_)->serialize;
      }
      else {
        $item = $_;
      }
    }
    else {
      $item = "null";
    }

    $result .= $self->length_string($item) . $item . ":";
  }
  $result .= "]";

  #warn "serialized: $result\n";
  $self->{RAW} = $result;
}

1;
