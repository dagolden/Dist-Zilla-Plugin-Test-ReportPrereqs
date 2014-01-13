requires "Dist::Zilla" => "4";
requires "Dist::Zilla::Plugin::InlineFiles" => "0";
requires "Dist::Zilla::Role::InstallTool" => "0";
requires "Dist::Zilla::Role::PrereqSource" => "0";
requires "Moose" => "0";
requires "perl" => "5.006";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Capture::Tiny" => "0";
  requires "Cwd" => "0";
  requires "Dist::Zilla::Tester" => "0";
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec::Functions" => "0";
  requires "File::pushd" => "0";
  requires "List::Util" => "0";
  requires "Path::Class" => "0";
  requires "Test::Harness" => "0";
  requires "Test::More" => "0.96";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "0";
  recommends "CPAN::Meta::Requirements" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5.011";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0.053";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::More" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};
