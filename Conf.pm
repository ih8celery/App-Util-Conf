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
our $alias_enabled = 0;
our $expr_enabled  = 1;
our $settings;
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

sub load_app_config {
  if (-f $configf) {
    $settings = Config::JSON->new($configf);
  }
}

# evaluate aliases, split path string on '.',
# report errors, and replace parts with expressions
sub split_path {
  my $path = shift;

  if ($alias_enabled) {
    eval_alias(\$path);
  }

  my @parts = split '.', $path;
  if ($expr_enabled) {
    for my $part ($parts) {
      eval_expr(\$part);
    }
  }

  return @parts;
}

# replace a substring with alias, if defined 
sub eval_alias {
  my $pathr = shift;

  my $aliases = $settings->get("aliases");
  for my($k, $v) (each %{$aliases}) {
    $$pathr =~ s/$k/$v/;
  }
}

# replace string with result of evaluating an expression
sub eval_expr {
  my $partr = shift;

  my $expr = $settings->get("expressions/" . $$partr);
  $$partr = qx/$expr/;
}

# follow path, report errors, perform function in $mode
sub run {
  my $partsr = shift;
  exit 1 unless scalar @$partsr;

  my $file = "";
  my $tmp_path = $confd;

  # find files, stopping when not a file
  for my $part (@$partsr) {
    # still looking for file
    if ($file eq "") {
      $tmp_path .= "/" . $part . ".json";

      if (-f $tmp_path) {
        $file = $tmp_path;
        $tmp_path = "";
        
        next;
      }
      else {
        $file = $confd . "/defaults.json";
        if (-f $file) {
          $tmp_path = "";
          
          next;
        }
        else {
          exit 1;
        }
      }
    }
    else {
      if ($tmp_path eq "") {
        $tmp_path = $part;
      }
      else {
        $tmp_path .= "/" . $part;
      }
    }
  }

  # TODO potential bug, if $file does not exist or is invalid
  my $json_obj = Config::JSON->new($file);
  # TODO potential bug if $json_obj is undefined or
  # $tmp_path is empty string
  my $info = $json_obj->get($tmp_path);

  if ($mode == Mode::OPEN || $mode == Mode::CAT) {
    # get path in obj
    # if scalar and file, open file
    # if list with elem 0, open file at [0]
    # if hash with key _default, open file at {_default}
  }
  elsif ($mode == Mode::LIST) {
    # get path in obj
    # if scalar, print
    # if list, print
    # if hash, print values
  }
  elsif ($mode == Mode::NEW) {
    # get path, ensuring it exists
    # set path to second positional command-line argument and any others
  }
  elsif ($mode == Mode::EDIT_CONF) {
    # open $file
  }
  else {
    # TODO
    die "debugging function unimplemented!";
  }
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
