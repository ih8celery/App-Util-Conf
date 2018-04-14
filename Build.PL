#! /usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name    => 'App::Util::Conf',
  license        => 'MIT',
  requires       => {
    'Getopt::Long' => '2.5',
    'Cwd'          => '0',
    'YAML::XS'     => '0'
  },
  dist_version   => '0.10',
  dist_abstract  => 'META.yml'
);

$build->create_build_script;
