use 5.006;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::ReportPrereqs;
# ABSTRACT: Report on prerequisite versions during automated testing
# VERSION

use Dist::Zilla 4 ();

use Moose;
extends 'Dist::Zilla::Plugin::InlineFiles';
with 'Dist::Zilla::Role::InstallTool', 'Dist::Zilla::Role::PrereqSource';

sub mvp_multivalue_args {
    return qw( include exclude );
}

foreach my $attr (qw( include exclude )) {
    has "${attr}s" => (
        init_arg => $attr,
        is       => 'ro',
        traits   => ['Array'],
        default  => sub { [] },
        handles  => { "${attr}d_modules" => 'elements', },
    );
}

has verify_prereqs => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

sub register_prereqs {
    my $self = shift;

    $self->zilla->register_prereqs(
        {
            phase => 'test',
            type  => 'recommends',
        },
        'CPAN::Meta'               => '0',
        'CPAN::Meta::Requirements' => 0,
    );
}

sub _munge_test {
    my ( $self, $file ) = @_;
    my $guts       = $file->content;
    my $list       = join( "\n", map { "  $_" } $self->_module_list );
    my $authorlist = join( "\n", map { "    $_" } $self->_author_module_list );
    $guts =~ s{INSERT_VERSION_HERE}{$self->VERSION || '<self>'}e;
    $guts =~ s{INSERT_MODULE_LIST_HERE}{$list};
    $guts =~ s{INSERT_AUTHOR_MODULE_LIST_HERE}{$authorlist};
    $guts =~ s{INSERT_EXCLUDED_MODULES_HERE}{join(' ', $self->excluded_modules)}ge;
    $guts =~ s{INSERT_VERIFY_PREREQS_CONFIG}{$self->verify_prereqs ? 1 : 0}ge;
    $file->content($guts);
}

sub setup_installer {
    my ( $self, $opt ) = @_;
    for my $file ( @{ $self->zilla->files } ) {
        if ( 't/00-report-prereqs.t' eq $file->name ) {
            return $self->_munge_test($file);
        }
    }
    $self->log_fatal(
        'Did not find t/00-report-prereqs.t in zilla files cache, inline files broken?');
}

sub _module_list {
    my $self    = shift;
    my $prereqs = $self->zilla->prereqs->as_string_hash;
    delete $prereqs->{develop};
    my %uniq = map { $_ => 1 } map { keys %$_ } map { values %$_ } values %$prereqs;

    if ( my @includes = $self->included_modules ) {
        @uniq{@includes} = (1) x @includes;
    }
    if ( my @excludes = $self->excluded_modules ) {
        delete @uniq{@excludes};
    }

    return sort keys %uniq; ## no critic
}

sub _author_module_list {
    my $self    = shift;
    my $prereqs = $self->zilla->prereqs->as_string_hash;
    my %uniq    = map { $_ => 1 } map { keys %$_ } map { values %$_ } values %$prereqs;

    if ( my @includes = $self->included_modules ) {
        @uniq{@includes} = (1) x @includes;
    }
    if ( my @excludes = $self->excluded_modules ) {
        delete @uniq{@excludes};
    }

    return sort keys %uniq; ## no critic
}
__PACKAGE__->meta->make_immutable;

1;

=for Pod::Coverage
setup_installer
mvp_multivalue_args
register_prereqs

=head1 SYNOPSIS

  # in dist.ini
  [Test::ReportPrereqs]
  include = Acme::FYI
  exclude = Acme::Dont::Care

=head1 DESCRIPTION

This L<Dist::Zilla> plugin adds a F<t/00-report-prereqs.t> test file. It reports
the version of all modules listed in the distribution metadata prerequisites
(including 'recommends', 'suggests', etc.).  However, any 'develop' prereqs
are not reported (unless they show up in another category).

If a F<MYMETA.json> file exists and L<CPAN::Meta> is installed on the testing
machine, F<MYMETA.json> will be examined for prerequisites in addition, as it
would include any dynamic prerequisites not set in the distribution metadata.

Versions are reported based on the result of C<parse_version> from
L<ExtUtils::MakeMaker>, which means prerequisite modules are not actually
loaded (which avoids various edge cases with certain modules). Parse errors are
reported as "undef".  If a module is not installed, "missing" is reported
instead of a version string.

Additionally, if L<CPAN::Meta> is installed, unfulfilled required prerequisites
are reported after the list of all versions based on either F<MYMETA>
(preferably) or F<META> (fallback).

=head1 CONFIGURATION

=head2 include

An C<include> attribute can be specified (multiple times) to add modules
to the report.  This can be useful if there is a module in the dependency
chain that is problematic but is not directly required by this project.

