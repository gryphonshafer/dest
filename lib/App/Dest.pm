package App::Dest;
use strict;
use warnings;

use File::Basename qw( dirname basename );
use File::Copy::Recursive 'dircopy';
use File::DirCompare ();
use File::Find 'find';
use File::Path qw( mkpath rmtree );
use IPC::Run 'run';
use Text::Diff ();

our $VERSION = '1.07';

sub init {
    die "Project already initialized\n" if ( -d '.dest' );
    mkdir('.dest') or die "Unable to create .dest directory\n";
    open( my $watch, '>', '.dest/watch' ) or die "Unable to create .dest/watch file\n";
    return 0;
}

sub add {
    my ( $self, $dir ) = @_;
    $dir =~ s|/$||;

    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    die "No directory specified; usage: dest add [directory]\n" unless ($dir);
    die "Directory specified does not exist\n" unless ( -d $dir );
    die "Directory $dir already added\n" if ( grep { $dir eq $_ } $self->_watches() );

    open( my $watch, '>>', '.dest/watch' ) or die "Unable to write .dest/watch file\n";
    print $watch $dir, "\n";

    mkpath(".dest/$dir");
    return 0;
}

sub rm {
    my ( $self, $dir ) = @_;
    $dir =~ s|/$||;

    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    die "No directory specified; usage: dest add [directory]\n" unless ($dir);
    die "Directory $dir not currently tracked\n" unless ( grep { $dir eq $_ } $self->_watches() );

    my @watches = $self->_watches();
    open( my $watch, '>', '.dest/watch' ) or die "Unable to write .dest/watch file\n";
    print $watch $_, "\n" for ( grep { $_ ne $dir } @watches );

    rmtree(".dest/$dir");
    return 0;
}

sub make {
    my ( $self, $path ) = @_;
    die "No name specified; usage: dest make [path]\n" unless ($path);

    eval {
        mkpath($path);
        for ( qw( deploy verify revert ) ) {
            open( my $file, '>', "$path/$_" ) or die;
            print $file "\n";
        }
    };
    die "Failed to fully make $path; check permissions or existing files\n" if ($@);

    $self->list($path);
    return 0;
}

sub list {
    my ( $self, $path ) = @_;

    if ($path) {
        print join( ' ', map { "$path/$_" } qw( deploy verify revert ) ), "\n";
    }
    else {
        for my $path ( $self->_watches() ) {
            print $path, "\n";

            find( {
                follow   => 1,
                no_chdir => 1,
                wanted   => sub {
                    return unless ( m|/deploy$| );
                    ( my $action = $_ ) =~ s|/deploy$||;
                    print '  ', $action, "\n";
                },
            }, $path );
        }
    }

    return 0;
}

sub status {
    my ($self) = @_;

    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );

    my %seen_actions;
    for ( $self->_watches() ) {
        my ( $this_path, $printed_path ) = ( $_, 0 );

        eval { File::DirCompare->compare( ".dest/$_", $_, sub {
            my ( $a, $b ) = @_;
            return if ( $a and $a =~ /\/dest.wrap$/ or $b and $b =~ /\/dest.wrap$/ );
            print 'diff - ', $this_path, "\n" unless ( $printed_path++ );

            if ( not $b ) {
                print '  - ', substr( $a, 7 ), "\n";
            }
            elsif ( not $a ) {
                print "  + $b\n";
            }
            else {
                ( my $action = $b ) =~ s\/(?:deploy|verify|revert)$\\;
                print "  $action\n" unless ( $seen_actions{$action}++ );
                print "    M $b\n";
            }

            return;
        } ) };

        if ( $@ and $@ =~ /Not a directory/ ) {
            print '? - ', $this_path, "\n";
        }
        else {
            print 'ok - ', $this_path, "\n" unless ($printed_path);
        }
    }

    return 0;
}

