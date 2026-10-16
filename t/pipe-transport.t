#! perl

use strict;
use utf8;
use warnings;

use Encode qw(encode decode FB_CROAK);
use POSIX qw(WNOHANG);
use IO::Select;
use IPC::Open3;
use lib 'lib', 't/lib';
use Symbol qw(gensym);
use Test::More;
use Test::Slim::List;

my @children;
END { stop_child($_) for @children }

sub start_child {
  my $error = gensym;
  my $pid = open3(my $input, my $output, $error,
    $^X, '-Ilib', '-It/lib', 'bin/perl-slim', '1');
  binmode $_ for ($input, $output, $error);
  my $child = { pid => $pid, input => $input, output => $output, error => $error };
  push @children, $child;
  return $child;
}

sub stop_child {
  my($child) = @_;
  return unless $child->{pid};
  close $child->{input} if $child->{input};
  my $deadline = time + 2;
  while (time < $deadline) {
    my $result = waitpid($child->{pid}, WNOHANG);
    if ($result == $child->{pid} || $result == -1) {
      $child->{status} = $?
        if $result == $child->{pid};
      $child->{pid} = undef;
      return;
    }
    select undef, undef, undef, 0.02;
  }
  kill 'TERM', $child->{pid};
  waitpid($child->{pid}, 0);
  $child->{status} = $?;
  $child->{pid} = undef;
}

sub read_exact {
  my($fh,$length,$timeout) = @_;
  my $select = IO::Select->new($fh);
  my $deadline = time + $timeout;
  my $result = '';
  while (length($result) < $length) {
    my $remaining = $deadline - time;
    die "timed out reading $length bytes" if $remaining <= 0
      || !$select->can_read($remaining);
    my $got = sysread($fh, my $buffer, $length - length($result));
    die "unexpected EOF after " . length($result) . " of $length bytes"
      unless defined($got) && $got > 0;
    $result .= $buffer;
  }
  return $result;
}

sub read_line {
  my($fh) = @_;
  my $line = '';
  my $deadline = time + 5;
  while (length($line) < 64) {
    $line .= read_exact($fh,1,$deadline - time);
    return $line if $line =~ /\n\z/;
  }
  die 'oversized handshake';
}

sub read_frame {
  my($fh) = @_;
  my $header = '';
  my $deadline = time + 5;
  while (length($header) < 33) {
    $header .= read_exact($fh,1,$deadline - time);
    last if $header =~ /:\z/;
  }
  die "invalid frame prefix: $header" unless $header =~ /\A([0-9]{6,}):\z/;
  return read_exact($fh,0 + $1,5);
}

sub write_all {
  my($fh,$bytes) = @_;
  local $SIG{PIPE} = 'IGNORE';
  while (length $bytes) {
    my $written = syswrite($fh,$bytes);
    die "write failed: $!" unless defined($written) && $written > 0;
    substr($bytes,0,$written) = '';
  }
}

sub send_frame {
  my($child,$payload) = @_;
  my $bytes = encode('UTF-8',$payload);
  write_all($child->{input},sprintf('%06d:',length($bytes)) . $bytes);
}

sub request {
  my($child,$instructions) = @_;
  send_frame($child,Test::Slim::List->new($instructions)->serialize);
  my $wire = decode('UTF-8',read_frame($child->{output}),FB_CROAK);
  return [Test::Slim::List->new($wire)->list];
}

my $child = start_child();
is(read_line($child->{output}),"Slim -- V0.5\n",'port 1 selects the v0.5 stdin/stdout handshake');

my $unicode = 'München / Tartu õun / Mae govannen / 😀 é';
my $first = request($child,[
  [i => import => 'fitnesse.slim.test'],
  [m => make => actor => 'PipeTransportFixture'],
  [remember => call => actor => 'remember' => $unicode],
  [saved => callAndAssign => saved => actor => 'echo' => $unicode],
  [empty => call => actor => 'empty_string'],
  [null => call => actor => 'null'],
  [list => call => actor => 'empty_list'],
]);
is_deeply($first,[
  [i => 'OK'], [m => 'OK'], [remember => $unicode], [saved => $unicode], [empty => ''], [null => 'null'],
  [list => []],
],'one framed batch preserves Unicode, empty string, null, and empty list values');

my $second = request($child,[
  [echo => call => actor => 'echo' => '$saved'],
  [previous => call => actor => 'remembered'],
]);
is_deeply($second,[[echo => $unicode],[previous => $unicode]],
  'the fixture and symbol state persist across pipe request batches');

