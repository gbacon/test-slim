package Test::FitNesse::Slim::InstallDocumentation;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec;

our @EXPORT_OK = qw(render_installed_pod installed_manpage_paths);

sub installed_manpage_paths {
  my ($prefix, $config) = @_;
  die 'installation prefix is required' unless defined $prefix;
  die 'Perl Config values are required' unless ref($config) eq 'HASH';

  my %spec = (
    bindoc => {
      config => [qw(installman1dir installsiteman1dir installvendorman1dir)],
      source => 'man1dir', section => 'man1', stem => 'perl-slim', ext => 'man1ext',
    },
    libdoc => {
      config => [qw(installman3dir installsiteman3dir installvendorman3dir)],
      source => 'man3dir', section => 'man3', stem => 'Test::FitNesse::Slim', ext => 'man3ext',
    },
  );

  my (%paths, @disabled);
  for my $kind (qw(bindoc libdoc)) {
    my $entry = $spec{$kind};
    my @configured = grep {
      defined($config->{$_}) && length($config->{$_}) && $config->{$_} ne 'none'
    } @{ $entry->{config} };
    my $source_dir = $config->{ $entry->{source} };
    if (!@configured || !defined($source_dir) || !length($source_dir)
        || $source_dir eq 'none') {
      push @disabled, $kind;
      next;
    }

    my $extension = $config->{ $entry->{ext} };
    die "Perl Config has no usable $entry->{ext} for Module::Build $kind"
      unless defined($extension) && $extension =~ /\A[A-Za-z0-9]+\z/ && $extension ne 'none';

    # Module::Build documents these install_base destinations as man/man1
    # and man/man3. This smoke test always configures --install_base.
    $paths{$kind} = File::Spec->catfile(
      $prefix, 'man', $entry->{section}, "$entry->{stem}.$extension",
    );
  }

  return (\%paths, \@disabled);
}

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

Test::FitNesse::Slim::InstallDocumentation - Installed-distribution POD smoke-test helper

=head1 DESCRIPTION

Renders a POD file from an installed distribution with C<Pod::Text> and
reports missing, unreadable, unparsable, or empty documentation distinctly.

=head1 FUNCTIONS

=head2 installed_manpage_paths($prefix, \%Config)

Returns the Module::Build C<install_base> manual-page destinations enabled by
the active Perl configuration and the documentation targets that are
disabled. Module::Build may omit Unix manual generation when Perl was
configured without manpage directories; callers must still validate the
installed POD separately.

=head2 render_installed_pod($path)

Returns the rendered text. Dies if the file is missing or unreadable, or if
the parser fails or produces no text.

=cut
