#! /usr/bin/env perl

use strict;
use warnings;

use File::Temp qw/tempfile/;
use Test::More;
use YAML::XS qw/LoadFile/;

use App::Util::Conf;

plan tests => 4;

# write to a yaml file
## create filehandle to temp file
my ($handle, $fname) = tempfile();

## print heredoc
print $handle <<EOD;
---
aliases:
  shell: zsh
expressions:
  sh: basename \$SHELL
EOD

close $handle;

# read yaml file as config
configure_app($fname);

# attempt to get subcommand (2)

## go
{
  local @ARGV = ('go');
  get_subcommand();
  ok($ACTION == 0, 'go subcommand sets program to open files');
}

## ls
{
  local @ARGV = ('ls');
  get_subcommand();
  ok($ACTION == 1, 'ls subcommand sets program to dump file contents');
}

# create a path
my @path = ("sh", "shell");

## eval aliases in path (1)
eval_alias(\@path);
is($path[1], "zsh", 'evaluate aliases in path');

## eval exprs in path (1)
eval_expr(\@path);
is($path[0], "bash", 'evaluate expressions in path');

done_testing();
