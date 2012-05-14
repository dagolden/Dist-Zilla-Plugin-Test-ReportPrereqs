use 5.006;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::ReportPrereqs;
# ABSTRACT: No abstract given for Dist::Zilla::Plugin::Test::ReportPrereqs
# VERSION

use File::Slurp qw/read_file write_file/;

use Moose;
extends 'Dist::Zilla::Plugin::InlineFiles';
with 'Dist::Zilla::Role::AfterBuild';

sub after_build {
  my ($self, $opt) = @_;
  my $build_root = $opt->{build_root};
  my $test_file = catfile($build_root, qw/t 000-report-prereqs.t/);
  my $guts = read_file($test_file);
  my $list = join("\n", map { "  $_" } $self->_module_list);
  $guts =~ s{INSERT_MODULE_LIST_HERE}{$list};
  write_file($test_file, $guts);
}

sub _module_list {
  my $self = shift;
  my $prereqs = $self->zilla->prereqs->as_string_hash;
  my %uniq = map {$_ => 1} map { keys %$_ } map { values %$_ } values %$prereqs;
  return sort keys %uniq;
}

__PACKAGE__->meta->make_immutable;

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  # in dist.ini
  [Test::ReportPrereqs]

=head1 DESCRIPTION

This L<Dist::Zilla> plugin adds a t/000-report-prereqs.t test file.  If
AUTOMATED_TESTING is true, it reports the version of all modules listed in the
distribution metadata prerequisites (including 'recommends', 'suggests', etc.).

If a MYMETA.json file exists and L<CPAN::Meta> is installed on the testing
machine, MYMETA.json will be examined for prerequisites as it would include any
dynamic prerequisites.  Otherwise, a static list of prerequisites is used,
generated when distribution tarball was built.

Version are reported based on the result of C<parse_version> from
L<ExtUtils::MakeMaker>, which means they are not actually loaded (which avoids
various edge cases with certain modules). Parse errors are reported as "undef".
If a module is not installed, "missing" is reported instead of a version
string.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Plugin::Test::PrereqsFromMeta> -- requires prereqs to be satisfied
* L<Dist::Zilla::Plugin::Test::ReportVersions> -- bundles a copy of YAML::Tiny,
reads prereqs only from META.yml, and attempts to load them with C<require>
* L<Dist::Zilla::Plugin::Test::ReportVersions::Tiny> -- static list only, loads
modules with C<require>

=cut

__DATA__
___[ t/000-report-prereqs.t ]___
#!perl

use strict;
use warnings;

use Test::More;

use ExtUtils::MakeMaker;
use File::Spec::Functions;
use List::Util qw/max/;

plan skip_all => '$ENV{AUTOMATED_TESTING} not set'
  unless $ENV{AUTOMATED_TESTING};

my @modules = qw(
  INSERT_MODULE_LIST_HERE 
);

# replace modules with dynamic results from MYMETA.json if we can
if ( -f "MYMETA.json" && eval { require CPAN::Meta } ) {
  if ( my $meta = eval { CPAN::Meta->load_file("MYMETA.json") } ) {
    my $prereqs = $meta->prereqs->as_string_hash;
    my %uniq = map {$_ => 1} map { keys %$_ } map { values %$_ } values %$prereqs;
    @modules = sort keys %uniq;
  }
}

my @reports;

for my $mod ( @modules ) {
  my $file = $mod;
  $file =~ s{::}{/}g;
  $file .= ".pm";
  my ($prefix) = grep { -e catfile($_, $file) } @INC;
  if ( $prefix ) {
    my $ver = MM->parse_version( catfile($prefix, $file) );
    $ver = "undef" unless defined $ver; # Newer MM should do this anyway
    push @reports, [$ver, $mod];
  }
  else {
    push @reports, [$mod, "missing", $mod];
  }
}
    
if ( @reports ) {
  my $vl = max map { length $_->[0] } @reports;
  my $ml = max map { length $_->[1] } @reports;
  diag "Prereq versions:", map {sprintf('%*s %*s',$vl,$_->[0],$ml,$_->[1])} @reports;
}

pass;

# vim: ts=2 sts=2 sw=2 et:
