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

use File::Basename qw/basename/;
use File::Spec::Functions qw/catfile/;
use Cwd qw/getcwd/;
use Getopt::Long qw/:config no_ignore_case/;
use YAML::XS qw/LoadFile DumpFile/;

BEGIN {
  use Exporter;

  our @ISA       = qw/Exporter/;
  our @EXPORT    = qw/&Run/;
  our @EXPORT_OK = qw{
      &process_path &configure_app &eval_expr 
      &eval_alias &get_subcommand &List_Conf &Open_Conf
  };
  our %EXPORT_TAGS = (
    tests => [qw{
      &Run &process_path &configure_app &eval_expr 
      &eval_alias &get_subcommand &List_Conf &Open_Conf
    }],
  );
}

# module parameters
our $VERSION = '0.011000';

# print help message and exit
sub _help {
  say <<EOM;
Options:
  -w|--with-editor=s set the editor used to view files
  -g|--global        use files in user's home, if any
  -l|--local         use files in current directory, if any
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

# load config file and change affected settings
sub configure_app {
  my ($ca_settings) = @_;

  if (-f $ca_settings->{CONFIG_FILE}) {
    my $ca_yaml = LoadFile($ca_settings->{CONFIG_FILE});
    
    if (exists $ca_yaml->{aliases}) {
      $ca_settings->{aliases} = $ca_yaml->{aliases};
    }

    if (exists $ca_yaml->{expressions}) {
      $ca_settings->{expressions} = $ca_yaml->{expressions};
    }
  }
}

# replace strings with alias definitions, if defined 
sub eval_alias {
  my ($ea_settings, $ea_array) = @_;

  for (my $i = 0; $i < scalar @{$ea_array}; $i++) {
    if (defined $ea_settings->{aliases}{ $ea_array->[$i] }) {
      $ea_array->[$i] = $ea_settings->{aliases}{ $ea_array->[$i] };
    }
  }
}

# replace strings with results of evaluating an expression
sub eval_expr {
  my ($ee_settings, $ee_array) = @_;

  for (my $i = 0; $i < scalar @$ee_array; $i++) {
    if (defined $ee_settings->{expressions}{ $ee_array->[$i] }) {
      $ee_array->[$i]
        = qx/$ee_settings->{expressions}{ $ee_array->[$i] }/;

      chomp $ee_array->[$i];
    }
  }
}

# try to find subcommand in argv
sub get_subcommand {
  my ($gs_subcommands) = @_;
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
    elsif (exists $gs_subcommands->{$ARGV[0]}) {
      return shift(@ARGV);
    }
    else {
      die('error: expected global option or subcommand');
    }
  }
}

# split argument into a list
# along the way, evaluate aliases and expressions
sub process_path {
  my ($pp_settings, $pp_path) = @_;
  my $pp_file;

  if ($pp_settings->{IS_GLOBAL}) {
    $pp_file = catfile($ENV{HOME}, $pp_settings->{RECORDS_DIR});
  }
  else {
    $pp_file = catfile(getcwd(), $pp_settings->{RECORDS_DIR});
  }

  # no starting directory to work with, so the program must DIE!!
  unless (-d $pp_file) {
    die("error: no $pp_settings->{RECORDS_DIR} directory found");
  }

  # @ARGV was empty when this function was called, so after the
  # starting directory is computed, return
  unless (defined $pp_path) {
    return ($pp_file, '');
  }

  my @pp_parts = split /\./, $pp_path;

  # replace aliases to strings
  if ($pp_settings->{ALIAS_ENABLED}) {
    eval_alias($pp_settings, \@pp_parts);
  }

  # replace embedded expressions with the results of evaluating them
  if ($pp_settings->{EXPR_ENABLED}) {
    eval_expr($pp_settings, \@pp_parts);
  }

  # identify the file
  my $pp_temp_file = $pp_file;
  my $pp_num_parts = scalar @pp_parts;
  for (my $i = 0; $i < $pp_num_parts; ++$i) {
    $pp_temp_file = catfile($pp_temp_file, $pp_parts[$i]);

    if (-d $pp_temp_file) {
      $pp_file = $pp_temp_file;
      next;
    }
    elsif (-f "$pp_temp_file.yml") {
      # if a file was found and the path has been either
      # completely processed or processed up to the last element,
      # save the file as $pp_file
      if ($i >= $pp_num_parts - 2) {
        $pp_temp_file = "$pp_temp_file.yml";
        $pp_file = $pp_temp_file;

        if ($i == $pp_num_parts - 2) {
          if ($pp_parts[-1] !~ m/^_/) {
            return ($pp_file, $pp_parts[$i+1]);
          }
          else {
            die('error: may not select an item whose name begins with _');
          }
        }
        else {
          return ($pp_file, '');
        }
      }
    }
    elsif ($i == $pp_num_parts - 1) {
      return ($pp_file, $pp_parts[$i]);
    }
    else {
      die('error: no file to read (perhaps you should write one?)');
    }
  }
}

# lists the contents of files or items on stdout
sub List_Conf {
  my ($ls_settings, $ls_file, $ls_key) = @_;

  # if file is a directory, list files in dir
  if (-d $ls_file) {
    die "error: List_Conf: $ls_key is not a file" unless $ls_key eq '';

    # glob files with yml extension
    my @yaml_files = glob "$ls_file/*.yml";
    @yaml_files = map { $_ =~ s/(.+?)\.yml/$1/; basename $_; } @yaml_files;

    say join("\n", @yaml_files);
  }
  elsif (-f $ls_file) {
    my $ls_records = LoadFile($ls_file);
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
          say catfile($ls_records->{_root}, $ls_records->{$ls_key});
        }
        else {
          say $ls_records->{$ls_key};
        }
      }
      else {
        die('nothing to show');
      }
    }
  }
}

# open a file with default editor
sub Open_Conf {
  my ($os_settings, $os_file, $os_key) = @_;

  die "error: Open_Conf: $os_file is a directory" if -d $os_file;

  my $os_records = LoadFile($os_file);

  if ($os_key eq '' && -f $os_file) {
    exec "$os_settings->{EDITOR} $os_file";
  }
  elsif ($os_key ne '' && defined $os_records->{$os_key}) {
    if (defined $os_records->{_root}) {
      exec $os_settings->{EDITOR} . ' ' . catfile(
          $os_records->{_root},
          $os_records->{$os_key}
      );
    }
    else {
      exec "$os_settings->{EDITOR} $os_records->{$os_key}";
    }
  }
  else {
    die('error: Open_Conf: nothing to open');
  }
}

# create a new config file listing
sub Init_Conf {
  my ($ic_settings, $ic_dir, $ic_key) = @_;

  # need dir and non-empty key string
  unless (-d $ic_dir) {
    die "error: Init_Conf: $ic_dir must be a directory";
  }

  if ($ic_key eq '') {
    die "error: Init_Conf: key cannot be the empty string";
  }

  # construct file path
  my $ic_path = catfile($ic_dir, "$ic_key.yml");

  # create file named $key.yml or open it if it exists
  unless (-f $ic_path) {
    open my $ic_fh, '>', $ic_path;

    say $ic_fh "# the _root is the directory in which your config files";
    say $ic_fh "# can be found. it is Not mandatory that you use it.";
    say $ic_fh "_root: $ENV{HOME}";
    say $ic_fh "# below is a config named basic located at";
    say $ic_fh "# ", catfile($ENV{HOME}, 'basic.conf');
    say $ic_fh "basic: basic.conf";

    close $ic_fh;
  }

  exec "$ic_settings->{EDITOR} $ic_path";
}

{
  # define default program settings
  my $SETTINGS = {
    CONFIG_FILE   => ($ENV{CONF_APP_RC} || catfile($ENV{HOME}, '.confrc')),
    EDITOR        => ($ENV{EDITOR} || 'vim'),
    RECORDS_DIR   => ($ENV{CONF_APP_RECORDS} || '.conf.d'),
    IS_GLOBAL     => 1,
    ALIAS_ENABLED => 1,
    EXPR_ENABLED  => 0,
    ALIASES       => {},
    EXPRESSIONS   => {},
  };

  # this is a bad idea. TODO BUG
  sub get_settings {
    return $SETTINGS;
  }

  # main application logic
  sub Run {
    # setup subcommands and command-line options
    my $r_subcommands = {
      'go'   => \&Open_Conf,
      'ls'   => \&List_Conf,
      'init' => \&Init_Conf,
    };

    ## if finding a subcommand fails, $r_ok will equal 0
    ## otherwise, $r_action will be the value of the subcommand
    my $r_action = get_subcommand($r_subcommands);

    ## if GetOptions fails, it will print an error message without
    ## dying and return a false value. this code ensures that
    ## a failure in GetOptions terminates the program
    exit 1 unless GetOptions(
      'w|with-editor=s' => \$SETTINGS->{EDITOR},
      'g|global'     => sub { $SETTINGS->{IS_GLOBAL} = 1; },
      'l|local'      => sub { $SETTINGS->{IS_GLOBAL} = 0; },
      'h|help'       => \&_help,
      'v|version'    => \&_version,
      'a|aliases'    => sub { $SETTINGS->{ALIAS_ENABLED} = 1; },
      'A|no-aliases' => sub { $SETTINGS->{ALIAS_ENABLED} = 0; },
      'e|exprs'      => sub { $SETTINGS->{EXPR_ENABLED} = 1; },
      'E|no-exprs'   => sub { $SETTINGS->{EXPR_ENABLED} = 0; }
    );
    
    configure_app($SETTINGS);
    
    my ($r_file, $r_key) = process_path($SETTINGS, shift(@ARGV));

    # say "file: $r_file; key: $r_key"; #ASSERT
    &{ $r_subcommands->{$r_action} }(
      $SETTINGS,
      $r_file,
      $r_key
    );
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
can distinguish between "local" configuration listings in the current
working directory, and "system-wide" listings found in the home directory.

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

Note: before continuing, let's define terms:

=over 4

=item listing

a listing is a YAML file that contains pairs of file names and paths.
C<conf> reads listings to show you where configuration files are
located or to open one of those files with an editor

=item listing directory

a directory containing listings. you can create as many of these as
you want arbitrarily nested, so long as they are contained in the
records directory, which is usually named '.conf.d'.

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

show the contents of YAML file or item in YAML file; with no path,
or a path that specifies a listing directory, this subcommand will list
the names (without the '.yml' extension) of files in one of the
listing directories.

=item init

create a new listing, either locally or globally

=back

=head1 Options

=over 4

=item -w|--with-editor=s

set the editor used to open files

=item -g|--global

use files in user's home, if any (B<default>)

=item -l|--local

use files in current directory, if any

=item -h|--help

print this help message

=item -v|--version

print version information

=item -a|--aliases

enable aliases (B<default>)

=item -A|--no-aliases

disable aliases

=item -e|--exprs

enable expressions

=item -E|--no-exprs

disable expressions (B<default>)

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

C<conf> will try the current directory if C<-l> was given as an argument.
otherwise, it will look in the user's home directory.

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
      shells/
        zsh

and that the file "zsh" looks like this:

  ---
  _root: ~
  rc: .zshrc
  alias: .zsh_alias
  ...

then, in the invocation

  $ conf ls -g shells.zsh.alias

"ls" is the subcommand and "shell.zsh.alias" is the path. "-U"
indicates that we are expecting user configuration. in step 1
above, therefore, C<process_path> will find the directory "~/.conf.d/".
in step 2, C<process_path>  will try to find a file or directory called
"~/.conf.d/shells". that is a directory, so it will move
to "~/.conf.d/shells/zsh". this is a file, so it will move
to "alias". C<process_path> will see that "~/.conf.d/shells/zsh/alias"
is not a file, so it will revert the filepath and advance to step
3. in step 3, "alias" will be used as the key, so C<conf> will
load the YAML file "~/.conf.d/shells/zsh" and print the value
at the key "alias".

  $ conf ls -g shells.zsh.alias
  ~/.zsh_alias

=head1 YAML Configuration Listings

here is a sample file that describes an nvim config:

  ---
  _root: /home/boy/.config/nvim
  init: init.vim
  plug: plugins.vim
  binds: bindings.vim
  ...

the key beginning with an "_" is private and cannot be accessed
directly through C<conf>'s command-line interface. if you list
the value of init with

  $ conf ls nvim.init

the value of _root will be concatenated with the value of init,
using the correct separator for Windows and *nix platforms:

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

=item * IS_GLOBAL

boolean. default value 1. set to 0 to force C<conf> to look in the
current working directory rather than the home directory.

=back

=back

=head1 Examples

 $ conf ls -g bash

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
