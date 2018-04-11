#!/usr/bin/env perl
# 
# file: Conf.pm
# author: Adam Marshall (ih8celery)
# brief: definitions of functions, variables, and constants
# required by the conf script

package App::Util::Conf;

use strict;
use warnings;

use feature qw/say/;

use Cwd qw/getcwd/;
use Getopt::Long;
use YAML::XS qw/LoadFile DumpFile/;

BEGIN {
  use Exporter;

  our @ISA    = qw/Exporter/;
  our @EXPORT = qw/&run/;
}

package Level {
  our $LOCAL  = 0;
  our $HOME   = 1;
  our $SYSTEM = 2;
}

package Mode {
  our $OPEN      = 0;
  our $CAT       = 1;
  our $NEW       = 2;
  our $LIST      = 3;
  our $DEBUG     = 4;
  our $EDIT_CONF = 5;
}

# module parameters
our $VERSION = '0.05';
our $EDITOR  = $ENV{EDITOR} || 'vim';
our $CWD     = getcwd;

# general settings
our $LEVEL = $Level::HOME;
our $MODE  = $Mode::OPEN;

# special settings
our $ALIAS_ENABLED = 0;
our $EXPR_ENABLED  = 1;
our $CONFIG_FILE   = "$ENV{HOME}/.confrc";
our $RECORDS_DIR   = "$ENV{HOME}/.conf.d";

# command-line options
our %OPTS    = (
  'w|with-editor=s' => \$EDITOR,
  'S|system'    => sub { $LEVEL = $Level::SYSTEM },
  'U|user'      => sub { $LEVEL = $Level::HOME },
  'L|local'     => sub { $LEVEL = $Level::LOCAL },
  'p|print'     => sub { $MODE  = $Mode::CAT },
  'o|open'      => sub { $MODE  = $Mode::OPEN },
  'l|list'      => sub { $MODE  = $Mode::LIST },
  'c|create'    => sub { $MODE  = $Mode::NEW },
  'd|debug'     => sub { $MODE  = $Mode::DEBUG },
  'e|edit-conf' => sub { $MODE  = $Mode::EDIT_CONF },
  'h|help'      => \&_help,
  'v|version'   => \&_version,
);

Getopt::Long::Configure('no_ignore_case');

# print help message and exit
sub _help {
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

# print version and exit
sub _version {
  say "conf $VERSION";
  exit 0;
}

# print error message and exit
sub _error {
  my ($msg, $code) = @_;

  if (defined $msg) {
    say $msg;

    if (defined $code) {
      exit (0 + $code);
    }
    else {
      exit 1;
    }
  }
  else {
    _help();
  }
}

# define functions that directly handle settings imported
# from $CONFIG_FILE
{
  my $SETTINGS;

  # load config file and change affected settings
  sub configure_app {
    $SETTINGS = LoadFile($CONFIG_FILE) if -f $CONFIG_FILE;
  }

  # replace a substring with alias, if defined 
  sub eval_alias {
    my ($ea_path_ref) = @_;

    while (my($ea_k, $ea_v) = each %{ $SETTINGS->{aliases} }) {
      $$ea_path_ref =~ s/$ea_k/$ea_v/;
    }
  }

  # replace string with result of evaluating an expression
  sub eval_expr {
    my ($ee_part) = @_;

    my $ee_expr = $SETTINGS->{expressions}{$ee_part};
    if (defined $ee_expr) {
      $ee_part = qx/$ee_expr/;

      chomp $ee_part;
    }

    return $ee_part;
  }
}

# evaluate aliases, split path string on '.',
# report errors, and replace parts with expressions
sub split_path {
  my $sp_path = shift;

  if ($ALIAS_ENABLED) {
    eval_alias(\$sp_path);
  }

  my @sp_parts = split '\.', $sp_path;
  if ($EXPR_ENABLED) {
    @sp_parts = map { eval_expr($_) } @sp_parts;
  }

  return @sp_parts;
}

# follow path, report errors, perform function in $MODE
sub run {
  my ($r_path) = @ARGV;
  my @r_path_parts;
  my $r_file   = '';
  my $r_tmp_path = $RECORDS_DIR;

  _error('usage: conf [options] [path [data]]') unless defined $r_path;

  GetOptions(%OPTS);

  configure_app();

  @r_path_parts = split_path($r_path);

  # TODO get the right data from object
  for my $r_part (@r_path_parts) {
    if ($r_file eq "") {
      $r_tmp_path .= "/" . $r_part . ".json";

      if (-f $r_tmp_path) {
        $r_file = $r_tmp_path;
        $r_tmp_path = "";
        
        next;
      }
      else {
        $r_file = $RECORDS_DIR . "/defaults.json";
        if (-f $r_file) {
          $r_tmp_path = $r_part;
          
          next;
        }
        else {
          return 1;
        }
      }
    }
    else {
      $r_tmp_path .= "/" . $r_part;
    }
  }

  return 1 unless -f $r_file;

  my $r_records = LoadFile($r_file);
  my $r_info = $r_records->{$r_tmp_path};

  if (!defined($r_info) && $MODE != $Mode::NEW) {
    return 1;
  }

  my $r_info_type = ref $r_info;

  if ($MODE == $Mode::OPEN || $MODE == $Mode::CAT) {
    $EDITOR = 'cat' if ($MODE == $Mode::CAT);

    if ($r_info_type eq "") {
      exec "$EDITOR $r_info" if -f $r_info;
    }
    elsif ($r_info_type eq "ARRAY") {
      if (defined $r_info->[0]) {
        exec "$EDITOR $r_info->[0]" if -f $r_info->[0];
      }
    }
    elsif ($r_info_type eq "HASH" && exists $r_info->{_default}) {
      if (defined $r_info->{_default}) {
        exec $r_info->{_default} if -f $r_info->{_default};
      }
    }

    die "error: nothing to open at path given";
  }
  elsif ($MODE == $Mode::LIST) {
    if ($r_info_type eq "") {
      say $r_info;
    }
    elsif ($r_info_type eq "ARRAY") {
      say join("\n", @$r_info);
    }
    elsif ($r_info_type eq "HASH") {
      say join("\n", values %$r_info);
    }
  }
  elsif ($MODE == $Mode::NEW) {
    say "creating something: "; #ASSERT
    if (scalar $ARGV[0]) {
      say $ARGV[0]; #ASSERT
    }
    else {
      die "usage: conf -n [path] [data]";
    }
  }
  elsif ($MODE == $Mode::EDIT_CONF) {
    exec "$EDITOR $r_file";
  }
  else {
    # TODO
    die "debugging function unimplemented!";
  }
}

__END__

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
