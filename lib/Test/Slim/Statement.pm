package Test::Slim::Statement;

use strict;
use warnings;

our $EXCEPTION_TAG;
*EXCEPTION_TAG = \"__EXCEPTION__:";

sub new {
  my $class = shift;

  my $self = bless {} => $class;
  if (@_) {
    $self->{STATEMENT} = [ @_ ];
  }

  $self;
}

sub execute {
  my($class,$executor,@statement) = @_;
  Test::Slim::Statement->new(@statement)->exec($executor);
}

sub exec {
  my($self,$executor) = @_;

  my($id,$instr,@args) = $self->statement;
  #{ local $" = "]["; warn "exec: [$id][$instr][@args]\n" }
  my $meth = "do_" . $instr;
  my $result = eval { $self->$meth($executor, $id, @args) };
  return $result if $@ eq "";

  my $list = join ", ", map qq["$_"], $id, $instr, @args;
  [ $id => $Test::Slim::Statement::EXCEPTION_TAG
             . "message:<<INVALID_STATEMENT: [$list]>>" ];
}

sub statement { @{ $_[0]->{STATEMENT} } }

sub do_import {
  my($self,$executor,$id,$prefix) = @_;
  $prefix =~ s/\s*<a title=.*//;  # FIXME
  $executor->add_import($prefix);

  [ $id => "OK" ];
}

sub do_make {
  my($self,$executor,$id,$instance,$class,@args) = @_;

  [ $id => $executor->create($instance, $class, \@args) ];
}

sub do_call {
  my($self,$executor,$id,$instance,$f,@args) = @_;

  return $self->malformed_instruction($id)
    unless defined $instance && defined $f;

  [ $id => $executor->call($instance, $f, @args) ];
}

sub do_callAndAssign {
  my($self,$executor,$id,$symbol,$instance,$f,@args) = @_;

  return $self->malformed_instruction($id)
    if grep !defined($_), $symbol, $instance, $f;

  [ $id => $executor->set_symbol($symbol,
             $executor->call($instance, $f, @args)) ];
}

sub malformed_instruction {
  my($self,$id) = @_;

  my $statement = join ", ", map qq["$_"], $self->statement;
  [ $id => $Test::Slim::Statement::EXCEPTION_TAG
             . "message:<<MALFORMED_INSTRUCTION [$statement]>>" ];
}

1;
