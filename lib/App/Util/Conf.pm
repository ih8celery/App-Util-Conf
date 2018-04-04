#!/usr/bin/env perl
# 
# file: Conf.pm
# author: Adam Marshall (ih8celery)
# brief: definitions of functions, variables, and constants
# required by the conf script

package Conf;

use strict;
use warnings;

use feature qw/say/;

use Const::Fast;
use Cwd qw/cwd/;
use Getopt::Long;
use YAML::XS;

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

our $VERSION = '0.05';
our $level   = Level::HOME;
our $mode    = Mode::OPEN;
our $alias_enabled = 0;
our $expr_enabled  = 1;
our $editor  = $ENV{EDITOR} || 'vim';
our $settings;
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

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::Configure('no_auto_abbrev');

sub load_app_config {
  if (-f $configf) {
    $settings = Load($configf);
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
  if ($expr_enabled) {
    @parts = map { eval_expr($_) } @parts;
  }

  return @parts;
}

# replace a substring with alias, if defined 
sub eval_alias {
  my $pathr = shift;

  my $aliases = $settings{aliases};
  while (my($k, $v) = each %$aliases) {
    $$pathr =~ s/$k/$v/;
  }
}

# replace string with result of evaluating an expression
sub eval_expr {
  my $part = shift;

  my $expr = $settings{expressions}{$part};
  if (defined $expr) {
    $part = qx/$expr/;

    chomp $part;
  }

  return $part;
}

# follow path, report errors, perform function in $mode
sub run {
  GetOptions(%opts);

  load_app_config();

  my $path;
  if (scalar @ARGV) {
    $path = shift @ARGV;
  }
  else {
    die "usage: conf [options] [path [data]]";
  }

  my @path_parts = split_path($path);
  my $file = "";
  my $tmp_path = $confd;

  # TODO get the right data from object
  for my $part (@path_parts) {
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

  my $hash_ref = Load($file);
  # TODO potential bug if $json_obj is undefined or
  # $tmp_path is empty string
  my $info = $hash_ref{$tmp_path};

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
  say "you are running `conf` $VERSION";
  say "copyright (C) 2018 Adam Marshall.";
  say "this software is provided under the MIT License";

  exit 0;
}

=head1 Summary

C<conf> helps you find and open your configuration files using a
simple notation to identify them called a path and a description of
your configuration setup in JSON that can be customized by you. C<conf>
can distinguish between "local" files, "user" files located in
the home directory, and "system" files. C<conf> uses JSON to
remember where files are located, which is reflected in the
format of the path.

=head1 Usage

conf [options] [path] [path]

=head2 Options

-w|--with-editor=s set the editor used to view files
-S|--system        use system files, if any
-U|--user          use files in user's home, if any (default)
-L|--local         use files in current directory, if any
-p|--print         print contents of file to stdout
-o|--open          open file in editor (default)
-l|--list          list important information to stdout
-c|--create        create a new item
-d|--debug         print debugging information about a path
-e|--edit-conf     open the configuration file on given path
-h|--help          print this help message
-v|--version       print version information

=head2 Path

=head1 Examples

 conf -l -U bash

lists the bash configuration files in your home directory

 conf -l bash.var

show the full path to the bash configuration file referred to as "var"

 conf bash

opens default file associated with bash

 conf bash.rc

opens the run control file for bash in your home directory

=cut 

