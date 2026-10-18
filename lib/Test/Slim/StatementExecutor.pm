package Test::Slim::StatementExecutor;

use 5.10.0;
use strict;
use warnings;

use HTML::TreeBuilder;
use Scalar::Util qw(reftype);
use Time::HiRes qw(alarm);
use Test::Slim::Statement;
use Test::Slim::SlimHelperLibrary;
use Test::Slim::MapResult;
use Test::Slim::ConverterRegistry;

my $FIXTURE_HANDLES_SYMBOLS = "SLIM_AGENT_FIXTURE_HANDLES_SYMBOLS";

sub new {
  my($class,%options) = @_;
  my $self = bless {
    imports  => [],
    instance => {},
    library  => [],
    symbol   => {},
    fixture_symbol_pattern => undef,
    stop_requested => undef,
    converters => Test::Slim::ConverterRegistry->new,
    statement_timeout => $options{statement_timeout},
  } => $class;

  $self->{instance}{__slim_helper_library} =
    Test::Slim::SlimHelperLibrary->new($self->{instance});
  push @{ $self->{library} }, {
    id => "__slim_helper_library",
    object => $self->{instance}{__slim_helper_library},
  };
  $self;
}

sub add_import {
    my($self, $prefix) = @_;
    push @{ $self->{imports} }, $self->slim_to_perl_class($prefix);
}

sub path_to_class {
  my($self,$name) = @_;
  $name =~ s!::!/!g;
  $name . ".pm";
}

sub require {
  my($self,$class) = @_;
  eval { require $self->path_to_class($class) };
  return $class unless $@;
  chomp $@;
  die "message:<<COULD_NOT_INVOKE_CONSTRUCTOR $class $@>>\n";
}

sub slim_to_perl_class {
  my($self,$name) = @_;
  $name =~ s/\s+(\w)/\u$1/g;
  join "::" => map "\u$_", split /\.|::/, $name;
}

sub resolve_class {
  my($self, $name) = @_;

  my $class = $self->slim_to_perl_class($name);

  # A nested import must remain usable when a page also imports its parent
  # package (for example, table fixtures for fixture-managed symbols).
  my @imports = reverse @{ $self->{imports} };
  my @candidates = (
      (map("${_}::${class}", sort { length($b) <=> length($a) } @imports)),
      $class,
  );

  for my $candidate (@candidates) {
      my $path = $self->path_to_class($candidate);
      return $candidate if eval { require $path; 1 };
  }

  die "message:<<NO_CLASS $class>>\n";
}

sub slim_to_perl_method {
  my($self,$name) = @_;
  $name =~ s/([A-Z])/_\l$1/g;
  $name;
}

sub _enum_types_for {
  my ($self, $fixture) = @_;
  my $class = ref($fixture) || $fixture;
  return {} unless $class->can('slim_enum_types');
  return $self->{converters}->validate_enum_types($class->slim_enum_types);
}

sub create {
  my($self,$id,$class,$args) = @_;

  eval {
    ($class) = $self->replace_symbols($class);

    my $is_library = $id =~ /^library/;
    my $object;
    if (ref $class) {
      $object = $class;
    }
    else {
      $class = $self->resolve_class($class);
      my @constructor_args =
        $self->replace_tables_with_hashes($self->replace_symbols(@$args));
      my $signature = $class->can('slim_constructor_signature')
        ? $class->slim_constructor_signature
        : undef;
      if ($signature) {
        $signature = {
          %$signature,
          enum_types => $self->_enum_types_for($class),
        };
      }
      @constructor_args = $self->{converters}->convert_arguments(
        $signature, "$class constructor", @constructor_args
      ) if $signature;
      $object = $self->_timed(sub {
        $class->new(@constructor_args);
      });
    }

    if ($is_library) {
      push @{ $self->{library} }, { id => $id, object => $object };
    }
    else {
      $self->{instance}{$id} = $object;
    }
    $object->set_statement_executor($self)
      if $object->can('set_statement_executor');
  };
  return "OK" unless $@;

  $self->exception_result($@, 1);
}

sub construct_instance {
  my($self,$id,$class,$args) = @_;

  eval {
    $self->{instance}{$id} = $class->new(
      $self->replace_tables_with_hashes($self->replace_symbols(@$args))
    );
  };
  die $@ if $@;
  return $self->{instance}{$id};
}

