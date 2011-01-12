package Test::Slim::Server;

use strict;
use warnings;

use Encode qw/ encode decode /;
use IO::Select;
use IO::Socket::INET;
use Test::Slim::List;
use Test::Slim::ListExecutor;

our $PROTOCOL_VERSION;
*PROTOCOL_VERSION = \'0.3';

sub new {
  my($class,%arg) = @_;

  my $self = bless {} => $class;
  $self->{EXEC}    = Test::Slim::ListExecutor->new;
  $self->{VERBOSE} = delete $arg{Verbose};

  $self;
}

sub _read {
  my($self,$fh,$length) = @_;

  my $expected = $length;

  my $result;
  while ($length > 0) {
    my $status = sysread $fh, my($buf), $length;

    if (defined $status) {
      $result .= $buf;
      last if $status == 0;
      $length -= $status;
    }
    else {
      next if $!{EINTR};
      die "sysread: $!";
    }
  }

  unless (defined eval { $result = decode "utf8", $result, 1 }) {
    die "$0: failed to decode input: $@";
  }

  { use bytes;
    warn "<<< $result\n",
         "  (expected $expected; got ", length $result, ")\n",
      if $self->{VERBOSE};
  }

  $result;
}

sub _write {
  my($self,$fh,$buf) = @_;
  return unless defined $buf;

  use bytes;

  unless ($buf =~ /^Slim -- V\d/) {
    die "$0: failed to encode input: $@"
      unless defined eval { $buf = encode "utf8", $buf, 1 };

    $buf = sprintf "%06d:%s", length $buf, $buf;
  }

  warn ">>> $buf\n" if $self->{VERBOSE};

  my $length = length $buf;
  while ($length > 0) {
    my $status = syswrite $fh, $buf;

    if (defined $status) {
      $length -= $status;
      substr($buf, 0, $status) = "";
    }
    else {
      next if $!{EINTR};
      die "syswrite failed: $!";
    }
  }
}

sub process {
  my($self,$fh) = @_;

  $self->_write($fh, "Slim -- V$PROTOCOL_VERSION\n");

  while (1) {
    my $length = $self->_read($fh, 7);

    $length =~ s/^(\d{6}):$/$1/
      or die "expected length, but got '$length'";

    my $command = $self->_read($fh, $length);

    if (lc($command) eq "bye") {
      close $fh;
      return;
    }
    else {
      my @instructions = Test::Slim::List->new($command)->list;
      my @results = $self->execute(@instructions);
      my $response = Test::Slim::List->new(\@results)->serialize;
      $self->_write($fh, $response);
    }
  }
}

sub execute {
  my($self,@instructions) = @_;
  $self->{EXEC}->execute(@instructions);
}

sub run {
  my($self,$port) = @_;

  my $lsn = IO::Socket::INET->new(ReuseAddr => 1,
                                  Listen    => 1,
                                  LocalPort => $port)
    or die "$0: create listen socket on port $port failed: $@\n";

  my $sel = IO::Select->new($lsn);
  while (my @ready = $sel->can_read) {
    foreach my $fh (@ready) {
      if ($fh == $lsn) {
        my $new = $lsn->accept;
        $self->process($new);
        exit 0;
      }
      else {
        warn "$0: unexpected input from fd " . fileno($fh) . "\n";
      }
    }
  }
}

1;
