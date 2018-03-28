# Summary

    `conf` helps you find and open your configuration files using a
    simple notation to identify them called a path and a description of
    your configuration setup in JSON that can be customized by you. C<conf>
    can distinguish between "local" files, "user" files located in
    the home directory, and "system" files. C<conf> uses JSON to
    remember where files are located, which is reflected in the
    format of the path.

# Options

    conf [options]? [path] [data]*

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

# Examples

    `conf -l -U bash`

    lists the bash configuration files in your home directory

    `conf -l bash.var`

    show the full path to the bash configuration file referred to as "var"

    `conf bash`

    opens default file associated with bash

    `conf bash.rc`

    opens the run control file for bash in your home directory

# Copyright and License

Copyright (C) 2018 Adam Marshall.

this software is available under the MIT License
