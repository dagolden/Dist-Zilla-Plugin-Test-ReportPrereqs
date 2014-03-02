use 5.006;
use strict;
use warnings;

package Dist::Zilla::Plugin::Test::ReportPrereqs;
# ABSTRACT: Report on prerequisite versions during automated testing
# VERSION

use Dist::Zilla 4 ();

use Moose;
with 'Dist::Zilla::Role::FileGatherer', 'Dist::Zilla::Role::PrereqSource';

use Sub::Exporter::ForMethods;
use Data::Section 0.200002 # encoding and bytes
    { installer => Sub::Exporter::ForMethods::method_installer },
    '-setup';

use Data::Dumper;

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
        'CPAN::Meta::Requirements' => '2.120900',
    );
}

sub gather_files {
    my $self = shift;

    my $data = $self->merged_section_data;
    return unless $data and %$data;

    require Dist::Zilla::File::InMemory;

    for my $filename (keys %$data) {
        $self->add_file(Dist::Zilla::File::InMemory->new({
            name => $filename,
            content => $self->_munge_test(${ $data->{$filename} }),
        }));
    }

    require Dist::Zilla::File::FromCode;
    $self->add_file(Dist::Zilla::File::FromCode->new({
        name => $self->_dump_filename,
        code => sub { $self->_dump_prereqs },
    }));

    return;
}

sub _munge_test {
    my ( $self, $guts ) = @_;
    $guts =~ s{INSERT_VERSION_HERE}{$self->VERSION || '<self>'}e;
    $guts =~ s{INSERT_DD_FILENAME_HERE}{$self->_dump_filename}e;
    $guts =~ s{INSERT_INCLUDED_MODULES_HERE}{_format_list($self->included_modules)}e;
    $guts =~ s{INSERT_EXCLUDED_MODULES_HERE}{_format_list($self->excluded_modules)}e;
    $guts =~ s{INSERT_VERIFY_PREREQS_CONFIG}{$self->verify_prereqs ? 1 : 0}e;
    return $guts;
}

sub _dump_filename { 't/00-report-prereqs.dd' }

sub _format_list {
    return join( "\n", map { "  $_" } @_ );
}

sub _dump_prereqs {
    my $self    = shift;
    my $prereqs = $self->zilla->prereqs->as_string_hash;
    return ("do { my "
          . Data::Dumper->new( [$prereqs], ['x'] )->Purity(1)->Sortkeys(1)->Terse(0)->Dump()
          . '  $x;'
          . "\n }" );
}

__PACKAGE__->meta->make_immutable;

1;

=for Pod::Coverage
gather_files
mvp_multivalue_args
register_prereqs

=head1 SYNOPSIS

  # in dist.ini
  [Test::ReportPrereqs]
  include = Acme::FYI
  exclude = Acme::Dont::Care

=head1 DESCRIPTION

This L<Dist::Zilla> plugin adds a F<t/00-report-prereqs.t> test file and an accompanying
F<t/00-report-prereqs.dd> data file. It reports
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
use version;

# hide optional CPAN::Meta modules from prereq scanner
# and check if they are available
my $cpan_meta = "CPAN::Meta";
my $cpan_meta_req = "CPAN::Meta::Requirements";
my $HAS_CPAN_META = eval "require $cpan_meta"; ## no critic
my $HAS_CPAN_META_REQ = eval "require $cpan_meta_req; $cpan_meta_req->VERSION('2.120900')";

# Verify requirements?
my $DO_VERIFY_PREREQS = INSERT_VERIFY_PREREQS_CONFIG;

sub _merge_requires {
    my ($collector, $prereqs) = @_;
    for my $phase ( qw/configure build test runtime develop/ ) {
        next unless exists $prereqs->{$phase};
        if ( my $req = $prereqs->{$phase}{'requires'} ) {
            my $cmr = CPAN::Meta::Requirements->from_string_hash( $req );
            $collector->add_requirements( $cmr );
        }
    }
}

my %include = map {; $_ => 1 } qw(
INSERT_INCLUDED_MODULES_HERE
);

my %exclude = map {; $_ => 1 } qw(
INSERT_EXCLUDED_MODULES_HERE
);

# Add static prereqs to the included modules list
my $static_prereqs = do 'INSERT_DD_FILENAME_HERE';

delete $static_prereqs->{develop} if not $ENV{AUTHOR_TESTING};
$include{$_} = 1 for map { keys %$_ } map { values %$_ } values %$static_prereqs;

# Merge requirements for major phases (if we can)
my $all_requires;
if ( $DO_VERIFY_PREREQS && $HAS_CPAN_META_REQ ) {
    $all_requires = $cpan_meta_req->new;
    _merge_requires($all_requires, $static_prereqs);
}


# Add dynamic prereqs to the included modules list (if we can)
my ($source) = grep { -f } 'MYMETA.json', 'MYMETA.yml';
if ( $source && $HAS_CPAN_META ) {
  if ( my $meta = eval { CPAN::Meta->load_file($source) } ) {
    my $dynamic_prereqs = $meta->prereqs;
    delete $dynamic_prereqs->{develop} if not $ENV{AUTHOR_TESTING};
    $include{$_} = 1 for map { keys %$_ } map { values %$_ } values %$dynamic_prereqs;

    if ( $DO_VERIFY_PREREQS && $HAS_CPAN_META_REQ ) {
        _merge_requires($all_requires, $dynamic_prereqs);
    }
  }
}
else {
  $source = 'static metadata';
}

my @modules = sort grep { ! $exclude{$_} } keys %include;
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

    if ( $DO_VERIFY_PREREQS && $all_requires ) {
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

    if ( $DO_VERIFY_PREREQS && $all_requires ) {
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

# vim: ts=4 sts=4 sw=4 et:
