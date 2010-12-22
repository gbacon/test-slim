package Test::Slim::SocketService;

use strict;
use warnings;

use Encode qw/ decode encode /;
use IO::Select;
use IO::Socket;
use Socket;

sub new {
  my($class,$port) = @_;
  my $self = bless {} => $class;

  $self->port($port);

  $self;
}

sub port {
  my($self,$port) = @_;
  $self->{PORT} = $port if defined $port;
  $self->{PORT};
}

sub utf8_encode {
  my($self,$text) = @_;
  encode "UTF-8", $text;
}

sub utf8_decode {
  my($self,$bytes) = @_;
  decode "UTF-8", $bytes;
}

1;
