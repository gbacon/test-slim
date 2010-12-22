package Test::Slim::SocketService;

use strict;
use threads;
use threads::shared;
use warnings;

use IO::Select;
use IO::Socket;
use Socket;
use Thread::Queue;

sub new {
  my($class) = @_;
  my $self : shared = shared_clone {};
  bless $self => $class;

  my $tids : shared = Thread::Queue->new;
  $self->{THREAD_IDS} = $tids;

  my $errors : shared = Thread::Queue->new;
  $self->{ERRORS} = $errors;

  $self;
}

sub serve {
  my($self,$port,$action) = @_;

  $self->port($port);
  $self->start_service($action);
}

sub port {
  my($self,$port) = @_;
  $self->{PORT} = $port if defined $port;
  $self->{PORT};
}

sub start_service {
  my($self,$action) = @_;

  my $thr = threads->create(
    sub { $SIG{KILL} = sub { threads->exit };
          $self->serve_connections($action);
        }
  );
  die "failed to create service thread" unless $thr;

  $self->{SERVICE} = $thr->tid;
}

sub serve_connections {
  my($self,$action) = @_;

  my $lsn = IO::Socket::INET->new(
    Listen => SOMAXCONN,
    LocalPort => $self->port,
  );

  unless ($lsn) {
    $self->error("failed to create listen socket: $@");
    threads->exit;
  }

  my $sel = IO::Select->new($lsn);

  while (!$self->{SHUTDOWN}) {
    while (my @ready = $sel->can_read(0.2)) {
      next unless @ready;

      my $s = $lsn->accept;
      my $thr = threads->create(
        sub { $SIG{KILL} = sub { close $s; threads->exit };
              $action->($s);
              close $s;
            }
      );

      if ($thr) {
        $self->add_child($thr->tid);
      }
      else {
        $self->error("accept: $!");
        last;
      }
    }
  }

  $lsn->close;

  threads->exit;
}

sub add_child {
  my($self,$tid) = @_;
  $self->{THREAD_IDS}->enqueue($tid);
}

sub error {
  my($self,$msg) = @_;
  $self->{ERRORS}->enqueue($msg);
}

sub close {
  my($self) = @_;
  my $tid = $self->{SERVICE};

  $self->{SERVICE} = undef;
  return unless defined $tid;

  $self->{SHUTDOWN} = 1;

  my $thr = threads->object($tid);
  $thr->join;
  while (defined(my $tid = $self->{THREAD_IDS}->dequeue_nb)) {
    threads->object($tid)->join;
  }

  my @errors;
  while (defined(my $msg = $self->{ERRORS}->dequeue_nb)) {
    push @errors, $msg;
  }

  die join "", map "$_\n", @errors if @errors;
}

1;
