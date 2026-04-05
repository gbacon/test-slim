package Test::Slim::StatementExecutor;

use 5.10.0;
use strict;
use warnings;

use HTML::TreeBuilder;
use Test::Slim::Statement;

sub new {
  my($class) = @_;
  bless { IMPORTS => [] } => $class;
}

sub add_import {
    my($self, $prefix) = @_;
    push @{ $self->{IMPORTS} }, $self->slim_to_perl_class($prefix);
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

  my @candidates = (
      map("${_}::${class}", @{ $self->{IMPORTS} }),
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

sub create {
  my($self,$id,$class,$args) = @_;

  eval {
    ($class) = $self->replace_symbols($class);

    if (ref $class) {
      $self->{instance}{$id} = $class;
    }
    else {
      $class = $self->resolve_class($class);
      $self->construct_instance($id, $class, $args);
    }
  };
  return "OK" unless $@;

  chomp $@;
  $Test::Slim::Statement::EXCEPTION_TAG . $@;
}

sub construct_instance {
  my($self,$id,$class,$args) = @_;

  eval {
    $self->{instance}{$id} = $class->new(
      $self->replace_tables_with_hashes($self->replace_symbols(@$args))
    );
  };
  return $self->{instance}{$id} unless $@;

  chomp $@;
  my $n = @$args;
  die "message:<<COULD_NOT_INVOKE_CONSTRUCTOR $class\[$n]: $@>>";
}

sub replace_symbols {
  my($self,@args) = @_;

  my @result;
  for (@args) {
    if (ref $_ eq "ARRAY") {
      push @result, [ $self->replace_symbols(@$_) ];
    }
    elsif (defined($_) && !ref($_) && /^\$(\w+)\z/) {
      my $sym = $self->get_symbol($1);
      push @result, defined($sym) ? $sym : $_;
    }
    else {
      s{ (?<orig> \$ (?<sym> \w+ ) ) } [
        $self->get_symbol($+{sym}) // $+{orig}
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
  $self->{instance}{$id};
}

sub set_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol} = $value;
}

sub get_symbol {
  my($self,$symbol,$value) = @_;
  $self->{symbol}{$symbol};
}

sub call {
  my($self,$instance,$method,@args) = @_;

  return $Test::Slim::Statement::EXCEPTION_TAG
           . "message:<<NO_INSTANCE $instance>>"
    unless exists $self->{instance}{$instance};

  my $obj = $self->{instance}{$instance};
  my $n = @args;
  my $class = ref $obj;
  $method = $self->slim_to_perl_method($method);
  return $Test::Slim::Statement::EXCEPTION_TAG
           . "message:<<NO_METHOD_IN_CLASS $method\[$n] $class>>"
    unless $obj->can($method);

  my $result;
  eval {
    $result = $obj->$method(
      $self->replace_tables_with_hashes($self->replace_symbols(@args))
    );
  };
  unless ($@) {
    return "null" unless defined $result;
    $result =~ s/\s+$// unless ref $result;
    return $result;
  }

  chomp $@;
  $Test::Slim::Statement::EXCEPTION_TAG
    . "message:<<$@>>"
}

1;
