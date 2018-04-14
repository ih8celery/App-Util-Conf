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
our $VERSION = '0.05';
our $EDITOR  = $ENV{EDITOR} || 'vim';

# general settings
our $LEVEL  = $Level::USER;
our $ACTION = $Action::OPEN;

# special settings
our $ALIAS_ENABLED = 0;
our $EXPR_ENABLED  = 0;
our $CONFIG_FILE   = $ENV{CONF_APP_RC}
      || _join_filepaths($ENV{HOME}, '.confrc');
our $RECORDS_DIR   = $ENV{CONF_APP_RECORDS}
      || _join_filepaths($ENV{HOME}, '.conf.d');

# command-line options
our %OPTS = (
  'w|with-editor=s' => \$EDITOR,
  'S|system'    => sub { $LEVEL = $Level::SYSTEM },
  'U|user'      => sub { $LEVEL = $Level::USER },
  'L|local'     => sub { $LEVEL = $Level::LOCAL },
  'h|help'      => \&_help,
  'v|version'   => \&_version,
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

    if (-f $pp_temp_file) {
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
    return _join_filepaths($RECORDS_DIR, 'user');
  }
  elsif ($locality eq $Level::SYSTEM) {
    return _join_filepaths($RECORDS_DIR, 'system');
  }
  else {
    return _join_filepaths(getcwd(), '.conf.d');
  }
}

# merge parts of path in a way appropriate to platform
sub _join_filepaths {
  my ($left, $right) = @_;

  return $left . '/' . $right;
}

# lists the contents of files or items on stdout
sub list_stuff {
  my ($stuff, $stuff_type) = @_;

  _error('nothing to show') unless defined $stuff;

  if ($stuff_type eq 'file') {
    # stuff is a yaml object which should be printed completely
    # print keys alongside values
    my $root = $ENV{HOME};
    $root = $stuff->{_root} if defined $stuff->{_root};
    $root =~ s/\/$//;

    foreach (keys %$stuff) {
      # forbid keys beginning with '_'
      unless (m/^_/) {
        print $_, ' ';
        if ($stuff->{$_} =~ m/^\//) {
          say $stuff->{$_};
        }
        else {
          say $root, '/', $stuff->{$_};
        }
      }
    }
  }
  else {
    # stuff is fully qualified path
    say $stuff;
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
    if ($r_path_end eq '' && -f $r_file) {
      exec "$EDITOR $r_file";
    }
    elsif ($r_path_end ne '' && defined $r_records->{$r_path_end}) {
      if (defined $r_records->{_root}) {
        exec $EDITOR . ' ' . _join_filepaths(
            $r_records->{_root},
            $r_records->{$r_path_end}
        );
      }
      else {
        exec "$EDITOR $r_records->{$r_path_end}";
      }
    }
    else {
      _error('nothing to open');
    }
  }
  elsif ($ACTION == $Action::LIST) {
    if ($r_path_end eq '') {
      list_stuff($r_records, 'file');
    }
    elsif (defined $r_records->{$r_path_end}) {
      if (defined $r_records->{_root}) {
        $r_path_end =
          _join_filepaths($r_records->{_root}, $r_records->{$r_path_end});

        list_stuff($r_path_end, 'item');
      }
      else {
        list_stuff($r_records->{$r_path_end}, 'item');
      }
    }
    else {
      _error('nothing to show');
    }
  }
}

1;

__END__

=head1 Summary

C<conf> helps you find and open your configuration files using a
simple notation to identify them called a path and a description of
your configuration setup in YAML that can be customized by you. C<conf>
can distinguish between "local" files, "user" files located in
the home directory, and "system" files. C<conf> uses YAML to
remember where files are located, which is reflected in the
format of the path.

=head1 Usage

conf [subcommand] [options] [path]

=head2 Subcommands

=over 4

=item go

open file

=item ls

show the contents of file or item

=back

=head2 Options

-w|--with-editor=s set the editor used to view files
-S|--system        use system files, if any
-U|--user          use files in user's home, if any (default)
-L|--local         use files in current directory, if any
-h|--help          print this help message
-v|--version       print version information

=head2 Path

=head1 Examples

 conf ls -U bash

lists the bash configuration files in your home directory

 conf ls bash.var

show the full path to the bash configuration file referred to as "var"

 conf go bash

opens default file associated with bash

 conf go bash.rc

opens the run control file for bash in your home directory

=cut 
