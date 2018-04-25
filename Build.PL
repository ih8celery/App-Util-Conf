#! /usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name    => 'App::Util::Conf',
  license        => 'MIT',
  requires       => {
    'Getopt::Long' => '>2.0',
    'Cwd'          => '0',
    'YAML::XS'     => '0'
  },
  build_requires => {
    'File::Temp' => '0',
    'Test::More' => '>0.9',
    'YAML::XS'   => '0'
  },
  dist_version   => '0.010000',
  dist_abstract  => 'META.yml'
);

$build->create_build_script;