sub diff {
    my ( $self, $path ) = @_;

    if ( not defined $path ) {
        $self->diff($_) for ( $self->_watches() );
        return 0;
    }

    eval { File::DirCompare->compare( ".dest/$path", $path, sub {
        my ( $a, $b ) = @_;
        return if ( $a and $a =~ /\/dest.wrap$/ or $b and $b =~ /\/dest.wrap$/ );
        print Text::Diff::diff( $a, $b );
        return;
    } ) };

    return 0;
}

sub update {
    my $self  = shift;
    my @paths = @_;

    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );

    File::DirCompare->compare( ".dest/$_", $_, sub {
        my ( $a, $b ) = @_;
        return if ( $a and $a =~ /\/dest.wrap$/ or $b and $b =~ /\/dest.wrap$/ );

        if ( not $b ) {
            $a =~ s|\.dest/||;
            $self->revert($a);
        }
        elsif ( not $a ) {
            $self->deploy($b);
        }
        else {

            $a =~ s|\.dest/||;
            $a =~ s|/(\w+)$||;
            $b =~ s|/(\w+)$||;

            my $type = $1;

            if ( $type eq 'deploy' ) {
                $self->revert($a);
                $self->deploy($b);
            }
            else {
                $self->dircopy( $a, ".dest/$a" );
            }
        }
    } ) for (
        grep {
            my $watch = $_;
            grep { $_ eq $watch } @paths;
        } $self->_watches()
    );

    return 0;
}

sub verify {
    my ( $self, $path ) = @_;
    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    return $self->_action( $path, 'verify' );
}

sub deploy {
    my ( $self, $name, $redeploy ) = @_;
    die "File to deploy required; usage: dest deploy file\n" unless ($name);
    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    my $rv = $self->_action( $name, 'deploy', $redeploy );
    $self->verify($name);
    dircopy( $name, ".dest/$name" );
    return $rv;
}

sub revert {
    my ( $self, $name ) = @_;
    die "File to revert required; usage: dest revert file\n" unless ($name);
    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    my $rv = $self->_action( ".dest/$name", 'revert' );
    rmtree(".dest/$name");
    return $rv;
}

sub redeploy {
    my ( $self, $name ) = @_;
    return $self->deploy( $name, 'redeploy' );
}

sub revdeploy {
    my ( $self, $name ) = @_;
    $self->revert($name);
    return $self->deploy($name);
}

sub clean {
    my ($self) = @_;
    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    for ( $self->_watches() ) {
        rmtree(".dest/$_");
        dircopy( $_, ".dest/$_" );
    }
    return 0;
}

sub preinstall {
    my ($self) = @_;
    die "Not in project root directory or project not initialized\n" unless ( -d '.dest' );
    for ( $self->_watches() ) {
        rmtree(".dest/$_");
        mkdir(".dest/$_");
    }
    return 0;
}

sub _watches {
    open( my $watch, '<', '.dest/watch' ) or die "Unable to read .dest/watch file\n";
    return map { chomp; $_ } <$watch>;
}

sub _action {
    my ( $self, $path, $type, $redeploy ) = @_;

    if ($path) {
        unless ( -f "$path/$type" ) {
            my $this_file = substr( $path, 7 );
            die "Unable to $type $this_file (perhaps action has already occured)\n";
        }
        $self->_execute( "$path/$type", $redeploy ) or die "Failed to $type $path\n";
    }
    else {
        find( {
            follow   => 1,
            no_chdir => 1,
            wanted   => sub {
                return unless ( /\/$type$/ );
                $self->_execute($_) or die "Failed to $type $_\n";
            },
        }, $self->_watches() );
    }

    return 0;
}

{
    my %seen_files;
    sub _execute {
        my ( $self, $file, $run_quiet, $is_dependency ) = @_;
        return if ( $seen_files{$file}++ );

        my @nodes = split( '/', $file );
        my $type = pop @nodes;
        ( my $action = join( '/', @nodes ) ) =~ s|^\.dest/||;

        if (
            ( $type eq 'deploy' and not $run_quiet and -f '.dest/' . $file ) or
            ( $type eq 'revert' and not -f $file )
        ) {
            if ( $is_dependency ) {
                return;
            }
            else {
                die 'Action already '. $type . "ed\n";
            }
        }

        open( my $content, '<', $file ) or die "Unable to read $file\n";

        $self->_execute( "$_/$type", undef, 'dependency' ) for (
            grep { defined }
            map { /dest\.prereq\b[\s:=-]+(.+?)\s*$/; $1 || undef }
            grep { /dest\.prereq/ } <$content>
        );

        my $wrap;
        shift @nodes if ( $nodes[0] eq '.dest' );
        while (@nodes) {
            my $path = join( '/', @nodes );
            if ( -f "$path/dest.wrap" ) {
                $wrap = "$path/dest.wrap";
                last;
            }
            pop @nodes;
        }

        if ( $type eq 'verify' ) {
            my ( $out, $err );

            run(
                [ grep { defined } ( ($wrap) ? $wrap : undef ), $file ],
                \undef, \$out, \$err,
            ) or die "Failed to execute $file\n";

            chomp($out);
            return ($err) ? 0 : $out if ($run_quiet);

            die "$err\n" if ($err);
            print '', ( ($out) ? 'ok' : 'not ok' ) . " - verify: $action\n";
        }
        else {
            print "begin - $type: $action\n";
            run( [ grep { defined } ( ($wrap) ? $wrap : undef ), $file ] ) or die "Failed to execute $file\n";
            $file =~ s|^\.dest/||;
            print "ok - $type: $action\n";
        }

        return 1;
    }
}

1;
__END__
=pod

=head1 NAME

dest - Deployment State Manager

=head1 SYNOPSIS

dest COMMAND [DIR || NAME]

    dest init            # initialize dest for a project
    dest add DIR         # add a directory to dest tracking list
    dest rm DIR          # remove a directory from dest tracking list
    dest make NAME       # create a named template set (set of 3 files)
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

    dest help            # display command synposis
    dest man             # display man page

=head1 DESCRIPTION

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

=head1 COMMANDS

Typing just C<dest> should bring up the usage instructions, which include a
command list. In nearly all cases, dest assumes you are calling dest from
the root directory of your project. If not, it will complain.

=head2 init

