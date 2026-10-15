package Fitnesse::Slim::Test::Library::LibraryInSetUp;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless { echo_called => 0 }, $class;
}

sub echo {
    my ($self) = @_;
    $self->{echo_called} = 1;
    return;
}

sub echo_in_set_up_library_called {
    my ($self) = @_;
    return $self->{echo_called} ? 'true' : 'false';
}

1;