sub replace_symbols {
  my($self,@args) = @_;

  my @result;
  for (@args) {
    if (ref $_ eq "ARRAY") {
      push @result, [ $self->replace_symbols(@$_) ];
    }
    elsif (defined($_) && !ref($_) && /^\$(\w+)\z/) {
      my $name = $1;
      push @result, exists $self->{symbol}{$name}
        ? $self->{symbol}{$name}
        : $_;
    }
    else {
      s{ (?<orig> \$ (?<sym> \w+ ) ) } [
        exists $self->{symbol}{$+{sym}}
          ? (defined $self->{symbol}{$+{sym}} ? $self->{symbol}{$+{sym}} : 'null')
          : $+{orig}
      ]gex;
      push @result, $_;
    }
  }

  @result;
}

sub replace_tables_with_hashes {
  my($self,@args) = @_;
  map $self->replace_table_with_hash($_), @args;
}

sub replace_table_with_hash {
  my($self,$arg) = @_;
  return $arg unless defined($arg) && !ref($arg);

  my $hash = eval {
    my $p = HTML::TreeBuilder->new_from_content($arg);
    my $table = $p->guts->look_down(_tag => "table");
    die "no table" unless $table;

    my %result;
    foreach my $row ($table->look_down(_tag => "tr")) {
      my @cols = map $_->content_list, $row->look_down(_tag => "td");
      die "bad columns"
        unless @cols == 2 && grep(!ref($_), @cols);
      s/^\s+//, s/\s+$// for @cols;
      $result{ $cols[0] } = $cols[1];
    }

    \%result;
  };

  return $@ eq "" ? $hash : $arg;
}

sub instance {
  my($self,$id) = @_;
  return $self->{instance}{$id} if exists $self->{instance}{$id};
  if ($id =~ /^library/) {
    for my $library (@{ $self->{library} }) {
      return $library->{object} if $library->{id} eq $id;
    }
  }
  return;
}

sub set_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol} = $value;
  if ($symbol eq $FIXTURE_HANDLES_SYMBOLS) {
    $self->{fixture_symbol_pattern} = undef;
    if (defined $value) {
      my $pattern = eval { qr/$value/ };
      $self->{fixture_symbol_pattern} = $pattern unless $@;
    }
  }
  return $value;
}

sub get_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol};
}

sub add_converter {
  my ($self, @args) = @_;
  $self->{converters}->add_converter(@args);
}

sub get_converter {
  my ($self, @args) = @_;
  $self->{converters}->get_converter(@args);
}

sub reset_converters {
  my ($self) = @_;
  $self->{converters}->reset;
  return;
}

sub call {
  my($self,@args) = @_;
  my $result = $self->_call(@args);
  return defined($result) ? $result : "null";
}

sub call_and_assign {
  my($self,$symbol,@args) = @_;
  my ($result, $raw_result) = $self->_call(@args);
  $self->set_symbol($symbol, ref($raw_result) ? $raw_result : $result)
    unless $self->{call_failed};
  return defined($result) ? $result : "null";
}

sub _call {
  my($self,$instance,$method,@args) = @_;
  $self->{call_failed} = 0;

  my $requested_method = $method;
  $method = $self->slim_to_perl_method($method);

  # FitNesse routes this helper call through the reserved "null" actor.
  if ($instance eq "null" && $method eq "clone_symbol" && @args == 1) {
    return ($self->replace_symbols(@args))[0];
  }

  my $has_instance = exists $self->{instance}{$instance};
  my $obj = $self->{instance}{$instance};
  if (!$has_instance && $instance =~ /^library/) {
    for my $library (@{ $self->{library} }) {
      if ($library->{id} eq $instance) {
        $obj = $library->{object};
        $has_instance = 1;
        last;
      }
    }
  }
  my $method_obj = $obj;
  unless ($has_instance && $obj->can($method)) {
    my $sut = $has_instance ? $self->_system_under_test($obj) : undef;
    $method_obj = $sut if $sut && $sut->can($method);
  }
  unless ($has_instance) {
    for my $lib_id (reverse @{ $self->{library} }) {
      my $lib = $lib_id->{object};
      next unless $lib && ref $lib;
      if ($lib->can($method)) {
        $obj = $lib;
        $method_obj = $lib;
        last;
      }
    }
    return $Test::Slim::Statement::EXCEPTION_TAG
             . "message:<<NO_INSTANCE $instance.$requested_method.>>"
      unless $obj;
  }

  unless ($method_obj && $method_obj->can($method)) {
    for my $lib_id (reverse @{ $self->{library} }) {
      my $lib = $lib_id->{object};
      next unless $lib && ref $lib;
      if ($lib->can($method)) {
        $method_obj = $lib;
        last;
      }
    }
  }

  my $n = @args;
  my $class = ref $obj;
  return $Test::Slim::Statement::EXCEPTION_TAG
           . "message:<<NO_METHOD_IN_CLASS $method\[$n] $class>>"
    unless $method_obj && $method_obj->can($method);

  my ($result, $raw_result, $retain_raw_result);
  eval {
    my @call_args = @args;
    unless ($self->{fixture_symbol_pattern}
        && "$instance.$requested_method" =~ /\A(?:$self->{fixture_symbol_pattern})\z/) {
      @call_args = $self->replace_symbols(@call_args);
    }
    @call_args = $self->replace_tables_with_hashes(@call_args);
    my $signature = $method_obj->can('slim_method_signature')
      ? $method_obj->slim_method_signature($method)
      : undef;
    if ($signature) {
      $signature = {
        %$signature,
        enum_types => $self->_enum_types_for($method_obj),
      };
    }
    @call_args = $self->{converters}->convert_arguments(
      $signature, $requested_method, @call_args
    ) if $signature;
    $result = $self->_timed(sub { $method_obj->$method(@call_args) });
    $raw_result = $result;
    $retain_raw_result = $signature
      && $self->{converters}->is_typed_sequence(
        $signature->{return}, $signature->{enum_types}
      );
    ($result) = $self->{converters}->convert_result($signature, $result)
      if $signature;
    $result = Test::Slim::MapResult->convert($result)
      if ref($result) eq "HASH";
  };
  unless ($@) {
    $result =~ s/\s+$// if defined($result) && !ref($result);
    return wantarray
      ? ($result, $retain_raw_result ? $raw_result : undef)
      : $result;
  }

  $self->{call_failed} = 1;
  $self->exception_result($@)
}

