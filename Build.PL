#! /usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name    => 'App::Util::Conf',
  licence        => 'MIT',
  requires       => {
    'Getopt::Long' => '2.5',
    'Cwd'          => '0',
    'YAML::XS'     => '0'
  },
  install_path   => { conf => "$ENV{HOME}/bin" },
  dist_version   => '0.05',
  dist_abstract  => 'META.yml'
);

$build->create_build_script;
