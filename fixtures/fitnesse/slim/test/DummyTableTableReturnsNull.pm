package DummyTableTableReturnsNull;

use strict;
use warnings;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub doTable {
  my($self,$table) = @_;

  # i.e., [['']]
  unless (ref $table eq "ARRAY" &&
          @$table == 1 &&
          ref $table->[0] eq "ARRAY" &&
          @{ $table->[0] } == 1 &&
          $table->[0][0] eq "")
  {
    return [ [ "unexpected argument to doTable" ] ];
  }

  [[]];

  # also acceptable
  # [['']];
}

1;
