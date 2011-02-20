package Test::Slim::StatementExecutor;

use 5.10.0;
use strict;
use warnings;

use HTML::TreeBuilder;
use Test::Slim::Statement;

sub new {
  my($class) = @_;
  bless { LIBRARIES => [] } => $class;
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

sub create {
  my($self,$id,$class,$args) = @_;

  eval {
    if ($self->has_stored_actor($class)) {
      $self->add_to_instances_or_library($id, $self->stored_actor($class));
    }
    else {
      ($class) = $self->replace_symbols($class);
      $self->require($class);

      while ($class) {
        no strict 'refs';
        last if scalar keys %{$class . "::"};
        $class =~ s/^.*?:://;
      }

      my $instance = $self->construct_instance($id,$class,$args);

      $self->add_to_instances_or_library($id, $instance);
    }
  };
  return "OK" unless $@;

  chomp $@;
  $Test::Slim::Statement::EXCEPTION_TAG . $@;
}

sub has_stored_actor {
  my($self,$name) = @_;

  return unless $name &&
                $name =~ /^\$(\w+)/s &&
                $self->symbol_exists($1);

  my $potential_actor = $self->get_symbol($1);
  return defined $potential_actor && ref $potential_actor;
}

sub stored_actor {
  my($self,$id) = @_;
  return unless $id =~ /^\$(\w+)/s;
  $self->symbol_exists($1) ? $self->get_symbol($1) : ();
}

sub add_to_instances_or_library {
  my($self,$id,$instance) = @_;

  if ($id =~ /^library/) {
    $self->add_library($instance);
  }
  else {
    $self->set_instance($id, $instance);
  }
}

sub set_instance {
  my($self,$id,$instance) = @_;
  $self->{instance}{$id} = $instance;
}

sub construct_instance {
  my($self,$id,$class,$args) = @_;

  my $inst;
  eval {
    $inst = $class->new(
      $self->replace_tables_with_hashes($self->replace_symbols(@$args))
    );
  };
  return $inst if $inst && !$@;

  chomp $@;
  my $n = @$args;
  my $extra = $@ ? ": $@" : "";
  die "message:<<COULD_NOT_INVOKE_CONSTRUCTOR $class\[$n]$extra>>\n";
}

sub add_library {
  my($self,$instance) = @_;
  unshift @{ $self->{LIBRARIES} }, $instance;
}

sub libraries {
  my($self) = @_;
  @{ $self->{LIBRARIES} };
}

sub replace_symbols {
  my($self,@args) = @_;

  my $sympat = qr/ (?<orig> (?<!\$)\$ (?<sym> \w+ ) ) /x;

  my @result;
  for (@args) {
    if (ref $_ eq "ARRAY") {
      push @result, [ $self->replace_symbols(@$_) ];
    }
    elsif (/^$sympat$/) {
      push @result, $self->symbol_exists($+{sym})
                      ? $self->get_symbol($+{sym})
                      : $+{orig};
    }
    else {
      s/$sympat/
        $self->symbol_exists($+{sym})
          ? $self->get_symbol($+{sym})
          : $+{orig};
      /gex;
      push @result, $_;
    }
  }

  for (@result) {
    s/\$\$/\$/ if defined $_;
  }

  @result;
}

sub replace_tables_with_hashes {
  my($self,@args) = @_;
  map $self->replace_table_with_hash($_), @args;
}

sub replace_table_with_hash {
  my($self,$arg) = @_;

  my $hash = eval {
    return unless defined $arg;
    my $p = HTML::TreeBuilder->new_from_content($arg);
    my $table = $p->guts->look_down(_tag => "table");
    die "no table\n" unless $table;

    my %result;
    foreach my $row ($table->look_down(_tag => "tr")) {
      my @cols = map $_->content_list, $row->look_down(_tag => "td");
      die "bad columns\n"
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
  $self->{instance}{$id};
}

sub set_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol} = $value;
}

sub get_symbol {
  my($self,$symbol) = @_;
  $self->{symbol}{$symbol};
}

sub symbol_exists {
  my($self,$symbol) = @_;
  exists $self->{symbol}{$symbol};
}

sub call {
  my($self,$instance,$method,@args) = @_;

  my $obj = $self->instance($instance);
  my $class = ref $obj;
  my $n = @args;

  my $result = eval {
    if ($obj && $obj->can($method)) {
      return $self->send_message_to_instance($obj, $method, @args);
    }
    elsif ($obj && $obj->can("sut") && $obj->sut && $obj->sut->can($method)) {
      return $self->send_message_to_instance($obj->sut, $method, @args);
    }
    else {
      foreach my $library ($self->libraries) {
        return $self->send_message_to_instance($library, $method, @args)
          if $library->can($method);
      }

      return $Test::Slim::Statement::EXCEPTION_TAG
               . "message:<<NO_INSTANCE $instance>>"
        unless $obj;

      return $Test::Slim::Statement::EXCEPTION_TAG
               . "message:<<NO_METHOD_IN_CLASS $method\[$n] $class>>";
    }
  };
  return $result if $@ eq "";

  chomp $@;
  $Test::Slim::Statement::EXCEPTION_TAG
    . "message:<<exception in ${class}::$method\[$n]: $@>>"
}

sub send_message_to_instance {
  my($self,$obj,$method,@args) = @_;
  $obj->$method(
    $self->replace_tables_with_hashes($self->replace_symbols(@args))
  );
}

1;
