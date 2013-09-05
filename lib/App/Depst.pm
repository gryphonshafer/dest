package App::Depst;
use strict;
use warnings;

use File::Basename qw( dirname basename );
use File::Copy::Recursive 'dircopy';
use File::DirCompare ();
use File::Find 'find';
use File::Path qw( mkpath rmtree );
use IPC::Run 'run';

our $VERSION = '1.01';

sub init {
    die "Project already initialized\n" if ( -d '.depst' );
    mkdir('.depst') or die "Unable to create .depst directory\n";
    open( my $watch, '>', '.depst/watch' ) or die "Unable to create .depst/watch file\n";
    return 0;
}

sub add {
    my ( $self, $dir ) = @_;
    $dir =~ s|/$||;

    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );
    die "No directory specified; usage: depst add [directory]\n" unless ($dir);
    die "Directory specified does not exist\n" unless ( -d $dir );
    die "Directory $dir already added\n" if ( grep { $dir eq $_ } $self->_watches() );

    open( my $watch, '>>', '.depst/watch' ) or die "Unable to write .depst/watch file\n";
    print $watch $dir, "\n";

    dircopy( $dir, ".depst/$dir" );
    return 0;
}

sub make {
    my ( $self, $path ) = @_;
    die "No name specified; usage: depst make [path]\n" unless ($path);

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

    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );

    for ( $self->_watches() ) {
        my ( $this_path, $printed_path ) = ( $_, 0 );

        File::DirCompare->compare( ".depst/$_", $_, sub {
            my ( $a, $b ) = @_;
            return if ( $a and $a =~ /\/depst.wrap$/ or $b and $b =~ /\/depst.wrap$/ );
            print 'diff - ', $this_path, "\n" unless ( $printed_path++ );

            if ( not $b ) {
                print '  - ', substr( $a, 7 ), "\n";
            }
            elsif ( not $a ) {
                print "  + $b\n";
            }
            else {
                print "  M $b\n";
            }

            return;
        } );

        print 'ok - ', $this_path, "\n" unless ($printed_path);
    }

    return 0;
}

sub update {
    my ($self) = @_;

    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );

    File::DirCompare->compare( ".depst/$_", $_, sub {
        my ( $a, $b ) = @_;
        return if ( $a and $a =~ /\/depst.wrap$/ or $b and $b =~ /\/depst.wrap$/ );

        if ( not $b ) {
            $a =~ s|\.depst/||;
            $self->revert($a);
        }
        elsif ( not $a ) {
            $self->deploy($b);
        }
        else {

            $a =~ s|\.depst/||;
            $a =~ s|/(\w+)$||;
            $b =~ s|/(\w+)$||;

            my $type = $1;

            if ( $type eq 'deploy' ) {
                $self->revert($a);
                $self->deploy($b);
            }
            else {
                $self->dircopy( $a, ".depst/$a" );
            }
        }
    } ) for ( $self->_watches() );

    return 0;
}

sub verify {
    my ( $self, $path ) = @_;
    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );
    return $self->_action( $path, 'verify' );
}

sub deploy {
    my ( $self, $name ) = @_;
    die "File to deploy required; usage: depst deploy file\n" unless ($name);
    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );
    my $rv = $self->_action( $name, 'deploy' );
    $self->verify($name);
    dircopy( $name, ".depst/$name" );
    return $rv;
}

sub revert {
    my ( $self, $name ) = @_;
    die "File to revert required; usage: depst revert file\n" unless ($name);
    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );
    my $rv = $self->_action( ".depst/$name", 'revert' );
    rmtree(".depst/$name");
    return $rv;
}

sub clean {
    my ($self) = @_;

    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );
    my @watches = $self->_watches();

    rmtree('.depst');
    $self->init();
    $self->add($_) for (@watches);

    return 0;
}

sub preinstall {
    my ($self) = @_;
    die "Not in project root directory or project not initialized\n" unless ( -d '.depst' );
    for ( $self->_watches() ) {
        rmtree(".depst/$_");
        mkdir(".depst/$_");
    }
    return 0;
}

sub _watches {
    open( my $watch, '<', '.depst/watch' ) or die "Unable to read .depst/watch file\n";
    return map { chomp; $_ } <$watch>;
}

sub _action {
    my ( $self, $path, $type ) = @_;

    if ($path) {
        unless ( -f "$path/$type" ) {
            my $this_file = substr( $path, 7 );
            die "Unable to $type $this_file (perhaps action has already occured)\n";
        }
        $self->_execute("$path/$type") or die "Failed to $type $path\n";
    }
    else {
        find( {
            follow   => 1,
            no_chdir => 1,
            wanted   => sub {
                return unless ( /\/$type$/ );
                $self->_execute($_);
            },
        }, $self->_watches() );
    }

    return 0;
}

