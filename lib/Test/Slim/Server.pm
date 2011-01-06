package Test::Slim::Server;

use strict;
use warnings;

use IO::Select;
use IO::Socket::INET;
use Test::Slim::List;
use Test::Slim::ListExecutor;

sub new {
  my($class) = @_;

  my $self = bless {} => $class;
  $self->{EXEC} = Test::Slim::ListExecutor->new;

  $self;
}

sub _read {
  my($self,$fh,$length) = @_;

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

  #warn "got $result...\n";
  $result;
}

sub _write {
  my($self,$fh,$buf) = @_;

  return unless defined $buf;
  #warn "writing $buf...\n";
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

  $self->_write($fh, "Slim -- V0.2\n");

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
      $self->_write($fh, sprintf "%06d:%s", length $response, $response);
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
