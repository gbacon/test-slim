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
  my($class,%options) = @_;

  my $self = bless {} => $class;
  my $max_frame = defined $options{max_frame_bytes}
    ? $options{max_frame_bytes}
    : defined $ENV{TEST_SLIM_MAX_FRAME_BYTES}
      ? $ENV{TEST_SLIM_MAX_FRAME_BYTES} : 67_108_864;
  die "invalid TEST_SLIM_MAX_FRAME_BYTES"
    unless defined($max_frame) && $max_frame =~ /\A[1-9][0-9]*\z/
      && (length($max_frame) < 10
        || length($max_frame) == 10 && $max_frame le '1073741824');
  $self->{MAX_FRAME_BYTES} = 0 + $max_frame;
  $self->{EXEC} = Test::Slim::ListExecutor->new;

  $self;
}

sub _read_exact {
  my($self,$fh,$length,$where,$clean_eof) = @_;

  my $result = "";
  my $wanted = $length;
  while ($length > 0) {
    my $status = sysread $fh, my($buf), $length;

    if (defined $status) {
      if ($status == 0) {
        return if $clean_eof && $result eq "";
        die "truncated $where ($wanted bytes expected, " . length($result) . " received)";
      }
      $result .= $buf;
      $length -= $status;
    }
    else {
      next if $!{EINTR};
      die "sysread: $!";
    }
  }

  $result;
}

sub _write {
  my($self,$fh,$buf) = @_;

  return unless defined $buf;
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

sub _read_message {
  my($self,$fh) = @_;

  my $digits = "";
  while (1) {
    my $char = $self->_read_exact($fh,1,"message length",$digits eq "");
    return unless defined $char;
    last if $char eq ":";

    die "invalid message length prefix"
      unless $char =~ /\A[0-9]\z/ && length($digits) < 32;
    $digits .= $char;
  }

  die "invalid message length prefix"
    unless $digits =~ /\A[0-9]{6,}\z/;
  (my $significant = $digits) =~ s/^0+//;
  $significant = '0' unless length $significant;
  my $maximum = "$self->{MAX_FRAME_BYTES}";
  die "resource limit: message frame exceeds configured maximum"
    if length($significant) > length($maximum)
      || length($significant) == length($maximum) && $significant gt $maximum;

  return $self->_read_exact($fh,0 + $significant,"message payload",0);
}

sub process {
  my($self,$fh) = @_;

  $self->_process_session($fh,$fh,'V0.4',1);
}

sub process_pipe {
  my($self,$input,$output) = @_;

  local $SIG{PIPE} = 'IGNORE';
  $self->_process_session($input,$output,'V0.5',0);
}

sub _process_session {
  my($self,$input,$output,$version,$close_input) = @_;

  my $ok;
  my $error;
  {
    local $self->{EXEC} = Test::Slim::ListExecutor->new;
    $ok = eval { $self->_process($input,$output,$version); 1 };
    $error = $@;
  }

  close $input if $close_input && defined fileno($input);
  die $error unless $ok;
  return;
}

sub _process {
  my($self,$input,$output,$version) = @_;

  $self->_write($output, "Slim -- $version\n");

  while (1) {
    my $command = $self->_read_message($input);
    return unless defined $command;

    if (lc($command) eq "bye") {
      return;
    }
    else {
      warn "command=[" . length($command) . " bytes]\n";
      my @instructions = Test::Slim::List->new(
        $command, limits => { frame_bytes => $self->{MAX_FRAME_BYTES} }
      )->list;
      my @results = $self->execute(@instructions);

      my $response = Test::Slim::List->new(\@results)->serialize;
      my $octets = encode "UTF-8", $response;
      die "resource limit: response frame exceeds configured maximum"
        if length($octets) > $self->{MAX_FRAME_BYTES};
      warn "response=[" . length($octets) . " bytes]\n";
      $self->_write($output, sprintf "%06d:%s", length($octets), $octets);
    }
  }
}

sub execute {
  my($self,@instructions) = @_;
  $self->{EXEC}->execute(@instructions);
}

sub run {
  my($self,$port) = @_;

  return $self->run_pipe if defined($port) && $port eq '1';

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

sub run_pipe {
  my($self) = @_;

  open my $protocol_output, '>&', \*STDOUT
    or die "$0: duplicate SLiM stdout failed: $!\n";
  binmode $protocol_output or die "$0: binary SLiM stdout failed: $!\n";
  binmode STDIN or die "$0: binary SLiM stdin failed: $!\n";

  # Keep fd 1 away from SLiM framing even when a fixture, child process, or
  # native routine writes directly to stdout. The saved handle remains the
  # only protocol-output path. FitNesse collects this diagnostic stream.
  open STDOUT, '>&', STDERR
    or die "$0: redirect fixture stdout failed: $!\n";
  binmode STDOUT or die "$0: binary fixture stdout redirection failed: $!\n";
  my $selected = select STDOUT;
  $| = 1;
  select $selected;

  $self->process_pipe(\*STDIN,$protocol_output);
  close $protocol_output or die "$0: close SLiM stdout failed: $!\n";
  return;
}

1;
