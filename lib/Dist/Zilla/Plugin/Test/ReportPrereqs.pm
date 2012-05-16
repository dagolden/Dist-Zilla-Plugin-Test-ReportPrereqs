use 5.006;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::ReportPrereqs;
# ABSTRACT: Report on prerequisite versions during automated testing
# VERSION

use Dist::Zilla 4 ();
use File::Slurp qw/read_file write_file/;
use File::Spec::Functions;

use Moose;
extends 'Dist::Zilla::Plugin::InlineFiles';
with 'Dist::Zilla::Role::AfterBuild';

sub mvp_multivalue_args {
  return qw( include exclude );
}

foreach my $attr ( qw( include exclude ) ){
  has "${attr}s" => (
    init_arg => $attr,
    is       => 'ro',
    traits   => ['Array'],
    default  => sub { [] },
    handles  => {
      "${attr}d_modules" => 'elements',
    },
  );
}

sub after_build {
  my ($self, $opt) = @_;
  my $build_root = $opt->{build_root};
  my $test_file = catfile($build_root, qw/t 00-report-prereqs.t/);
  my $guts = read_file($test_file);
  my $list = join("\n", map { "  $_" } $self->_module_list);
  $guts =~ s{INSERT_MODULE_LIST_HERE}{$list};
  write_file($test_file, $guts);
}

sub _module_list {
  my $self = shift;
  my $prereqs = $self->zilla->prereqs->as_string_hash;
  my %uniq = map {$_ => 1} map { keys %$_ } map { values %$_ } values %$prereqs;

  if( my @includes = $self->included_modules ){
    @uniq{ @includes } = (1) x @includes;
  }
  if( my @excludes = $self->excluded_modules ){
    delete @uniq{ @excludes };
  }

  return sort keys %uniq; ## no critic
}

__PACKAGE__->meta->make_immutable;

1;

=for Pod::Coverage after_build
mvp_multivalue_args

=head1 SYNOPSIS

  # in dist.ini
  [Test::ReportPrereqs]

=head1 DESCRIPTION

This L<Dist::Zilla> plugin adds a t/00-report-prereqs.t test file.  If
AUTOMATED_TESTING is true, it reports the version of all modules listed in the
distribution metadata prerequisites (including 'recommends', 'suggests', etc.).

If a MYMETA.json file exists and L<CPAN::Meta> is installed on the testing
machine, MYMETA.json will be examined for prerequisites in addition, as it
would include any dynamic prerequisites not set in the distribution metadata.

Versions are reported based on the result of C<parse_version> from
L<ExtUtils::MakeMaker>, which means prerequisite modules are not actually
loaded (which avoids various edge cases with certain modules). Parse errors are
reported as "undef".  If a module is not installed, "missing" is reported
instead of a version string.

=head1 CONFIGURATION

=head2 include

An C<include> attribute can be specified (multiple times) to add modules
to the report.  This can be useful if there is a module in the dependency
chain that is problematic but is not directly required by this project.

=head2 exclude

An C<exclude> attribute can be specified (multiple times) to remove
modules from the report (if you had a reason to do so).

=head1 SEE ALSO

Other Dist::Zilla::Plugins do similar things in slightly different ways that didn't
suit my style and needs.

=for :list
* L<Dist::Zilla::Plugin::Test::PrereqsFromMeta> -- requires prereqs to be satisfied
* L<Dist::Zilla::Plugin::Test::ReportVersions> -- bundles a copy of YAML::Tiny, reads prereqs only from META.yml, and attempts to load them with C<require>
* L<Dist::Zilla::Plugin::Test::ReportVersions::Tiny> -- static list only, loads modules with C<require>

=cut

__DATA__
___[ t/00-report-prereqs.t ]___
#!perl

use strict;
use warnings;

use Test::More;

use ExtUtils::MakeMaker;
use File::Spec::Functions;
use List::Util qw/max/;

if ( $ENV{AUTOMATED_TESTING} ) {
  plan tests => 1;
}
else {
  plan skip_all => '$ENV{AUTOMATED_TESTING} not set';
}

my @modules = qw(
INSERT_MODULE_LIST_HERE
);

# replace modules with dynamic results from MYMETA.json if we can
# (hide CPAN::Meta from prereq scanner)
my $cpan_meta = "CPAN::Meta";
if ( -f "MYMETA.json" && eval "require $cpan_meta" ) { ## no critic
  if ( my $meta = eval { CPAN::Meta->load_file("MYMETA.json") } ) {
    my $prereqs = $meta->prereqs;
    my %uniq = map {$_ => 1} map { keys %$_ } map { values %$_ } values %$prereqs;
    $uniq{$_} = 1 for @modules; # don't lose any static ones
    @modules = sort keys %uniq;
  }
}

my @reports = [qw/Version Module/];

for my $mod ( @modules ) {
  next if $mod eq 'perl';
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
    push @reports, ["missing", $mod];
  }
}
    
if ( @reports ) {
  my $vl = max map { length $_->[0] } @reports;
  my $ml = max map { length $_->[1] } @reports;
  splice @reports, 1, 0, ["-" x $vl, "-" x $ml];
  diag "Prerequisite Report:\n", map {sprintf("  %*s %*s\n",$vl,$_->[0],-$ml,$_->[1])} @reports;
}

pass;

# vim: ts=2 sts=2 sw=2 et:
