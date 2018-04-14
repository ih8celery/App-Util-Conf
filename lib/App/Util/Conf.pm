#!/usr/bin/env perl
# 
# file: Conf.pm
# author: Adam Marshall (ih8celery)
# brief: find and open configuration files using custom
# names

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
  our $LOCAL  = 'local';
  our $USER   = 'user';
  our $SYSTEM = 'system';
}

package Action {
  our $OPEN = 0;
  our $LIST = 1;
}

# module parameters
our $VERSION = '0.10';
our $EDITOR  = $ENV{EDITOR} || 'vim';

# general settings
our $LEVEL  = $Level::USER;
our $ACTION = $Action::OPEN;

# special settings
our $ALIAS_ENABLED = 0;
our $EXPR_ENABLED  = 1;
our $CONFIG_FILE   = $ENV{CONF_APP_RC}
      || _join_filepaths($ENV{HOME}, '.confrc');
our $RECORDS_DIR   = $ENV{CONF_APP_RECORDS} || '.conf.d';

# command-line options
our %OPTS = (
  'w|with-editor=s' => \$EDITOR,
  'S|system'     => sub { $LEVEL = $Level::SYSTEM },
  'U|user'       => sub { $LEVEL = $Level::USER },
  'L|local'      => sub { $LEVEL = $Level::LOCAL },
  'h|help'       => \&_help,
  'v|version'    => \&_version,
  'a|aliases'    => sub { $ALIAS_ENABLED = 1; },
  'A|no-aliases' => sub { $ALIAS_ENABLED = 0; },
  'e|exprs'      => sub { $EXPR_ENABLED = 1; },
  'E|no-exprs'   => sub { $EXPR_ENABLED = 0; }
);

Getopt::Long::Configure('no_ignore_case');

# print help message and exit
sub _help {
  say <<EOM;
Options:
  -w|--with-editor=s set the editor used to view files
  -S|--system        use system files, if any
  -U|--user          use files in user's home, if any
  -L|--local         use files in current directory, if any
  -h|--help          print this help message
  -v|--version       print version information
  -a|--aliases       enable aliases in path processing
  -A|--no-aliases    disable aliases in path processing
  -e|--exprs         enable expressions in path processing
  -E|--no-exprs      disable expressions in path processing
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
    say 'error: ', $msg;

    if (defined $code) {
      exit (0 + $code);
    }
    else {
      exit 1;
    }
  }
  else {
    say 'usage: conf [subcommand] [opts] [path]';
    exit 1;
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

  # replace strings with alias definitions, if defined 
  sub eval_alias {
    my ($ea_array) = @_;

    for (my $i = 0; $i < scalar @{$ea_array}; $i++) {
      if (defined $SETTINGS->{aliases}{ $ea_array->[$i] }) {
        $ea_array->[$i] = $SETTINGS->{aliases}{ $ea_array->[$i] };
      }
    }
  }

  # replace strings with results of evaluating an expression
  sub eval_expr {
    my ($ee_array) = @_;

    for (my $i = 0; $i < scalar @$ee_array; $i++) {
      if (defined $SETTINGS->{expressions}{ $ee_array->[$i] }) {
        $ee_array->[$i]
          = qx/$SETTINGS->{expressions}{ $ee_array->[$i] }/;

        chomp $ee_array->[$i];
      }
    }
  }
}

# try to find subcommand in argv
sub get_subcommand {
  my $gs_num_args = scalar @ARGV;
  if ($gs_num_args == 0) {
    _help();  
  }
  else {
    if ($ARGV[0] eq '-h' || $ARGV[0] eq '--help') {
      _help();
    }
    elsif ($ARGV[0] eq '-v' || $ARGV[0] eq '--version') {
      _version();
    }
    elsif ($ARGV[0] eq 'go') {
      $ACTION = $Action::OPEN;
    }
    elsif ($ARGV[0] eq 'ls') {
      $ACTION = $Action::LIST;
    }
    else {
      _error('expected global option or subcommand as first arg');
    }
  }
}

# split argument into a list
# along the way, evaluate aliases and expressions
sub process_path {
  my ($pp_path) = @_;
  my $pp_file = _pp_find_starting_point($LEVEL) || _error('no files');
  my @pp_parts = split /\./, $pp_path;

  # replace aliases to strings
  if ($ALIAS_ENABLED) {
    eval_alias(\@pp_parts);
  }

  # replace embedded expressions with the results of evaluating them
  if ($EXPR_ENABLED) {
    eval_expr(\@pp_parts);
  }

  # identify the file
  my $pp_temp_file = $pp_file;
  my $pp_num_parts = scalar @pp_parts;
  for (my $i = 0; $i < $pp_num_parts; ++$i) {
    $pp_temp_file = _join_filepaths($pp_temp_file, $pp_parts[$i]);

    if (-e $pp_temp_file) {
      $pp_file = $pp_temp_file;
      next;
    }
    else {
      if ($i >= $pp_num_parts - 1) {
        # last part, so this marks an exit
        last;
      }
      else {
        _error('no file to read (perhaps you should write one?)');
      }
    }
  }

  unless (-f $pp_file) {
    _error('no file to read (perhaps you should write one?)');
  }

  # signals that file-search consumed entire path
  if ($pp_temp_file eq $pp_file) {
    return ($pp_file, '');
  }
  # a single part was left behind
  else {
    if ($pp_parts[-1] !~ m/^_/) {
      return ($pp_file, $pp_parts[-1]);
    }
    else {
      _error('may not select an item whose name begins with _');
    }
  }
}

# figure out where to start the search for the files with config info
sub _pp_find_starting_point {
  my ($locality) = @_;

  # return for now, do checks later TODO
  if ($locality eq $Level::USER) {
    return _join_filepaths($ENV{HOME}, $RECORDS_DIR, 'user');
  }
  elsif ($locality eq $Level::SYSTEM) {
    return _join_filepaths($ENV{HOME}, $RECORDS_DIR, 'system');
  }
  else {
    return _join_filepaths(getcwd(), $RECORDS_DIR, 'local');
  }
}

# merge parts of path in a way appropriate to platform
sub _join_filepaths {
  my $out = $_[0] || _error('_join_filepaths: at least one arg required');

  my $sep = '/';
  for(my $i = 1; $i < scalar @_; $i++) {
    $out .= $sep . $_[ $i ];
  }

  return $out;
}

# lists the contents of files or items on stdout
sub list_stuff {
  my ($ls_records, $ls_key) = @_;

  _error('nothing to show') unless defined $ls_records;

  if ($ls_key eq '') {
    # stuff is a yaml object which should be printed completely
    # print keys alongside values
    my $ls_root = $ENV{HOME};
    $ls_root = $ls_records->{_root} if defined $ls_records->{_root};
    $ls_root =~ s/\/$//;

    foreach (keys %$ls_records) {
      # forbid keys beginning with '_'
      unless (m/^_/) {
        print $_, ' ';
        if ($ls_records->{$_} =~ m/^\//) {
          say $ls_records->{$_};
        }
        else {
          say $ls_root, '/', $ls_records->{$_};
        }
      }
    }
  }
  else {
    if (defined $ls_records->{$ls_key}) {
      if (defined $ls_records->{_root}) {
        say _join_filepaths($ls_records->{_root}, $ls_records->{$ls_key});
      }
      else {
        say $ls_records->{$ls_key};
      }
    }
    else {
      _error('nothing to show');
    }
  }
}

# open a file with default editor
sub open_stuff {
  my ($os_file, $os_records, $os_key) = @_;

  if ($os_key eq '' && -f $os_file) {
    exec "$EDITOR $os_file";
  }
  elsif ($os_key ne '' && defined $os_records->{$os_key}) {
    if (defined $os_records->{_root}) {
      exec $EDITOR . ' ' . _join_filepaths(
          $os_records->{_root},
          $os_records->{$os_key}
      );
    }
    else {
      exec "$EDITOR $os_records->{$os_key}";
    }
  }
  else {
    _error('nothing to open');
  }
}

# main application logic
sub run {
  get_subcommand();
  shift @ARGV;

  GetOptions(%OPTS);

  configure_app($CONFIG_FILE);
  
  my ($r_path) = shift @ARGV || _error();

  my ($r_file, $r_path_end) = process_path($r_path);

  my $r_records = LoadFile($r_file);

  if ($ACTION == $Action::OPEN) {
    open_stuff($r_file, $r_records, $r_path_end);
  }
  elsif ($ACTION == $Action::LIST) {
    list_stuff($r_records, $r_path_end);
  }
}

1;

__END__

=head1 Name

conf -- find and open configuration files lazily

=head1 Summary

conf [subcommand] [options] [path]

C<conf> helps you find and open your configuration files using a
simple notation to identify them called a path and a description of
your configuration setup in YAML that can be customized by you. C<conf>
can distinguish between "local" files, "user" files located in
the home directory, and "system" files. C<conf> uses YAML to
remember where files are located. 

C<conf> uses three shell variables:

=over 4

=item 1. EDITOR

if defined, this variable's value will be used as the editor with which
to open files (via the "go" subcommand)

=item 2. CONF_APP_RC

if defined, this variable's value will be used as the full path to the
YAML file containing defaults and defining aliases and expressions for
the program

=item 3. CONF_APP_RECORDS

if defined, this variable's value is the starting directory for searches
for configuration listings. this variable should be a relative path
since it will be used for searching in the home directory as well as the
current working directory

=back

=head1 Subcommands

=over 4

=item go

open file, if there is one. this command can open the YAML file
containing the locations of other configuration files if the
path ends on the name of one such file. For instance, if you
have listed configuration files in a file called "bash" and your
path is "bash", "go" will open that file.

=item ls

show the contents of YAML file or item in YAML file

=back

=head1 Options

=over 4

=item -w|--with-editor=s

set the editor used to open files

=item -S|--system

use system files, if any

=item -U|--user

use files in user's home, if any (B<default>)

=item -L|--local

use files in current directory, if any

=item -h|--help

print this help message

=item -v|--version

print version information

=item -a|--aliases

enable aliases

=item -A|--no-aliases

disable aliases (default)

=item -e|--exprs

enable expressions (default)

=item -E|--no-exprs

disable expressions

=back

=head1 Path

the path is a single argument of one or more dot-delimited strings
which describe the path C<conf> will take through the filesystem
and into a YAML file. the path can be thought of as having two parts:
a file part and the key part. the key part may be an empty string,
resulting in the "go" or "ls" subcommand being applied to an entire
file, but part must point to some real file. the path is split into
"file" and "key" in a three part process by the C<process_path>
subroutine:

=over 4

=item 1. Locate Starting Point in File System

based on whether the user has asked for "local", "system", or "user"
files, a dedicated subroutine will search the current working directory
and the home directory for a directory called ".conf.d" and a
subdirectory called either "user", "local", or "system". if this
directory is found, the full path to this directory is returned and
the process moves on to step 2. otherwise, the subroutine throws an
error.

=item 2. Create Maximum Valid Filepath

at this point, a starting point has been identified and the path string
has been split into an array of strings using '.' as the delimiter.
each member of this array will be concatenated with the starting file
until the result is no longer a valid filepath or until the array has
been consumed. if the final filepath produced in this process is a
directory and not a regular file, C<process_path> will throw an error.
C<process_path> will otherwise advance to the third step.

=item 3. Determine the Key

any element of the array that was not accepted in step 2 (i.e., it was
not used to create a B<valid> filepath) can be accepted in step 3,
provided that at most one such element may remain in the list. any
more will result in an error. if there are no array elements left,
the key will be set to the empty string. once the value of the key
has been determined, C<process_path> returns its results.

=back

let's look at an example. for simplicity, we will not think about
aliases or expressions.

assume the following file structure:

  ~/.conf.d/
    user/
      shells/
        zsh

and that the file "zsh" looks like this:

  ---
  _root: ~
  rc: .zshrc
  alias: .zsh_alias
  ...

then, in the invocation

  $ conf ls -U shells.zsh.alias

"ls" is the subcommand and "shell.zsh.alias" is the path. "-U"
indicates that we are expecting user configuration. in step 1
above, therefore, C<process_path> will find the directory "~/.conf.d/user".
in step 2, C<process_path>  will try to find a file or directory called
"~/.conf.d/user/shells". that is a directory, so it will move
to "~/.conf.d/user/shells/zsh". this is a file, so it will move
to "alias". C<process_path> will see that "~/.conf.d/user/shells/zsh/alias"
is not a file, so it will revert the filepath and advance to step
3. in step 3, "alias" will be used as the key, so C<conf> will
load the YAML file "~/.conf.d/user/shells/zsh" and print the value
at the key "alias".

  $ conf ls -U shells.zsh.alias
  ~/.zsh_alias

=head1 YAML Configuration Listings

here is a sample file that describes an nvim config:

  ---
  _root: /home/body/.config/nvim
  init: init.vim
  plug: plugins.vim
  binds: bindings.vim
  ...

the key beginning with an "_" is private and cannot be accessed
directly through C<conf>'s command-line interface. if you list
the value of init with

  $ conf ls nvim.init

the value of _root will be concatenated with the value of init,
using the correct separator:

  /home/adamu/.config/nvim/init.vim

=head1 Configuring the App Through the Global Config File

as soon as it launches, C<conf> searches for a YAML file in your home
directory called ".confrc". if this file exists, C<conf> loads it and
performs three steps: 1) loads any aliases, 2) loads any expressions,
and 3) loads new default values. each of those steps is described below.

=over 4

=item 1. Aliases

an alias is a string substitution stored under the 'aliases' key. much
like aliases in bash, an alias is activated when a part of the path
is recognized as an alias name. some aliases you might like to use
to maintain a "generic" approach:

  ---
  aliases:
    ed: nvim
    sh: bash
  ...

=item 2. Expressions

an expression is a string which can be evaluated by the shell. its
output is captured by C<conf> and used to replace the part of the
path which triggered it. for instance, if you created an expression
called 'sh'

  ---
  expressions:
    sh: basename $SHELL
  ...

you could automatically replace 'sh' in the path 'sh.rc' with the
name of your shell (zsh, for instance) instead of hard-coding it
into the aliases. thus

  $ conf go sh.rc

would be equivalent to

  $ conf go zsh.rc

=item 3. Default Values

C<conf> uses several global variables to control its behavior. some of
these variables have default values which can be changed at runtime by
the configuration file. they are the following:

=over 4

=item * ALIAS_ENABLED

boolean. default value 0. if 1, C<conf> will use the aliases above to
modify the B<path>. otherwise, the aliases will be completely ignored.

=item * EXPR_ENABLED

boolean. default value 0. if 1, C<conf> will use the expressions above
to modify the B<path>. otherwise, expressions will be completely
ignored.

=item * EDITOR

name of the program to use by default to open files if your subcommand
is "go".

=item * LEVEL

name of the "level" to use when searching for files. default value
"user". possible values are "user", "local", and "system".

=back

=back

=head1 Examples

 $ conf ls -U bash

lists the bash configuration files in your home directory

 $ conf ls bash.var

show the full path to the bash configuration file referred to as "var"

 $ conf go bash

opens default file associated with bash

 $ conf go bash.rc

opens the run control file for bash in your home directory

=head1 Copyright and License

This software is copyright (C) 2018, Adam Marshall.

Distributed under the MIT License.

=cut 
