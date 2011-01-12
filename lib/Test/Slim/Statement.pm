package Test::Slim::Statement;

use strict;
use warnings;

use File::Spec::Functions;

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

  my $meth = "do_" . $instr;
  my $result = eval { $self->$meth($executor, $id, @args) };
  return $result if $@ eq "";

  chomp $@;
  my $list = join ", ", map qq["$_"], $id, $instr, @args;
  [ $id => $Test::Slim::Statement::EXCEPTION_TAG
             . "message:<<INVALID_STATEMENT: [$list]: $@>>" ];
}

sub statement { @{ $_[0]->{STATEMENT} } }

sub slim_to_perl_class {
  my($self,$name) = @_;
  $name =~ s/\./::/g;
  $name;
}

sub do_import {
  my($self,undef,$id,$path) = @_;

  $path = catfile split /\./, $path;

  if (file_name_is_absolute $path) {
    unshift @INC, $path
      unless grep $_ eq $path, @INC;
  }
  else {
    foreach my $inc (@INC) {
      my $added = catdir $inc, $path;
      unshift @INC, $added
        if -d $added && !grep $_ eq $added, @INC;
    }
  }

  [ $id => "OK" ];
}

sub do_make {
  my($self,$executor,$id,$instance,$class,@args) = @_;

  [ $id => $executor->create($instance, $self->slim_to_perl_class($class), \@args) ];
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
