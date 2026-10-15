package Fitnesse::Slim::Test::LoginDialogDriver;

use strict;
use warnings;

sub new {
    my ($class, $user_name, $password) = @_;
    return bless {
        user_name => $user_name,
        password => $password,
        message => undef,
        login_attempts => 0,
    }, $class;
}

sub login_with_username_and_password {
    my ($self, $user_name, $password) = @_;
    ++$self->{login_attempts};
    my $success = defined($self->{user_name})
        && defined($self->{password})
        && defined($user_name)
        && defined($password)
        && $self->{user_name} eq $user_name
        && $self->{password} eq $password;
    my $name = defined($self->{user_name}) ? $self->{user_name} : 'null';
    $self->{message} = $success ? "$name logged in." : "$name not logged in.";
    return $success ? 'true' : 'false';
}

sub login_message {
    my ($self) = @_;
    return $self->{message};
}

sub number_of_login_attempts {
    my ($self) = @_;
    return $self->{login_attempts};
}

1;
