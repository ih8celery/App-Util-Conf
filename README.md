# Name

conf -- find and open configuration files lazily

# Summary

conf \[subcommand\] \[options\] \[path\]

`conf` helps you find and open your configuration files using a
simple notation to identify them called a path and a description of
your configuration setup in YAML that can be customized by you. `conf`
can distinguish between "local" files, "user" files located in
the home directory, and "system" files. `conf` uses YAML to
remember where files are located. 

`conf` uses three shell variables:

- 1. EDITOR

    if defined, this variable's value will be used as the editor with which
    to open files (via the "go" subcommand)

- 2. CONF\_APP\_RC

    if defined, this variable's value will be used as the full path to the
    YAML file containing defaults and defining aliases and expressions for
    the program

- 3. CONF\_APP\_RECORDS

    if defined, this variable's value is the starting directory for searches
    for configuration listings. this variable should be a relative path
    since it will be used for searching in the home directory as well as the
    current working directory

# Subcommands

- go

    open file, if there is one. this command can open the YAML file
    containing the locations of other configuration files if the
    path ends on the name of one such file. For instance, if you
    have listed configuration files in a file called "bash" and your
    path is "bash", "go" will open that file.

- ls

    show the contents of YAML file or item in YAML file

# Options

- -w|--with-editor=s

    set the editor used to open files

- -S|--system

    use system files, if any

- -U|--user

    use files in user's home, if any (**default**)

- -L|--local

    use files in current directory, if any

- -h|--help

    print this help message

- -v|--version

    print version information

- -a|--aliases

    enable aliases

- -A|--no-aliases

    disable aliases (default)

- -e|--exprs

    enable expressions (default)

- -E|--no-exprs

    disable expressions

# Path

the path is a single argument of one or more dot-delimited strings
which describe the path `conf` will take through the filesystem
and into a YAML file. the path can be thought of as having two parts:
a file part and the key part. the key part may be an empty string,
resulting in the "go" or "ls" subcommand being applied to an entire
file, but part must point to some real file. the path is split into
"file" and "key" in a three part process by the `process_path`
subroutine:

- 1. Locate Starting Point in File System

    based on whether the user has asked for "local", "system", or "user"
    files, a dedicated subroutine will search the current working directory
    and the home directory for a directory called ".conf.d" and a
    subdirectory called either "user", "local", or "system". if this
    directory is found, the full path to this directory is returned and
    the process moves on to step 2. otherwise, the subroutine throws an
    error.

- 2. Create Maximum Valid Filepath

    at this point, a starting point has been identified and the path string
    has been split into an array of strings using '.' as the delimiter.
    each member of this array will be concatenated with the starting file
    until the result is no longer a valid filepath or until the array has
    been consumed. if the final filepath produced in this process is a
    directory and not a regular file, `process_path` will throw an error.
    `process_path` will otherwise advance to the third step.

- 3. Determine the Key

    any element of the array that was not accepted in step 2 (i.e., it was
    not used to create a **valid** filepath) can be accepted in step 3,
    provided that at most one such element may remain in the list. any
    more will result in an error. if there are no array elements left,
    the key will be set to the empty string. once the value of the key
    has been determined, `process_path` returns its results.

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
above, therefore, `process_path` will find the directory "~/.conf.d/user".
in step 2, `process_path`  will try to find a file or directory called
"~/.conf.d/user/shells". that is a directory, so it will move
to "~/.conf.d/user/shells/zsh". this is a file, so it will move
to "alias". `process_path` will see that "~/.conf.d/user/shells/zsh/alias"
is not a file, so it will revert the filepath and advance to step
3\. in step 3, "alias" will be used as the key, so `conf` will
load the YAML file "~/.conf.d/user/shells/zsh" and print the value
at the key "alias".

    $ conf ls -U shells.zsh.alias
    ~/.zsh_alias

# YAML Configuration Listings

here is a sample file that describes an nvim config:

    ---
    _root: /home/body/.config/nvim
    init: init.vim
    plug: plugins.vim
    binds: bindings.vim
    ...

the key beginning with an "\_" is private and cannot be accessed
directly through `conf`'s command-line interface. if you list
the value of init with

    $ conf ls nvim.init

the value of \_root will be concatenated with the value of init,
using the correct separator:

    /home/adamu/.config/nvim/init.vim

# Configuring the App Through the Global Config File

as soon as it launches, `conf` searches for a YAML file in your home
directory called ".confrc". if this file exists, `conf` loads it and
performs three steps: 1) loads any aliases, 2) loads any expressions,
and 3) loads new default values. each of those steps is described below.

- 1. Aliases

    an alias is a string substitution stored under the 'aliases' key. much
    like aliases in bash, an alias is activated when a part of the path
    is recognized as an alias name. some aliases you might like to use
    to maintain a "generic" approach:

        ---
        aliases:
          ed: nvim
          sh: bash
        ...

- 2. Expressions

    an expression is a string which can be evaluated by the shell. its
    output is captured by `conf` and used to replace the part of the
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

- 3. Default Values

    `conf` uses several global variables to control its behavior. some of
    these variables have default values which can be changed at runtime by
    the configuration file. they are the following:

    - ALIAS\_ENABLED

        boolean. default value 0. if 1, `conf` will use the aliases above to
        modify the **path**. otherwise, the aliases will be completely ignored.

    - EXPR\_ENABLED

        boolean. default value 0. if 1, `conf` will use the expressions above
        to modify the **path**. otherwise, expressions will be completely
        ignored.

    - EDITOR

        name of the program to use by default to open files if your subcommand
        is "go".

    - LEVEL

        name of the "level" to use when searching for files. default value
        "user". possible values are "user", "local", and "system".

# Examples

    $ conf ls -U bash

lists the bash configuration files in your home directory

    $ conf ls bash.var

show the full path to the bash configuration file referred to as "var"

    $ conf go bash

opens default file associated with bash

    $ conf go bash.rc

opens the run control file for bash in your home directory

# Copyright and License

This software is copyright (C) 2018, Adam Marshall.

Distributed under the MIT License.
