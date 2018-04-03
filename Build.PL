#! /usr/bin/env perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name => 'App::Util::Conf',
  licence     => 'MIT',
  requires    => {
    'Getopt::Long' => '>2.0',
    'Cwd'          => '>3.5',
    'YAML::XS'     => '>0.5'
  },
);

$build->create_build_script;