=head2 exclude

An C<exclude> attribute can be specified (multiple times) to remove
modules from the report (if you had a reason to do so).

=head2 verify_prereqs

When set, installed versions of all 'requires' prerequisites are verified
against those specified.  Defaults to true.

=head1 SEE ALSO

Other Dist::Zilla::Plugins do similar things in slightly different ways that didn't
suit my style and needs.

=for :list
* L<Dist::Zilla::Plugin::Test::PrereqsFromMeta> -- requires prereqs to be satisfied
* L<Dist::Zilla::Plugin::Test::ReportVersions> -- bundles a copy of YAML::Tiny, reads prereqs only from META.yml, and attempts to load them with C<require>
* L<Dist::Zilla::Plugin::ReportVersions::Tiny> -- static list only, loads modules with C<require>

=cut

__DATA__
___[ t/00-report-prereqs.t ]___
#!perl

use strict;
use warnings;

# This test was generated by Dist::Zilla::Plugin::Test::ReportPrereqs INSERT_VERSION_HERE

use Test::More tests => 1;

use ExtUtils::MakeMaker;
use File::Spec::Functions;
use List::Util qw/max/;

my @modules = qw(
INSERT_MODULE_LIST_HERE
);

if ( $ENV{AUTHOR_TESTING} ) {
  @modules = qw(
INSERT_AUTHOR_MODULE_LIST_HERE
  );
}

my %exclude = map {; $_ => 1 } qw(
INSERT_EXCLUDED_MODULES_HERE
);

my ($source) = grep { -f $_ } qw/MYMETA.json MYMETA.yml META.json/;
$source = "META.yml" unless defined $source;

# replace modules with dynamic results from MYMETA.json if we can
# (hide CPAN::Meta from prereq scanner)
my $cpan_meta = "CPAN::Meta";
my $cpan_meta_req = "CPAN::Meta::Requirements";
my $all_requires;
if ( -f $source && eval "require $cpan_meta" ) { ## no critic
  if ( my $meta = eval { CPAN::Meta->load_file($source) } ) {

    # Get ALL modules mentioned in META (any phase/type)
    my $prereqs = $meta->prereqs;
    delete $prereqs->{develop} if not $ENV{AUTHOR_TESTING};
    my %uniq = map {$_ => 1} map { keys %$_ } map { values %$_ } values %$prereqs;
    $uniq{$_} = 1 for @modules; # don't lose any static ones
    @modules = sort grep { ! $exclude{$_} } keys %uniq;

    # If verifying, merge 'requires' only for major phases
    if ( INSERT_VERIFY_PREREQS_CONFIG ) {
      $prereqs = $meta->effective_prereqs; # get the object, not the hash
      if (eval "require $cpan_meta_req; 1") { ## no critic
        $all_requires = $cpan_meta_req->new;
        for my $phase ( qw/configure build test runtime develop/ ) {
          $all_requires->add_requirements(
            $prereqs->requirements_for($phase, 'requires')
          );
        }
      }
    }
  }
}

my @reports = [qw/Version Module/];
my @dep_errors;
my $req_hash = defined($all_requires) ? $all_requires->as_string_hash : {};

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

    if ( INSERT_VERIFY_PREREQS_CONFIG && $all_requires ) {
      my $req = $req_hash->{$mod};
      if ( defined $req && length $req ) {
        if ( ! defined eval { version->parse($ver) } ) {
          push @dep_errors, "$mod version '$ver' cannot be parsed (version '$req' required)";
        }
        elsif ( ! $all_requires->accepts_module( $mod => $ver ) ) {
          push @dep_errors, "$mod version '$ver' is not in required range '$req'";
        }
      }
    }

  }
  else {
    push @reports, ["missing", $mod];

    if ( INSERT_VERIFY_PREREQS_CONFIG && $all_requires ) {
      my $req = $req_hash->{$mod};
      if ( defined $req && length $req ) {
        push @dep_errors, "$mod is not installed (version '$req' required)";
      }
    }
  }
}

if ( @reports ) {
  my $vl = max map { length $_->[0] } @reports;
  my $ml = max map { length $_->[1] } @reports;
  splice @reports, 1, 0, ["-" x $vl, "-" x $ml];
  diag "\nVersions for all modules listed in $source (including optional ones):\n",
    map {sprintf("  %*s %*s\n",$vl,$_->[0],-$ml,$_->[1])} @reports;
}

if ( @dep_errors ) {
  diag join("\n",
    "\n*** WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING ***\n",
    "The following REQUIRED prerequisites were not satisfied:\n",
    @dep_errors,
    "\n"
  );
}

pass;

# vim: ts=2 sts=2 sw=2 et:
