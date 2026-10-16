package Fitnesse::Slim::Test::PipeTransportFixture;

use strict;
use warnings;
use Encode qw(encode_utf8);

sub new { bless { value => undef }, shift }
sub echo { $_[1] }
sub remember { $_[0]{value} = $_[1] }
sub remembered { $_[0]{value} }
sub empty_string { '' }
sub empty_list { [] }
sub null { undef }

sub write_stdout {
  print encode_utf8($_[1]), "\n";
  return $_[1];
}

sub write_stderr {
  print STDERR encode_utf8($_[1]), "\n";
  return $_[1];
}

sub write_marker {
  my($self,$path) = @_;
  open my $marker, '>', $path or die "create execution marker: $!";
  print {$marker} "executed\n" or die "write execution marker: $!";
  close $marker or die "close execution marker: $!";
  return 'written';
}

1;
