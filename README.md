# NAME

App::Dest - Deployment State Manager

# VERSION

version 1.36

[![test](https://github.com/gryphonshafer/dest/workflows/test/badge.svg)](https://github.com/gryphonshafer/dest/actions?query=workflow%3Atest)
[![codecov](https://codecov.io/gh/gryphonshafer/dest/graph/badge.svg)](https://codecov.io/gh/gryphonshafer/dest)

# SYNOPSIS

dest COMMAND \[OPTIONS\]

    dest init               # initialize dest for a project
    dest add DIR            # add a directory to dest tracking list
    dest rm DIR             # remove a directory from dest tracking list

    dest watches            # returns a list of watched directories
    dest putwatch FILE      # set watch list to be what's in a file
    dest writewatch         # creates watch file in project root directory

    dest make NAME [EXT]    # create a named template set (set of 3 files)
    dest expand NAME        # dump a list of the template set (set of 3 files)
    dest list [FILTER]      # list all actions in all watches
    dest prereqs [FILTER]   # like "list" but include report of prereqs

    dest status             # check status of tracked directories
    dest diff [NAME]        # display a diff of any modified actions
    dest clean [NAME]       # reset dest state to match current files/dirs
    dest preinstall [NAME]  # set dest state so an update will deploy everything
    dest nuke               # de-initialize dest; remove all dest stuff

    dest deploy NAME [-d]   # deployment of a specific action
    dest verify [NAME]      # verification of tracked actions or specific action
    dest revert NAME [-d]   # revertion of a specific action
    dest redeploy NAME [-d] # deployment of a specific action
    dest revdeploy NAME     # revert and deployment of a specific action
    dest update [INCS] [-d] # automaticall deploy or revert to cause currency

    dest version            # dest current version
    dest help               # display command synposis
    dest man                # display man page

# DESCRIPTION

`dest` is a simple "deployment state" change management tool. Inspired by
what Sqitch does for databases, it provides a simple mechanism for writing
deploy, verify, and revert parts of a change action. The typical use of
`dest` is in a development context because it allows for simplified state
changes when switching between branches (as an example).

Let's say you're working with a group of other software engineers on a
particular software project using your favorite revision control system.
Let's also say that you have a database that undergoes schema changes as
features are developed, and you have various system activities like the
installation of libraries or other applications. Then let's also say the team
branches, works on stuff, shares those branches, reverts, merges, etc. And also
from time to time you want to go back in time a bit so you can reproduce a bug.
Maintaining the database state and the state of the system across all that
activity can be problematic. `dest` tries to solve this in a very simple way,
letting you be able to deploy, revert, and verify to any point in time in
the development history.

See below for an example scenario that may help illustrate using `dest` in a
pseudo real world situation.

Note that using `dest` for production deployment, provisioning, or
configuration management is not advised. Use a full-featured configuration
management tool instead.

# COMMANDS

Typing just `dest` should bring up the usage instructions, which include a
command list. You should be able to execute `dest` commands from any directory
at or below your project's root directory once the project has been initiated
in `dest`.

## init

To start using `dest`, you need to initialize your project by calling `init`
while in the root directory of your project. (If you are in a different
directory, `dest` will assume that is your project's root directory.)

The initialization will result in a `.dest` directory being created.
You'll almost certainly want to add ".dest" to your `.gitignore` file or
similar revision control ignore file.

## add DIR

Once a project has been initialized, you need to tell `dest` what directories
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

This removes a directory from the `dest` tracking list.

## watches

Returns a list of tracked or watched directories.

## putwatch FILE

Sets the current list of tracked or watched directories to be what's in a file.
For example, you could do this:

    dest watches > dest.watch
    echo 'new_dir_to_watch' >> dest.watch
    dest putwatch dest.watch

## writewatch

Creates (or overwrites) a watch file in the project root directory with the
contents of the currently watched directories.

## make NAME \[EXT\]

This is a helper command. Given a directory you've already added, it will create
the subdirectory and deploy, revert, and verify files.

    # given db, creates db/schema and the 3 files
    dest make db/schema

As a nice helper bit, `make` will list the relative paths of the 3 new files.
So if you want, you can do something like this:

    vi `dest make db/schema`

Optionally, you can specify an extension for the created files. For example:

    vi `dest make db/schema sql`
    # this will create and open in vi:
    #    db/schema/deploy.sql
    #    db/schema/revert.sql
    #    db/schema/verify.sql

And optionally, you can include any date/time format supported by [POSIX](https://metacpan.org/pod/POSIX)
`strftime`.

    dest make db/%s_action sql

## expand NAME

This command lists out the relative paths and names of the 3 files of the
action provided, so you can do stuff like:

    vi `dest expand db/schema`

## list \[FILTER\]

This command will list all tracked directories and every action within each
directory. If provided a filter, it will limit what's displayed to actions
containing the filter.

## prereqs \[FILTER\]

This command will list every action within any tracked directory, then for each
action, it will list any prereqs of that action. If provided a filter, it will
limit what's displayed to actions containing the filter.

## status

This command will tell you your current state compared to what the current code
says your state should be. For example, you might see something like this:

    diff - db
      + db/new_function
      - db/lolcats
      M db/schema/deploy
    ok - etc

`dest` will report for each tracked directory what are new changes that haven't
yet been deployed (marked with a "+"), features that have been deployed in your
current system state but are missing from the code (marked with a "-"), and
changes to previously existing files (marked with an "M").

## diff \[NAME\]

This will display a diff delta of the differences of any modified action files.
You can specify an optional name parameter that refers to a tracking directory,
action name, or specific sub-action.

    dest diff
    dest diff db/schema
    dest diff db/schema/deploy

## clean \[NAME\]

Let's say that for some reason you have a delta between what `dest` thinks your
system is and what your code says it ought to be, and you really believe your
code is right. You can call `clean` to tell `dest` to just assume that what
the code says is right.

You can optionally provide a specific action or even a step of an action to
`clean`. For example:

    dest clean db/schema
    dest clean db/schema/deploy

## preinstall \[NAME\]

Let's say you're setting up a new system or installing the project/application,
so you start by creating yourself a working directory. At some point, you'll
want to deploy all the deploy actions. You'll need to `init` and `add` the
directories/paths you need. But `dest` will have a cache that matches the
current working directory. At this point, you need to `preinstall` to remove
that cache and be in a state where you can `update`.

Here's an example of what you might want:

    dest init
    dest add path_to/stuff
    dest add path_to/other_stuff
    dest preinstall
    dest update

You can optionally provide a specific action or even a step of an action to
`preinstall` similar to `clean`.

## nuke

Completely remove all traces of `dest`. In effect, this is a de-initialization
of `dest`, like an un-`init` command. It's like `preinstall`, but it reverses
all initializations and watches.

## deploy NAME \[-d\]

This tells `dest` to deploy a specific action. For example, if you called
`status` and got back results like in the status example above, you might then
want to:

    dest deploy db/new_function

Note that you shouldn't add "/deploy" to the end of that. Also note that a
`deploy` call will automatically call `verify` when complete.

Adding a "-d" flag to the command will cause a "dry run" to run, which will
not perform any actions but will instead report what actions would happen.

## verify \[NAME\]

This will run the verify step on any given action, or if no action name is
provided, all actions under directories that are tracked.

Unlike deploy and revert files, which can run the user through all sorts of
user input/output, verify files must return some value that is either true
or false. `dest` will assume that if it sees a true value, verification is
confirmed. If it receives a false value, verification is assumed to have failed.

## revert NAME \[-d\]

This tells `dest` to revert a specific action. For example, if you deployed
`db/new_function` but then you wanted to revert it, you'd:

    dest revert db/new_function

Adding a "-d" flag to the command will cause a "dry run" to run, which will
not perform any actions but will instead report what actions would happen.

## redeploy NAME \[-d\]

This is exactly the same as deploy, except that if you've already deployed an
action, "redeploy" will let you deploy the action again, whereas "deploy"
shouldn't.

Adding a "-d" flag to the command will cause a "dry run" to run, which will
not perform any actions but will instead report what actions would happen.

## revdeploy NAME

This is exactly the same as conducting a revert of an action followed by a
deploy of the same action.

## update \[INCS\] \[-d\]

This will automatically deploy or revert as appropriate to make your system
match the code. This will likely be the most common command you run.

If there are actions in the code that have not been deployed, these will be
deployed. If there are actions that have been deployed that are no longer in
the code, they will be reverted.

If there are actions that are in the code that have been deployed, but the
"deploy" file has changed, then `update` will revert the previously deployed
"deploy" file then deploy the new "deploy" file. (And note that the deployment
will automatically call `verify`.)

You can optionally add one or more "INCS" strings to the update command to
restrict the update to only perform operations that include one of the "INCS" in
its action file. So for example, let's say you have a "db/changes" directory
with some actions and a "etc/changes" directory with some actions. If you were
to specify "db/changes" as one of your "INCS", this would only  update actions
from that directory tree.

Adding a "-d" flag to the command will cause a "dry run" to run, which will
not perform any actions but will instead report what actions would happen.

## version

Displays the current `dest` version.

## help

Displays a synposis of commands and their usage.

## man

Displays the man page for `dest`.

# DEPENDENCIES

Sometimes you may have deployments that have dependencies on other deployments.
For example, if you want to add a column to a table in a database, that table
(and the database) have to exist already.

To define a dependency, place the action's name after a `dest.prereq` marker in
the deploy action file. This will likely need to be in the form of a comment.
(The comment marker can be whatever the language of the deployment file is.) For
example, in a SQL file that adds a column, you might have:

    -- dest.prereq: db/schema

Dependencies are defined only in deploy actions. Reverting infers its dependency
tree from the  dependencies defined in deploy actions, just in reverse.

# WRAPPERS

Unless a "wrapper" is used (and thus, by default), `dest` will assume that the
action files (those 3 files under each action name) are self-contained
executable files. Often if not almost always the action sub-files would be a
lot simpler and contain less code duplication if they were executed through
some sort of wrapper.

Given our database example, we'd likely want each of the action sub-files to be
pure SQL. In that case, we'll need to write some wrapper program that `dest`
will run that will then consume and run the SQL files as appropriate.

`dest` looks for wrapper files up the chain from the location of the action
file. Specifically, it'll assume a file is a wrapper if the filename is
"dest.wrap". If such a file is found, then that file is called, and the name of
the action sub-file is passed as its only argument.

As an example, let's say I created an action set that looked like this

    example/
        ls/
            deploy
            revert
            verify

Let's then also say that the `example/ls/deploy` file contains: `ls`

I could create a deployment file `example/dest.wrap` that looked like this:

    #!/bin/sh
    /bin/sh "$1"

Wrappers will only ever be run from the current code. For example, if you have
a revert file for some action and you checkout your working directory to a
point in time prior to the revert file existing, `dest` maintains a copy of the
original revert file so it can revert the action. However, it will always rely
on whatever wrapper is in the current working directory.

The `dest.wrap` is called with two parameters: first, the name of the change
program, and second, the action type ("deploy", "revert", "verify").

# WATCH FILE

Optionally, you can elect to use a watch file that can be committed to your
favorite revision control system. In the root directory of your project, create
a filed called "dest.watch" and list therein the directories (relative to the
root directory of the project) to watch.

If this "dest.watch" file exists in the root directory of your project, `dest`
will add the following behavior:

During an "init" action, the `dest.watch` file will be read to setup all
watched directories (as though you manually called the "add" action on each).

During a "status" action, `dest` will report any differences between your
current watch list and the `dest.watch` file.

During an "update" action, `dest` will automatically add (as if you manually
called the "add" action) each directory in the `dest.watch` file that is
currently not watched by `dest` prior to executing the update action.

# EXAMPLE SCENARIO

To help illustrate what `dest` can do, consider the following example scenario.
You start a new project that requires the use of a typical database. You want to
control the schema of that database with progressively executed SQL files. You
also have data operations that require more functionality than what SQL can
provide, so you'd like to have data operations handled by progressively executed
Perl programs.

## Project Initiation

You could setup your changes and `dest` as follows (starting in your project's
root directory):

    mkdir db data     # create the directories
    dest init         # initiate dest for your project
    dest add db data  # add the directories to the dest watch list
    dest writewatch   # write the watch list (so others can init without adding)
    dest status       # show the current status (which is everything is OK)

## Create Schema Action

The next step would probably be to create your database schema as a `dest`
action. Actions include deploy, verify, and revert files. You can use the "make"
command to create these files for you. The command will return the list of files
created, so you can wrap the command to your favorite editor.

    dest make db/schema sql       # create "schema" action as ".sql" files
    vi `dest list db/schema`      # list the "schema" files into vi
    vi `dest make db/schema sql`  # the previous 2 commands as 1 command

Your deploy file will be the SQL required to create your schema. The revert file
reverts what the deploy file deploys. The verify file needs to return some
positive value if and only if the deploy action worked.

Since your local CLI shell probably doesn't know how to execute SQL files
natively, you'll likely need to create a `dest.wrap` file.

    touch db/dest.wrap && chmod u+x db/dest.wrap && vi db/dest.wrap

This file if it exists will get executed instead of the deploy, verify, and
revert files, and it will be passed the action file being executed.

## Status and Deploying

Now, check the project's `dest` status:

    dest s  # short for "dest status"

You should see:

    ok - data
    diff - db
      + db/schema

This indicates that the "schema" action exists in your code but has not been
executed on your environment. To execute, you have a couple options:

    dest deploy db/schema  # explicitly deploy the "schema" action
    dest update            # make dest do whatever status says needs to be done

If you run `dest update` and there's nothing to do, `dest` will happily do
nothing. If you run `dest deploy db/schema` after having already deployed
"schema", `dest` will complain that "schema" has already been deployed. If you
really, really want to run a deploy of "schema" again:

    dest redeploy db/schema  # deploy "schema" even if you already did

## Changing a Deployed Action

If you discover you made a mistake in a table definition inside your "schema"
deploy action file, you could either create a second action to change that table
or change the "schema" deploy and "revdeploy" to revert the old "schema" deploy
action and deploy the new "schema" deploy action. Let's alter the deploy action
already created, then check status.

    vi db/schema/deploy.sql  # fix the table definition
    dest status

You should see something like:

    ok - data
    diff - db
      db/schema/deploy.sql
        M db/schema/deploy.sql

This indicates that the `schema/deploy` action is different than what was
deployed. You can revert the action and deploy it with the "revert" and "deploy"
actions, or do it in a single "revdeploy" command:

    dest revert db/schema     # revert old action
    dest deploy db/schema     # deploy new action
    dest revdeploy db/schema  # revert old action and deploy new action

## Action with a Dependency

Now let's create a data action, a Perl program that will do things and stuff
to insert data into the database. To work, this action obviously will require
the schema action to have already been deployed.

    vi `dest make data/stuff pl`  # create the action and edit the files

Inside the `data/stuff/deploy.pl` file, include the following line:

    # dest.prereq: db/schema

## Other Developers

Now let's say you invite a friend or coworker to the project. That person might
do something like this:

    git clone https://example.com/example_scenario project
    cd project
    dest init    # initiates dest and sets up watches from the watch file
    dest update  # brings the local environment

With the "update" command, `dest` will notice that the "db/schema" and
"data/stuff" actions haven't been deployed. It'll also notice that "data/stuff"
depends on "db/schema", so it'll deploy the schema before it deploys the data.

What's especially fun now is that this other developer can branch and do all
sorts of work requiring `dest` actions in parallel to you doing other `dest`
actions in parallel on different branches. If this new developer wants you to
help test some changes, you just checkout the developer's branch and run a
`dest update`. `dest` will revert whatever changes you have in your
environment that don't exist in the other developer's environment, and will
then deploy the other developer's new actions.

    git checkout other_branch && dest update
    prove t
    git checkout my_branch && dest update

# SEE ALSO

[App::Sqitch](https://metacpan.org/pod/App%3A%3ASqitch).

You can also look for additional information at:

- [GitHub](https://github.com/gryphonshafer/dest)
- [MetaCPAN](https://metacpan.org/pod/App::Dest)
- [GitHub Actions](https://github.com/gryphonshafer/dest/actions)
- [Codecov](https://codecov.io/gh/gryphonshafer/dest)
- [CPANTS](http://cpants.cpanauthors.org/dist/App-Dest)
- [CPAN Testers](http://www.cpantesters.org/distro/A/App-Dest.html)

# AUTHOR

Gryphon Shafer <gryphon@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2013-2050 by Gryphon Shafer.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
