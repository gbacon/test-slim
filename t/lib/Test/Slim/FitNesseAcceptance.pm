package Test::Slim::FitNesseAcceptance;

use strict;
use warnings;

use Exporter qw(import);
use IO::Select;
use IO::Socket::INET;
use Time::HiRes qw(alarm time);

our @EXPORT_OK = qw(
  bounded_request
  compare_inventory
  missing_wiki_pages
  parse_page_result
  probe_slim
);

sub bounded_request {
  my($seconds,$request) = @_;
  my($response,$error);
  my $ok = eval {
    local $SIG{ALRM} = sub { die "request timed out after ${seconds}s\n" };
    alarm($seconds);
    $response = $request->();
    alarm(0);
    1;
  };
  alarm(0);
  unless ($ok) {
    $error = $@ || 'request failed';
    $error =~ s/\s+\z//;
  }
  return ($response,$error);
}

sub parse_page_result {
  my($body,$http_status,$host,$port) = @_;
  return { status => 'execution_error', error => "HTTP $http_status" }
    unless defined($http_status) && $http_status == 200;
  return { status => 'execution_error', error => 'empty FitNesse response' }
    unless defined($body) && length($body);

  my($result) = $body =~ m{<result>(.*?)</result>}s;
  my($counts) = defined($result) ? $result =~ m{<counts>(.*?)</counts>}s : ();
  return { status => 'execution_error', error => 'primary result counts missing' }
    unless defined $counts;

  my %counts;
  for my $name (qw(right wrong ignores exceptions)) {
    my($value) = $counts =~ m{<$name>(\d+)</$name>};
    return { status => 'execution_error', error => "invalid or missing $name count" }
      unless defined $value;
    $counts{$name eq 'ignores' ? 'ignored' : $name} = 0 + $value;
  }

  my($log) = $body =~ m{<executionLog>(.*?)</executionLog>}s;
  my($system) = defined($log) ? $log =~ m{<testSystem>(.*?)</testSystem>}s : ();
  my($command) = defined($log) ? $log =~ m{<command>(.*?)</command>}s : ();
  my($exit_code) = defined($log) ? $log =~ m{<exitCode>(-?\d+)</exitCode>}s : ();

  return {
    status => 'completed',
    counts => \%counts,
    conformance => $counts{wrong} == 0 && $counts{exceptions} == 0 ? 'conformant' : 'nonconformant',
    testSystem => $system,
    command => $command,
    exitCode => defined($exit_code) ? 0 + $exit_code : undef,
    externalPerlConfirmed => defined($system) && lc($system) eq lc('slim:fitnesse.slim.SlimService')
      && defined($command) && $command eq "Connection to running SlimService: $host:$port"
      && defined($exit_code) && $exit_code eq '0',
  };
}

sub compare_inventory {
  my($baseline,$observed) = @_;
  my(@missing,@unexecuted,@regressions,@newly_conformant,@known_failures,@service_failures);
  my %expected = map { $_->{page} => $_ } @$baseline;

  for my $page (sort keys %expected) {
    my $result = $observed->{$page};
    if (!$result) {
      push @missing, $page;
      push @unexecuted, $page;
      push @regressions, $page if $expected{$page}{conformance}{status} eq 'conformant';
      next;
    }

    if (($result->{status} // '') ne 'completed') {
      push @unexecuted, $page;
      push @regressions, $page if $expected{$page}{conformance}{status} eq 'conformant';
      next;
    }
    if (!$result->{externalPerlConfirmed}) {
      push @service_failures, $page;
      push @regressions, $page if $expected{$page}{conformance}{status} eq 'conformant';
      next;
    }

    my $expected_conformant = $expected{$page}{conformance}{status} eq 'conformant';
    my $is_conformant = $result->{conformance} eq 'conformant';
    push @regressions, $page if $expected_conformant && !$is_conformant;
    push @newly_conformant, $page if !$expected_conformant && $is_conformant;
    push @known_failures, $page if !$expected_conformant && !$is_conformant;
  }

  my @unexpected = sort grep { !$expected{$_} } keys %$observed;
  return {
    missing => \@missing,
    unexecuted => \@unexecuted,
    regressions => \@regressions,
    newlyConformant => \@newly_conformant,
    knownFailures => \@known_failures,
    serviceFailures => \@service_failures,
    unexpectedPages => \@unexpected,
    failed => @missing || @unexecuted || @regressions || @service_failures || @unexpected ? 1 : 0,
  };
}

sub missing_wiki_pages {
  my($wiki_root,$baseline) = @_;
  my @missing;
  for my $entry (@$baseline) {
    my $path = join '/', $wiki_root, split /\./, $entry->{page};
    my $properties = "$path/properties.xml";
    unless (-f $properties) {
      push @missing, $entry->{page};
      next;
    }
    open my $fh, '<', $properties or do { push @missing, $entry->{page}; next };
    local $/;
    my $xml = <$fh> // '';
    close $fh;
    push @missing, $entry->{page}
      unless $xml =~ m{<Test>\s*true\s*</Test>}i;
  }
  return \@missing;
}

sub probe_slim {
  my($host,$port,$timeout) = @_;
  $timeout = 1 unless defined $timeout;
  my $socket = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => $port,
    Proto => 'tcp',
    Timeout => $timeout,
  );
  return { reachable => 0, ready => 0, error => "connect: $!" } unless $socket;

  my $select = IO::Select->new($socket);
  my $line = '';
  my $deadline = time + $timeout;
  while (length($line) < 80) {
    my $remaining = $deadline - time;
    last if $remaining <= 0 || !$select->can_read($remaining);
    my $count = sysread($socket, my $chunk, 80 - length($line));
    last unless defined($count) && $count > 0;
    $line .= $chunk;
    last if $line =~ /\n/;
  }
  close $socket;
  my $ready = $line eq "Slim -- V0.4\n";
  return {
    reachable => 1,
    ready => $ready ? 1 : 0,
    greeting => $line,
    error => $ready ? undef : (length($line) ? "unexpected SLiM greeting: $line" : 'no SLiM greeting'),
  };
}

1;