To start using dest, you need to initialize your project by calling C<init>
while in the root directory of your project. (If you are in a different
directory, dest will assume that is your project's root directory.)

The initialization will result in a C<.dest> directory being created.
You'll almost certainly want to add ".dest" to your .gitignore file or
whatever.

=head2 add DIR

Once a project has been initialized, you need to tell dest what directories
you want to "track". Into these tracked directories you'll place subdirectories
with recognizable names, and into each subdirectory a set of 3 files: deploy,
revert, and verify.

For example, let's say you have a database. So you create C<db> in your
project's root directory. Then call C<dest add db> from your root directory.
Inside C<db>, you might create the directory C<db/schema>. And under that
directory, add the files: deploy, revert, and verify.

The deploy file contains the instructions to create the database schema. The
revert file contains the instructions to revert what the deploy file did. And
the verify file let's you verify the deploy file worked.

=head2 rm DIR

This removes a directory from the dest tracking list.

=head2 make NAME

This is a helper command. Given a directory you've already added, it will create
the subdirectory and deploy, revert, and verify files.

    # given db, creates db/schema and the 3 files
    dest make db/schema

As a nice helper bit, C<make> will list the relative paths of the 3 new files.
So if you want, you can do something like this:

    vi `dest make db/schema`

=head2 list [NAME]

If provided a name of an action, it does the last step of C<make>. It lists
out the relative paths of the 3 files, so you can do stuff like:

    vi `dest list db/schema`

If not provided a name of an action, it will list all tracked directories and
every action within each directory.

=head2 status

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

=head2 diff

This will display a diff delta of the differences of any modified action files.
You can specify an optional name parameter that refers to a tracking directory,
action name, or specific sub-action.

    dest diff
    dest diff db/schema
    dest diff db/schema/deploy

=head2 clean

Let's say that for some reason you have a delta between what dest thinks your
system is and what your code says it ought to be, and you really believe your
code is right. You can call C<clean> to tell dest to just assume that what
the code says is right.

=head2 preinstall

Let's say you're setting up a new system or installing the project/application,
so you start by creating yourself a working directory. At some point, you'll
want to deploy all the deploy actions. You'll need to C<init> and C<add> the
directories/paths you need. But dest will have a cache that matches the
current working directory. At this point, you need to C<preinstall> to remove
that cache and be in a state where you can C<update>.

Here's an example of what you might want:

    dest init
    dest add path_to/stuff
    dest add path_to/other_stuff
    dest preinstall
    dest update

=head2 deploy NAME

This tells dest to deploy a specific action. For example, if you called
C<status> and got back results like in the status example above, you might then
want to:

    dest deploy db/new_function

Note that you shouldn't add "/deploy" to the end of that. Also note that a
C<deploy> call will automatically call C<verify> when complete.

=head2 verify [NAME]

This will run the verify step on any given action, or if no action name is
provided, all actions under directories that are tracked.

Unlike deploy and revert files, which can run the user through all sorts of
user input/output, verify files must return some value that is either true
or false. dest will assume that if it sees a true value, verification is
confirmed. If it receives a false value, verification is assumed to have failed.

=head2 revert NAME

This tells dest to revert a specific action. For example, if you deployed
C<db/new_function> but then you wanted to revert it, you'd:

    dest revert db/new_function

=head2 redeploy NAME

This is exactly the same as deploy, except that if you've already deployed an
action, "redeploy" will let you deploy the action again, whereas "deploy"
shouldn't.

=head2 revdeploy NAME

This is exactly the same as conducting a revert of an action followed by a
deploy of the same action.

=head2 update [DIRS]

This will automatically deploy or revert as appropriate to make your system
match the code. This will likely be the most common command you run.

If there are actions in the code that have not been deployed, these will be
deployed. If there are actions that have been deployed that are no longer in
the code, they will be reverted.

If there are actions that are in the code that have been deployed, but the
"deploy" file has changed, then C<update> will revert the previously deployed
"deploy" file then deploy the new "deploy" file. (And note that the deployment
will automatically call C<verify>.)

You can optionally add one or more directories to the end of the update command
to restrict the update to only operate within the directories you specify.
This will not prevent cross-directory dependencies, however. For example, if
you have two tracked directories and limit the update to only one directory and
within the directory there is an action with a dependency on an action in the
non-specificied directory, that action will be triggered.

=head2 help

Displays a synposis of commands and their usage.

=head2 man

Displays the man page for dest.

=head1 DEPENDENCIES

Sometimes you may have deployments (or revertions) that have dependencies on
other deployments (or revertions). For example, if you want to add a column
to a table in a database, that table (and the database) have to exist already.

To define a dependency, place the action's name after a C<dest.prereq> marker,
which itself likely will be after a comment. (The comment marker can be
whatever the language of the deployment file is.) For example, in a SQL file
that adds a column, you might have:

    -- dest.prereq: db/schema

=head1 WRAPPERS

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

Let's then also say that the C<example/ls/deploy> file contains:

    ls

I could create a deployment file C<example/dest.wrap> that looked like this:

    #!/bin/bash
    /bin/bash "$1"

Wrappers will only ever be run from the current code. For example, if you have
a revert file for some action and you checkout your working directory to a
point in time prior to the revert file existing, dest maintains a copy of the
original revert file so it can revert the action. However, it will always rely
on whatever wrapper is in the current working directory.

=head1 SEE ALSO

L<App::Sqitch>.

=head1 AUTHOR

Gryphon Shafer E<lt>gryphon@cpan.orgE<gt>.

  code('Perl') || die;

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
