#!/usr/bin/env perl

package Conf;

=pod
  identify configuration files using simple names

search for files matching path (choose default file if none)

search data structure for rest of path

open correct configuration file

global config:
{
  defaults: /* default options, will override above defaults */
  aliases: /* pairs of paths and replacements for them */
  expressions: /* names on paths and shell programs */
}

config.json:
{
  bash: {
    rc: {
      local: ".bashrc",
      system: "",
      home: "~/.bashrc"
    },
    var: "~/.bash_var"
  }
}
=cut

use strict;
use warnings;

use feature qw/say/;

use Config::JSON;
use Cwd qw/cwd/;

BEGIN {
  use Exporter;
  our @ISA    = qw/Exporter/;
  our @EXPORT = qw(
              %opts &load_app_config &split_path
              &eval_alias &eval_expr &run $mode
              $level);
}

package Level {
  use constant LOCAL  => 0;
  use constant HOME   => 1;
  use constant SYSTEM => 2;
}

package Mode {
  use constant OPEN      => 0;
  use constant CAT       => 1;
  use constant NEW       => 2;
  use constant LIST      => 3;
  use constant DEBUG     => 4;
  use constant EDIT_CONF => 5;
}

our $version = '0.01';
our $level   = Level::HOME;
our $mode    = Mode::OPEN;
our $editor  = $ENV{EDITOR} || 'vim';
our $configf = "$ENV{HOME}/.confrc";
our $confd   = "$ENV{HOME}/.conf.d";
our $cwd     = cwd();
our %opts    = (
  'w|with-editor=s' => \$editor,
  'S|system'    => sub { $level = Level::SYSTEM },
  'U|user'      => sub { $level = Level::HOME },
  'L|local'     => sub { $level = Level::LOCAL },
  'p|print'     => sub { $mode  = Mode::CAT },
  'o|open'      => sub { $mode  = Mode::OPEN },
  'l|list'      => sub { $mode  = Mode::LIST },
  'c|create'    => sub { $mode  = Mode::NEW },
  'd|debug'     => sub { $mode  = Mode::DEBUG },
  'e|edit-conf' => sub { $mode  = Mode::EDIT_CONF },
  'h|help'      => \&HELP,
  'v|version'   => \&VERSION,
);

# load the global config file
sub load_app_config {
  1;
}

# evaluate aliases, split path string on '.',
# report errors, and replace parts with expressions
sub split_path {
  1;
}

# replace a substring with alias, if defined 
sub eval_alias {
  1;
}

# replace string with result of evaluating an expression
sub eval_expr {
 1;
}

# follow path, report errors, perform function in $mode
sub run {
  1;
}

sub HELP {
  say <<EOM;
manipulate configuration files lazily.

options:
  -w|--with-editor=s set the editor used to view files
  -S|--system        use system files, if any
  -U|--user          use files in user's home, if any
  -L|--local         use files in current directory, if any
  -p|--print         print contents of file to stdout
  -o|--open          open file in editor
  -l|--list          list important information to stdout
  -c|--create        create a new item
  -d|--debug         print debugging information about a path
  -e|--edit-conf     open the configuration file on given path
  -h|--help          print this help message
  -v|--version       print version information
EOM

  exit 0;
}

sub VERSION {
  say "you are running `conf` v${version}";
  
  exit 0;
}
