shconf version 0.1.0

# What is shconf?
this perl script can modify and source user-owned shell configuration files
automatically or open the right file with the default editor.
shconf is aware of 5 types of files:
  history
  aliases
  functions
  run control
  variables

I wrote this script as a handy aid to configuring my shell of choice
in a safe, controlled manner independent of project or other usage. I
like to keep configuration separate and organized whenever possible.
suggestions and pull requests are usually welcome.

# Usage

shconf [options] [arguments]

(control locality: user files (-U) or project files (-P))
(control action: source-file, edit-file, add-config-to-file,
   remove-config-from-file, list-files, list-project, load-shconf)
(control configuration affected: run-control setting (-r, default), 
   alias (-a), functions (-f), history (-h), vars (-v))

## Options


# Installation

move the script into your path and mark is as an executable.


# Copyright and License

Copyright (C) 2018 Adam Marshall

This software is available under the MIT License. (TODO)