sub exception_result {
  my($self,$error,$pretty_print) = @_;
  chomp $error;

  return $Test::Slim::Statement::EXCEPTION_TAG . $error
    if $error =~ /^message:<<.*?>>\nTried to invoke: .*$/s;

  return $Test::Slim::Statement::EXCEPTION_TAG . $error
    if $error =~ /^message:<<.*>>$/s;

  if ($error =~ /^[\w.\$]*IgnoreScriptTest[\w.\$]*:/) {
    $self->{stop_requested} = 'ignore_script';
    return $Test::Slim::Statement::EXCEPTION_TAG . 'IGNORE_SCRIPT_TEST:';
  }
  if ($error =~ /^[\w.\$]*IgnoreAllTests[\w.\$]*:/) {
    $self->{stop_requested} = 'ignore_all';
    return $Test::Slim::Statement::EXCEPTION_TAG . 'IGNORE_ALL_TESTS:';
  }

  if ($error =~ /([\w.\$]*StopTest\w*Exception):\s*(.*)/s) {
    $self->{stop_requested} = 'test';
    return $Test::Slim::Statement::EXCEPTION_TAG
      . "ABORT_SLIM_TEST:"
      . ($pretty_print ? "message:<<$1: $2>>" : "$1: $2");
  }
  if ($error =~ /([\w.\$]*StopSuite\w*Exception):\s*(.*)/s) {
    $self->{stop_requested} = 'suite';
    return $Test::Slim::Statement::EXCEPTION_TAG
      . "ABORT_SLIM_SUITE:"
      . ($pretty_print ? "message:<<$1: $2>>" : "$1: $2");
  }

  if ($error =~ /^((?:java|fitnesse)\.[\w.\$]+):\s*(.*)/s) {
    return $Test::Slim::Statement::EXCEPTION_TAG
      . ($pretty_print ? "message:<<$1: $2>>" : "$1: $2");
  }

  $Test::Slim::Statement::EXCEPTION_TAG . "message:<<$error>>"
}

sub _timed {
  my($self,$code) = @_;
  my $timeout = $self->{statement_timeout};
  return $code->() unless defined $timeout;

  my $previous = alarm 0;
  local $SIG{ALRM} = sub { die "message:<<TIMED_OUT $timeout>>\n" };
  my($result,$ok,$error);
  $ok = eval {
    alarm $timeout;
    $result = $code->();
    1;
  };
  $error = $@ unless $ok;
  alarm 0;
  alarm $previous if $previous;
  die $error unless $ok;
  return $result;
}

sub stop_requested { $_[0]->{stop_requested} }
sub reset_stop_requested { $_[0]->{stop_requested} = undef }

sub _system_under_test {
  my($self,$fixture) = @_;
  return unless ref($fixture) && (reftype($fixture) || '') eq 'HASH';
  my $sut = exists $fixture->{system_under_test}
    ? $fixture->{system_under_test}
    : $fixture->{systemUnderTest};
  return ref($sut) ? $sut : undef;
}

1;
