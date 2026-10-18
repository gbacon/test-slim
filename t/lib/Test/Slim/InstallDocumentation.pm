package Test::Slim::InstallDocumentation;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(render_installed_pod);

sub render_installed_pod {
  my ($path) = @_;
  die "installed POD file is missing: $path" unless -f $path;
  die "installed POD file is unreadable: $path" unless -r $path;

  require Pod::Text;
  my $rendered = '';
  open my $output, '>', \$rendered or die "open POD render buffer: $!";
  my $parser = Pod::Text->new;
  my $ok = eval { $parser->parse_from_file($path, $output); 1 };
  my $error = $@;
  close $output or die "close POD render buffer: $!";
  die "Pod::Text could not render installed POD $path: $error" unless $ok;
  die "Pod::Text produced no output for installed POD $path" unless length $rendered;
  return $rendered;
}

1;

__END__

=head1 NAME

Test::Slim::InstallDocumentation - Installed-distribution POD smoke-test helper

=head1 DESCRIPTION

Renders a POD file from an installed distribution with C<Pod::Text> and
reports missing, unreadable, unparsable, or empty documentation distinctly.

=head1 FUNCTIONS

=head2 render_installed_pod($path)

Returns the rendered text. Dies if the file is missing or unreadable, or if
the parser fails or produces no text.

=cut
