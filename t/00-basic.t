#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { plan tests => 4; }

BEGIN { use_ok('App::Util::Conf'); }

# join a filepath
my $path = _join_filepaths('.conf.d');
ok($path eq '.conf.d', '_join_filepaths does not change a list with one arg');

# join three filepaths
$path = _join_filepaths($ENV{HOME}, '.conf.d', 'system');
ok($path eq "$ENV{HOME}/.conf.d/system", 'filepaths joined with /');

# find the starting point if $LEVEL is system
my $start_path = _pp_find_starting_point('system');
ok($path eq $start_path, 'start search for system files in ~/.conf.d/system');

done_testing();