my $output_test = request($child,[[out => call => actor => 'writeStdout' => 'fixture-stdout-marker']]);
is_deeply($output_test,[[out => 'fixture-stdout-marker']],
  'fixture stdout does not corrupt the next framed protocol response');
my $error_select = IO::Select->new($child->{error});
my $error_text = '';
my $error_deadline = time + 2;
while (time < $error_deadline && $error_text !~ /fixture-stdout-marker/) {
  next unless $error_select->can_read(0.1);
  my $got = sysread($child->{error},my $buffer,4096);
  last unless defined($got) && $got > 0;
  $error_text .= $buffer;
}
like($error_text,qr/fixture-stdout-marker/,'fixture stdout is redirected away from protocol stdout');

my $stderr_test = request($child,[[err => call => actor => 'writeStderr' => 'fixture-stderr-marker']]);
is_deeply($stderr_test,[[err => 'fixture-stderr-marker']],
  'fixture stderr does not corrupt protocol responses');
my $stderr_deadline = time + 2;
while (time < $stderr_deadline && $error_text !~ /fixture-stderr-marker/) {
  next unless $error_select->can_read(0.1);
  my $got = sysread($child->{error},my $buffer,4096);
  last unless defined($got) && $got > 0;
  $error_text .= $buffer;
}
like($error_text,qr/fixture-stderr-marker/,'fixture stderr remains on the diagnostic stream');

send_frame($child,'bye');
my $readable = IO::Select->new($child->{output})->can_read(5);
ok($readable,'child closes its protocol output after bye');
my $eof = sysread($child->{output},my $extra,1);
is($eof,0,'bye produces no extra response frame');
close $child->{input};
stop_child($child);
is($child->{status} >> 8,0,'bye terminates the pipe child successfully');

my $eof_child = start_child();
is(read_line($eof_child->{output}),"Slim -- V0.5\n",'a second child starts a separate pipe session');
close $eof_child->{input};
stop_child($eof_child);
is($eof_child->{status} >> 8,0,'clean EOF terminates the pipe child successfully');

my $truncated = start_child();
read_line($truncated->{output});
write_all($truncated->{input},'000020:[');
close $truncated->{input};
stop_child($truncated);
 isnt($truncated->{status} >> 8,0,'truncated frame fails the pipe child without a response');

my $malformed = start_child();
read_line($malformed->{output});
write_all($malformed->{input},'not-a-frame');
close $malformed->{input};
stop_child($malformed);
isnt($malformed->{status} >> 8,0,'invalid frame prefix fails the pipe child');

my $marker_path = "/tmp/test-slim-pipe-atomic-$$";
unlink $marker_path;
my $bad_list = start_child();
read_line($bad_list->{output});
my $serialized = Test::Slim::List->new([
  [i => import => 'fitnesse.slim.test'],
  [m => make => actor => 'PipeTransportFixture'],
  [mark => call => actor => 'writeMarker' => $marker_path],
])->serialize;
chop $serialized;
$serialized .= 'x';
send_frame($bad_list,$serialized);
close $bad_list->{input};
stop_child($bad_list);
ok(!-e $marker_path,'a structurally corrupt batch executes none of its valid leading instructions');
isnt($bad_list->{status} >> 8,0,'corrupt serialized payload terminates only its pipe child');
unlink $marker_path;

my $bad_instruction = start_child();
read_line($bad_instruction->{output});
my $bad_response = request($bad_instruction,[['bad','unknownOperation']]);
like($bad_response->[0][1],qr/^__EXCEPTION__:message:<<MALFORMED_INSTRUCTION/,
  'valid framing with malformed instruction returns the protocol exception');
my $after_bad = request($bad_instruction,[[ok => import => 'fitnesse.slim.test']]);
is_deeply($after_bad,[[ok => 'OK']],
  'pipe session continues after a validly framed malformed instruction');
send_frame($bad_instruction,'bye');
close $bad_instruction->{input};
stop_child($bad_instruction);
is($bad_instruction->{status} >> 8,0,'malformed instruction does not poison session shutdown');

my $broken_output = start_child();
read_line($broken_output->{output});
close $broken_output->{output};
send_frame($broken_output,Test::Slim::List->new([[ok => import => 'fitnesse.slim.test']])->serialize);
close $broken_output->{input};
stop_child($broken_output);
isnt($broken_output->{status} >> 8,0,'broken protocol output pipe fails the child without SIGPIPE termination');

done_testing;
