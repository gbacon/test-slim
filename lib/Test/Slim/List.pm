package Test::Slim::List;

use strict;
use warnings;

use Encode qw/ is_utf8 encode decode /;
use Text::CharWidth qw/ mbswidth /;

sub new {
  my($this,$l) = @_;
  my $class = ref($this) || $this;
  bless { LIST => [ @$l ] } => $class;
}

sub list {
  my($self) = @_;
  @{ $self->{LIST} };
}

sub length_string {
  my($self,$length) = @_;
  sprintf "%06d:", $length;
}

sub serialize {
  my($self) = @_;
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
      elsif (is_utf8($_) || defined eval { $_ = decode("UTF-8", $_, 1) }) {
        $length = mbswidth $_;
        $item = encode "UTF-8", $_;
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
}

1;
