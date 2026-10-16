#! perl

use strict;
use warnings;

use lib 'lib', 't/lib';

use Test::More;
use Test::Slim::StatementExecutor;
use Fitnesse::Slim::Test::TestSlimWithConverter;

my $executor = Test::Slim::StatementExecutor->new;
my $fixture = Fitnesse::Slim::Test::TestSlimWithConverter->new;
$executor->create('converter', $fixture, []);

is($executor->call('converter', 'set_list_converter'), 'null',
  'fixture can register a converter in its executor');
is($executor->call('converter', 'get_object'), '{a, b, c}',
  'broad declared result type uses runtime-class converter');
is_deeply($executor->call('converter', 'get_list'), ['a', 'b', 'c'],
  'exact List result remains a nested SLiM list');
is($executor->call('converter', 'get_array_list'), '{a, b, c}',
  'concrete collection result uses interface converter');
is($executor->call('converter', 'same_list', '{a, b, c}'), 'true',
  'declared List argument uses registered fromString converter');
$executor->add_converter('java.util.List', DyingConverter->new);
my $bad = $executor->call('converter', 'same_list', '{a, b, c}');
like($bad, qr/EXCEPTION.*conversion error.*Tried to invoke: same_list/s,
  'converter exceptions become SLiM errors with invocation context');
is($executor->call('converter', 'remove_list_converter'), 'null',
  'fixture restores the previous standard converter');
is($executor->call('converter', 'same_list', '[a, b, c]'), 'true',
  'standard collection converter remains active for standard syntax');
$executor->set_symbol('items', [qw(a b c)]);
is($executor->call('converter', 'same_list', '$items'), 'true',
  'an already converted symbol value bypasses string conversion');

my $other = Test::Slim::StatementExecutor->new;
$other->create('converter', Fitnesse::Slim::Test::TestSlimWithConverter->new, []);
is($other->call('converter', 'get_object'), '[a, b, c]',
  'converter registrations are isolated by executor');

my $registry = $executor->{converters};
my ($null, $converted) = $registry->convert_result(
  { return => 'java.util.ArrayList' }, undef
);
ok(!defined($null) && $converted, 'declared return converter receives null results');
my ($fallback, $used) = $registry->convert_result(
  { return => 'example.Unregistered' }, [qw(x y)]
);
is($fallback, '[x, y]', 'unknown declared return types fall back to runtime class');
ok($used, 'runtime converter is reported as applied');
my ($nested) = $registry->convert_result(
  { return => 'java.util.ArrayList' }, [[qw(a b)], undef]
);
is($nested, '[[a, b], null]', 'collection conversion recursively renders nested lists and nulls');
my @null_args = $registry->convert_arguments(
  { parameters => ['java.util.List'] }, 'nullable', undef
);
ok(!defined($null_args[0]), 'null arguments bypass fromString conversion');
ok(!defined($registry->get_converter('java.lang.Boolean')->from_string('')),
  'boxed Boolean conversion preserves blank as null');
is($registry->get_converter('boolean')->from_string(''), 0,
  'primitive boolean conversion uses its false default');
is($registry->get_converter('boolean')->from_string('yes'), 1,
  'boolean conversion accepts upstream yes syntax');
my $no_converter = eval {
  $registry->convert_arguments(
    { parameters => ['example.UnknownType'] }, 'unknown_argument', 'value'
  );
  '';
};
like($@, qr/NO_CONVERTER_FOR_ARGUMENT_NUMBER example\.UnknownType/,
  'missing argument converters report the upstream error category');

done_testing;

package DyingConverter;
use strict;
use warnings;
sub new { bless {}, shift }
sub from_string { die "conversion error: test failure\n" }
sub to_string { die "conversion error: test failure\n" }
