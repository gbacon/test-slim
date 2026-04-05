package Fitnesse::Fixtures::PageDriver;

sub new {
  my($class) = @_;
  bless {} => $class;
}

sub create_page_with_content {
  my($self,$pagename,$content) = @_;
  $self->{page} = $pagename;
  $self->{content} = $content;
}

sub request_page {
  my($self,$pagename) = @_;
  200;
}

sub content {
  my($self) = @_;
  $self->{content};
}

sub content_contains {
  my($self,$str) = @_;
  index($self->{content}, $str) >= 0 ? "true" : "false";
}

1;
