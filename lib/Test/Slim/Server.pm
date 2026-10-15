package Test::Slim::Server;

use strict;
use warnings;

use Encode qw/ encode /;
use IO::Select;
use IO::Socket::INET;
use POSIX qw/ WNOHANG /;
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

  my $result = "";
  while ($length > 0) {
    my $status = sysread $fh, my($buf), $length;

    if (defined $status) {
      last if $status == 0;
      $result .= $buf;
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
      die "syswrite returned zero" if $status == 0;
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

  my $ok;
  my $error;
  {
    local $self->{EXEC} = Test::Slim::ListExecutor->new;
    $ok = eval { $self->_process($fh); 1 };
    $error = $@;
  }

  close $fh if defined fileno($fh);
  die $error unless $ok;
  return;
}

sub _process {
  my($self,$fh) = @_;

  $self->_write($fh, "Slim -- V0.4\n");

  while (1) {
    my $length = $self->_read($fh, 7);
    return unless defined($length) && $length ne "";

    $length =~ s/^([0-9]{6}):$/$1/
      or die "expected length, but got '$length'";

    my $command = $self->_read($fh, $length);

    if (lc($command) eq "bye") {
      return;
    }
    else {
      warn "command=[$command]";
      my @instructions = Test::Slim::List->new($command)->list;
      my @results = $self->execute(@instructions);

      my $response = Test::Slim::List->new(\@results)->serialize;
      warn "response=[$response]";
      my $octets = encode "UTF-8", $response;
      $self->_write($fh, sprintf "%06d:%s", length($octets), $octets);
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
                                  Listen    => 16,
                                  LocalPort => $port)
    or die "$0: create listen socket on port $port failed: $@\n";

  local $SIG{CHLD} = sub {
    1 while waitpid(-1, WNOHANG) > 0;
  };

  my $sel = IO::Select->new($lsn);
  while (1) {
    my @ready = $sel->can_read;
    next unless @ready;
    foreach my $fh (@ready) {
      if ($fh == $lsn) {
        my $new = $lsn->accept;
        unless ($new) {
          next if $!{EINTR};
          warn "$0: accept failed: $!\n";
          next;
        }

        my $pid = fork();
        unless (defined $pid) {
          warn "$0: fork failed: $!\n";
          close $new;
          next;
        }

        if ($pid == 0) {
          close $lsn;
          $SIG{CHLD} = "DEFAULT";
          my $ok = eval { $self->process($new); 1 };
          unless ($ok) {
            my $error = $@;
            warn "$0: SLiM client failed: $error\n";
            close $new if defined fileno($new);
          }
          exit($ok ? 0 : 1);
        }

        close $new;
      }
      else {
        warn "$0: unexpected input from fd " . fileno($fh) . "\n";
      }
    }
  }
}

1;
