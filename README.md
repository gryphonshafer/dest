# NAME

App::Dest - Deployment State Manager

# VERSION

version 1.14

[![Build Status](https://travis-ci.org/gryphonshafer/dest.svg)](https://travis-ci.org/gryphonshafer/dest)
[![Coverage Status](https://coveralls.io/repos/gryphonshafer/dest/badge.png)](https://coveralls.io/r/gryphonshafer/dest)

# SYNOPSIS

dest COMMAND \[DIR || NAME\]

    dest init            # initialize dest for a project
    dest add DIR         # add a directory to dest tracking list
    dest rm DIR          # remove a directory from dest tracking list
    dest make NAME [EXT] # create a named template set (set of 3 files)
    dest watches         # returns a list of watched directories
    dest list [NAME]     # dump a list of the template set (set of 3 files)
    dest status          # check status of tracked directories
    dest diff [NAME]     # display a diff of any modified actions
    dest clean           # reset dest state to match current files/directories
    dest preinstall      # set dest state so an "update" will deploy everything

    dest deploy NAME     # deployment of a specific action
    dest verify [NAME]   # verification of tracked actions or specific action
    dest revert NAME     # revertion of a specific action
    dest redeploy NAME   # deployment of a specific action
    dest revdeploy NAME  # revert and deployment of a specific action
    dest update [DIRS]   # automaticall deploy or revert to cause currency

    dest version         # dest current version
    dest help            # display command synposis
    dest man             # display man page

# DESCRIPTION

dest is a simple "deployment state" change management tool. Inspired by
what Sqitch does for databases, it provides a simple mechanism for writing
deploy, verify, and revert parts of a change action. The typical use of
dest is in a development context because it allows for simplified state
changes when switching between branches (as an example).

Let's say you're working with a group of other software engineers on a
particular software project using your favorite revision control system.
Let's also say that you have a database that undergoes schema changes as
features are developed, and you have various system activities like the
installation of libraries or other applications. Then let's also say the team
braches, works on stuff, shares those branches, reverts, merges, etc. And also
from time to time you want to go back in time a bit so you can reproduce a bug.
Maintaining the database state and the state of the system across all that
activity can be problematic. dest tries to solve this in a very simple way,
letting you be able to deploy, revert, and verify to any point in time in
the development history.

Using dest for production deployment, provisioning, or configuration management
is not advised. Use something like Angular et al instead. Angular (or whatever
CM tool you prefer) can use dest to perform some actions.

# COMMANDS

Typing just `dest` should bring up the usage instructions, which include a
command list. In nearly all cases, dest assumes you are calling dest from
the root directory of your project. If not, it will complain.

## init

To start using dest, you need to initialize your project by calling `init`
while in the root directory of your project. (If you are in a different
directory, dest will assume that is your project's root directory.)

The initialization will result in a `.dest` directory being created.
You'll almost certainly want to add ".dest" to your .gitignore file or
whatever.

## add DIR

Once a project has been initialized, you need to tell dest what directories
you want to "track". Into these tracked directories you'll place subdirectories
with recognizable names, and into each subdirectory a set of 3 files: deploy,
revert, and verify.

For example, let's say you have a database. So you create `db` in your
project's root directory. Then call `dest add db` from your root directory.
Inside `db`, you might create the directory `db/schema`. And under that
directory, add the files: deploy, revert, and verify.

The deploy file contains the instructions to create the database schema. The
revert file contains the instructions to revert what the deploy file did. And
the verify file let's you verify the deploy file worked.

## rm DIR

This removes a directory from the dest tracking list.

## make NAME \[EXT\]

This is a helper command. Given a directory you've already added, it will create
the subdirectory and deploy, revert, and verify files.

    # given db, creates db/schema and the 3 files
    dest make db/schema

As a nice helper bit, `make` will list the relative paths of the 3 new files.
So if you want, you can do something like this:

    vi `dest make db/schema`

Optionally, you can specify an extention for the created files. For example:

    vi `dest make db/schema sql`
    # this will create and open in vi:
    #    db/schema/deploy.sql
    #    db/schema/revert.sql
    #    db/schema/verify.sql

## watches

Returns a list of tracked or watched directories.

## list \[NAME\]

If provided a name of an action, it does the last step of `make`. It lists
out the relative paths of the 3 files, so you can do stuff like:

    vi `dest list db/schema`

If not provided a name of an action, it will list all tracked directories and
every action within each directory.

## status

This command will tell you your current state compared to what the current code
says your state should be. For example, you might see something like this:

    diff - db
      + db/new_function
      - db/lolcats
      M db/schema/deploy
    ok - etc

dest will report for each tracked directory what are new changes that haven't
yet been deployed (marked with a "+"), features that have been deployed in your
current system state but are missing from the code (marked with a "-"), and
changes to previously existing files (marked with an "M").

## diff

This will display a diff delta of the differences of any modified action files.
You can specify an optional name parameter that refers to a tracking directory,
action name, or specific sub-action.

    dest diff
    dest diff db/schema
    dest diff db/schema/deploy

## clean

Let's say that for some reason you have a delta between what dest thinks your
system is and what your code says it ought to be, and you really believe your
code is right. You can call `clean` to tell dest to just assume that what
the code says is right.

## preinstall

Let's say you're setting up a new system or installing the project/application,
so you start by creating yourself a working directory. At some point, you'll
want to deploy all the deploy actions. You'll need to `init` and `add` the
directories/paths you need. But dest will have a cache that matches the
current working directory. At this point, you need to `preinstall` to remove
that cache and be in a state where you can `update`.

Here's an example of what you might want:

    dest init
    dest add path_to/stuff
    dest add path_to/other_stuff
    dest preinstall
    dest update

## deploy NAME

This tells dest to deploy a specific action. For example, if you called
`status` and got back results like in the status example above, you might then
want to:

    dest deploy db/new_function

Note that you shouldn't add "/deploy" to the end of that. Also note that a
`deploy` call will automatically call `verify` when complete.

## verify \[NAME\]

This will run the verify step on any given action, or if no action name is
provided, all actions under directories that are tracked.

Unlike deploy and revert files, which can run the user through all sorts of
user input/output, verify files must return some value that is either true
or false. dest will assume that if it sees a true value, verification is
confirmed. If it receives a false value, verification is assumed to have failed.

## revert NAME

This tells dest to revert a specific action. For example, if you deployed
`db/new_function` but then you wanted to revert it, you'd:

    dest revert db/new_function

## redeploy NAME

This is exactly the same as deploy, except that if you've already deployed an
action, "redeploy" will let you deploy the action again, whereas "deploy"
shouldn't.

## revdeploy NAME

This is exactly the same as conducting a revert of an action followed by a
deploy of the same action.

## update \[DIRS\]

This will automatically deploy or revert as appropriate to make your system
match the code. This will likely be the most common command you run.

If there are actions in the code that have not been deployed, these will be
deployed. If there are actions that have been deployed that are no longer in
the code, they will be reverted.

If there are actions that are in the code that have been deployed, but the
"deploy" file has changed, then `update` will revert the previously deployed
"deploy" file then deploy the new "deploy" file. (And note that the deployment
will automatically call `verify`.)

You can optionally add one or more directories to the end of the update command
to restrict the update to only operate within the directories you specify.
This will not prevent cross-directory dependencies, however. For example, if
you have two tracked directories and limit the update to only one directory and
within the directory there is an action with a dependency on an action in the
non-specificied directory, that action will be triggered.

## version

Displays the current dest version.

## help

Displays a synposis of commands and their usage.

## man

Displays the man page for dest.

# DEPENDENCIES

Sometimes you may have deployments (or revertions) that have dependencies on
other deployments (or revertions). For example, if you want to add a column
to a table in a database, that table (and the database) have to exist already.

To define a dependency, place the action's name after a `dest.prereq` marker,
which itself likely will be after a comment. (The comment marker can be
whatever the language of the deployment file is.) For example, in a SQL file
that adds a column, you might have:

    -- dest.prereq: db/schema

# WRAPPERS

Unless a "wrapper" is used (and thus, by default), dest will assume that the
action files (those 3 files under each action name) are self-contained
executable files. Often if not almost always the action sub-files would be a
lot simpler and contain less code duplication if they were executed through
some sort of wrapper.

Given our database example, we'd likely want each of the action sub-files to be
pure SQL. In that case, we'll need to write some wrapper program that dest
will run that will then consume and run the SQL files as appropriate.

dest looks for wrapper files up the chain from the location of the action file.
Specifically, it'll assume a file is a wrapper if the filename is "dest.wrap".
If such a file is found, then that file is called, and the name of the action
sub-file is passed as its only argument.

As an example, let's say I created an action set that looked like this

    example/
        ls/
            deploy
            revert
            verify

Let's then also say that the `example/ls/deploy` file contains:

    ls

I could create a deployment file `example/dest.wrap` that looked like this:

    #!/bin/bash
    /bin/bash "$1"

Wrappers will only ever be run from the current code. For example, if you have
a revert file for some action and you checkout your working directory to a
point in time prior to the revert file existing, dest maintains a copy of the
original revert file so it can revert the action. However, it will always rely
on whatever wrapper is in the current working directory.

# WATCH FILE

Optionally, you can elect to use a watch file that can be committed to your
favorite revision control system. In the root dirctory of your project, create
a filed called "dest.watch" and list therein the directores (relative to the
root directory of the project) to watch.

If this "dest.watch" file exists in the root directory of your project, dest
will add the following behavior:

During an "init" action, the dest.watch file will be read to setup all watched
directories (as though you manually called the "add" action on each).

During a "status" action, dest will report any differences between your current
watch list and the dest.watch file.

During an "update" action, dest will automatically add (as if you manually
called the "add" action) each directory in the dest.watch file that is
currently not watched by dest prior to executing the update action.

# SEE ALSO

[App::Sqitch](https://metacpan.org/pod/App::Sqitch).

You can also look for additional information at:

- [GitHub](https://github.com/gryphonshafer/dest)
- [CPAN](http://search.cpan.org/dist/App-Dest)
- [MetaCPAN](https://metacpan.org/pod/App::Dest)
- [AnnoCPAN](http://annocpan.org/dist/App-Dest)
- [Travis CI](https://travis-ci.org/gryphonshafer/dest)
- [Coveralls](https://coveralls.io/r/gryphonshafer/dest)
- [CPANTS](http://cpants.cpanauthors.org/dist/App-Dest)
- [CPAN Testers](http://www.cpantesters.org/distro/A/App-Dest.html)

# AUTHOR

Gryphon Shafer &lt;gryphon@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Gryphon Shafer.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
