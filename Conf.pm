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

  my @parts = split '\.', $path;
  # say join ' ', @parts;
  if ($expr_enabled) {
    for my $part (@parts) {
      eval_expr(\$part);
    }
  }

  return @parts;
}

# replace a substring with alias, if defined 
sub eval_alias {
  my $pathr = shift;

  my $aliases = $settings->get("aliases");
  while (my($k, $v) = each %$aliases) {
    $$pathr =~ s/$k/$v/;
  }
}

# replace string with result of evaluating an expression
sub eval_expr {
  my $partr = shift;

  my $expr = $settings->get("expressions/" . $$partr);
  $$partr = qx/$expr/ if defined $expr;
}

# follow path, report errors, perform function in $mode
sub run {
  my $partsr = shift;
  exit 1 unless scalar @$partsr;

  my $file = "";
  my $tmp_path = $confd;

  for my $part (@$partsr) {
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
          $tmp_path = $part;
          
          next;
        }
        else {
          return 1;
        }
      }
    }
    else {
      $tmp_path .= "/" . $part;
    }
  }

  return 1 if $file eq "";

  my $json_obj = Config::JSON->new($file);
  # TODO potential bug if $json_obj is undefined or
  # $tmp_path is empty string
  my $info = $json_obj->get($tmp_path);

  if (!defined($info) && $mode != Mode::NEW) {
    return 1;
  }

  my $ref_type = ref $info;

  if ($mode == Mode::OPEN || $mode == Mode::CAT) {
    $editor = 'cat' if ($mode == Mode::CAT);

    if ($ref_type eq "") {
      exec "$editor $info" if -f $info;
    }
    elsif ($ref_type eq "ARRAY") {
      if (defined $info->[0]) {
        exec "$editor $info->[0]" if -f $info->[0];
      }
    }
    elsif ($ref_type eq "HASH" && exists $info->{_default}) {
      if (defined $info->{_default}) {
        exec $info->{_default} if -f $info->{_default};
      }
    }

    die "error: nothing to open at path given";
  }
  elsif ($mode == Mode::LIST) {
    if ($ref_type eq "") {
      say $info;
    }
    elsif ($ref_type eq "ARRAY") {
      say join("\n", @$info);
    }
    elsif ($ref_type eq "HASH") {
      say join("\n", values %$info);
    }
  }
  elsif ($mode == Mode::NEW) {
    say "creating something: "; #ASSERT
    if (scalar $ARGV[0]) {
      say $ARGV[0]; #ASSERT
      $json_obj->set($tmp_path, $ARGV[0]);
    }
    else {
      die "usage: conf -n [path] [data]";
    }
  }
  elsif ($mode == Mode::EDIT_CONF) {
    exec "$editor $file";
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
  say "you are running `conf` v${version}.";
  say "copyright (C) 2018 Adam Marshall.";
  say "this software is provided under the MIT License";

  exit 0;
}
