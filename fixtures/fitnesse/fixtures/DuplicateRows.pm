package DuplicateRows;

sub new {
  my($class,$phase) = @_;
  bless { PHASE => $phase }, $class;
}

sub query {
  my($self) = @_;

  if (uc($self->{PHASE}) eq "A") {
    return
      [
        [ [ qw/ x SuiteChildOne.SuiteSetUp    / ] ],
        [ [ qw/ x SuiteChildOne.TestOneOne    / ] ],
        [ [ qw/ x SuiteChildOne.TestOneTwo    / ] ],
        [ [ qw/ x SuiteChildOne.SuiteTearDown / ] ],
        [ [ qw/ x SuiteChildOne.SuiteSetUp    / ] ],
        [ [ qw/ x SuiteChildOne.TestOneThree  / ] ],
        [ [ qw/ x SuiteChildOne.SuiteTearDown / ] ],
      ];
  }
  else {
    return
      [
        [ [ qw/ x SuiteChildOne.SuiteSetUp    / ] ],
        [ [ qw/ x SuiteChildOne.TestOneThree  / ] ],
        [ [ qw/ x SuiteChildOne.SuiteTearDown / ] ],
        [ [ qw/ x SuiteChildOne.SuiteSetUp    / ] ],
        [ [ qw/ x SuiteChildOne.TestOneOne    / ] ],
        [ [ qw/ x SuiteChildOne.TestOneTwo    / ] ],
        [ [ qw/ x SuiteChildOne.SuiteTearDown / ] ],
      ];
  }
}

1;