{
    my %seen_files;
    sub _execute {
        my ( $self, $file, $quiet_verify ) = @_;
        return if ( $seen_files{$file}++ );

        my @nodes = split( '/', $file );
        my $type = pop @nodes;
        ( my $action = join( '/', @nodes ) ) =~ s|^\.depst/||;

        return if (
            ( $type eq 'deploy' and -f '.depst/' . $file ) or
            ( $type eq 'revert' and not -f $file )
        );

        open( my $content, '<', $file ) or die "Unable to read $file\n";

        $self->_execute("$_/$type") for (
            grep { defined }
            map { /depst\.prereq\b[\s:=-]+(.+?)\s*$/; $1 || undef }
            grep { /depst\.prereq/ } <$content>
        );

        my $wrap;
        shift @nodes if ( $nodes[0] eq '.depst' );
        while (@nodes) {
            my $path = join( '/', @nodes );
            if ( -f "$path/depst.wrap" ) {
                $wrap = "$path/depst.wrap";
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
            return ($err) ? 0 : $out if ($quiet_verify);

            die "$err\n" if ($err);
            print '', ( ($out) ? 'ok' : 'not ok' ) . " - verify: $action\n";
        }
        else {
            print "begin - $type: $action\n";
            run( [ grep { defined } ( ($wrap) ? $wrap : undef ), $file ] ) or die "Failed to execute $file\n";
            $file =~ s|^\.depst/||;
            print "ok - $type: $action\n";
        }

        return 1;
    }
}

1;
__END__
=pod

=head1 NAME

depst - Deployment State Manager

=head1 SYNOPSIS

depst COMMAND [DIR || NAME]

    depst init            # initialize depst for a project
    depst add DIR         # add a directory to depst tracking list
    depst make NAME       # create a named template set (set of 3 files)
    depst list [NAME]     # dump a list of the template set (set of 3 files)
    depst status [DIR]    # check status of all tracked or specific directory
    depst clean           # reset depst state to match current files/directories
    depst preinstall      # set depst state so an "update" will deploy everything

    depst deploy NAME     # deployment of a specific action
    depst verify [NAME]   # verification of tracked actions or specific action
    depst revert NAME     # revertion of a specific action
    depst update          # automaticall deploy or revert to cause currency

    depst help            # display command synposis
    depst man             # display man page

=head1 DESCRIPTION

depst is a simple "deployment state" change management tool. I really like
what Sqitch is doing, but I wanted something that worked on more than just
databases. And I'm not very smart, so I wanted something really simple.
(Both simple to use and simple to maintain.) Thus, depst was born.

Let's say you're working with a group of other software engineers on a
particular software project using your favorite revision control system.
Let's also say that you have a database that undergoes schema changes as
features are developed, and you have various system activities like the
installation of libraries or other applications. Then let's also say the team
braches, works on stuff, shares those branches, reverts, merges, etc. And also
from time to time you want to go back in time a bit so you can reproduce a bug.
Maintaining the database state and the state of the system across all that
activity can be problematic. depst tries to solve this in a very simple way,
letting you be able to deploy, revert, and verify to any point in time in
the development history.

=head1 COMMANDS

Typing just C<depst> should bring up the usage instructions, which include a
command list. In nearly all cases, depst assumes you are calling depst from
the root directory of your project. If not, it will complain.

=head2 init

To start using depst, you need to initialize your project by calling C<init>
while in the root directory of your project. (If you are in a different
directory, depst will assume that is your project's root directory.)

The initialization will result in a C<.depst> directory being created.
You'll almost certainly want to add ".depst" to your .gitignore file or
whatever.

=head2 add DIR

Once a project has been initialized, you need to tell depst what directories
you want to "track". Into these tracked directories you'll place subdirectories
with recognizable names, and into each subdirectory a set of 3 files: deploy,
revert, and verify.

For example, let's say you have a database. So you create C<db> in your
project's root directory. Then call C<depst add db> from your root directory.
Inside C<db>, you might create the directory C<db/schema>. And under that
directory, add the files: deploy, revert, and verify.

The deploy file contains the instructions to create the database schema. The
revert file contains the instructions to revert what the deploy file did. And
the verify file let's you verify the deploy file worked.

=head2 make NAME

This is a helper command. Given a directory you've already added, it will create
the subdirectory and deploy, revert, and verify files.

    # given db, creates db/schema and the 3 files
    depst make db/schema

As a nice helper bit, C<make> will list the relative paths of the 3 new files.
So if you want, you can do something like this:

    vi `depst make db/schema`

=head2 list [NAME]

If provided a name of an action, it does the last step of C<make>. It lists
out the relative paths of the 3 files, so you can do stuff like:

    vi `depst list db/schema`

If not provided a name of an action, it will list all tracked directories and
every action within each directory.

=head2 status [DIR]

This command will tell you your current state compared to what the current code
says your state should be. For example, if you called status with no optional
directory parameter, you might see something like this:

    diff - db
      + db/new_function
      - db/lolcats
      M db/schema/deploy
    ok - etc

depst will report for each tracked directory what are new changes that haven't
yet been deployed (marked with a "+"), features that have been deployed in your
current system state but are missing from the code (marked with a "-"), and
changes to previously existing files (marked with an "M").

If you want, you can provide a specific directory to status, and it'll only
report on the directory.

    depst status db

=head2 clean

Let's say that for some reason you have a delta between what depst thinks your
system is and what your code says it ought to be, and you really believe your
code is right. You can call C<clean> to tell depst to just assume that what
the code says is right.

=head2 preinstall

Let's say you're setting up a new system or installing the project/application,
so you start by creating yourself a working directory. At some point, you'll
want to deploy all the deploy actions. You'll need to C<init> and C<add> the
directories/paths you need. But depst will have a cache that matches the
current working directory. At this point, you need to C<preinstall> to remove
that cache and be in a state where you can C<update>.

Here's an example of what you might want:

    depst init
    depst add path_to/stuff
    depst add path_to/other_stuff
    depst preinstall
    depst update

=head2 deploy NAME

This tells depst to deploy a specific action. For example, if you called
C<status> and got back results like in the status example above, you might then
want to:

    depst deploy db/new_function

Note that you shouldn't add "/deploy" to the end of that. Also note that a
C<deploy> call will automatically call C<verify> when complete.

=head2 verify [NAME]

This will run the verify step on any given action, or if no action name is
provided, all actions under directories that are tracked.

Unlike deploy and revert files, which can run the user through all sorts of
user input/output, verify files must return some value that is either true
or false. depst will assume that if it sees a true value, verification is
confirmed. If it receives a false value, verification is assumed to have failed.

=head2 revert NAME

This tells depst to revert a specific action. For example, if you deployed
C<db/new_function> but then you wanted to revert it, you'd:

    depst revert db/new_function

=head2 update

This will automatically deploy or revert as appropriate to make your system
match the code. This will likely be the most common command you run.

If there are actions in the code that have not been deployed, these will be
deployed. If there are actions that have been deployed that are no longer in
the code, they will be reverted.

If there are actions that are in the code that have been deployed, but the
"deploy" file has changed, then C<update> will revert the previously deployed
"deploy" file then deploy the new "deploy" file. (And note that the deployment
will automatically call C<verify>.)

=head2 help

Displays a synposis of commands and their usage.

=head2 man

Displays the man page for depst.

=head1 DEPENDENCIES

Sometimes you may have deployments (or revertions) that have dependencies on
other deployments (or revertions). For example, if you want to add a column
to a table in a database, that table (and the database) have to exist already.

To define a dependency, place the action's name after a C<depst.prereq> marker,
which itself likely will be after a comment. (The comment marker can be
whatever the language of the deployment file is.) For example, in a SQL file
that adds a column, you might have:

    -- depst.prereq: db/schema

=head1 WRAPPERS

Unless a "wrapper" is used (and thus, by default), depst will assume that the
action files (those 3 files under each action name) are self-contained
executable files. Often if not almost always the action sub-files would be a
lot simpler and contain less code duplication if they were executed through
some sort of wrapper.

Given our database example, we'd likely want each of the action sub-files to be
pure SQL. In that case, we'll need to write some wrapper program that depst
will run that will then consume and run the SQL files as appropriate.

depst looks for wrapper files up the chain from the location of the action file.
Specifically, it'll assume a file is a wrapper if the filename is "depst.wrap".
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

I could create a deployment file C<example/depst.wrap> that looked like this:

    #!/bin/bash
    /bin/bash "$1"

Wrappers will only ever be run from the current code. For example, if you have
a revert file for some action and you checkout your working directory to a
point in time prior to the revert file existing, depst maintains a copy of the
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
