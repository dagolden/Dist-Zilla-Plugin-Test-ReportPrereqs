use 5.006;
use strict;
use warnings;
use Test::More 0.96;

use Capture::Tiny qw/capture/;
use Dist::Zilla::Tester;
use File::pushd qw/pushd/;
use Path::Class;
use Test::Harness;
use Cwd;

my $test_file = file(qw(t 00-report-prereqs.t));
my $root = 'corpus/DZ';

# Adapted from DZP-CheckChangesHasContent
sub capture_test_results {
  my $build_dir = shift;
  my $test_file_full = file($build_dir, $test_file)->stringify;
  my $wd = pushd $build_dir;
  return capture {
    # I'd use TAP::Parser here, except the docs are horrid.
    local $ENV{HARNESS_VERBOSE} = 1;
    Test::Harness::execute_tests(tests => [$test_file_full]);
  };
}

{
    my $tzil = Dist::Zilla::Tester->from_config(
        { dist_root => $root },
    );
    ok($tzil, "created test dist");

    $tzil->build_in;

    my $cwd = getcwd;
    chdir $tzil->tempdir->subdir('build');
    system($^X, 'Makefile.PL'); # create MYMETA.json
    chdir $cwd;

    my ($out, $err, $total, $failed) = capture_test_results($tzil->built_in);
    is($total->{ok}, 1, 'test passed') or diag "STDOUT:\n", $out, "STDERR:\n", $err, "\n";
    like( $err, qr/Prerequisite Report/, "Saw report header" );
    like( $err, qr/\bFile::Basename\b/, "prereq reported" );
    like( $err, qr/\bAn::Extra::Module::That::Causes::Problems\b/, "module included" );
    like( $err, qr/\bAn::Extra::Module::That::Causes::More::Problems\b/, "multiple modules included" );
    unlike( $err, qr/\bSecretly::Used::Module\b/, "module excluded" );
}

done_testing;
# COPYRIGHT
