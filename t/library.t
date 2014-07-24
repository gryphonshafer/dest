#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Cwd 'getcwd';
use File::Path qw( mkpath rmtree );

use constant MODULE => 'App::Dest';

exit main(@ARGV);

my ( $buffer_handle, $buffer );

sub main {
    require_ok(MODULE);

    my $pwd = getcwd();
    mkpath('/tmp/dest_testing/db');
    chdir('/tmp/dest_testing');

    test_basics();

    done_testing();

    chdir($pwd);
    rmtree('/tmp/dest_testing');
    return 0;
}

sub test_basics {

    eval{ App::Dest->init };
    ok( !$@, 'init()' );

    ok( -d '/tmp/dest_testing/.dest', 'init() += directory' );
    ok( -f '/tmp/dest_testing/.dest/watch', 'init() += watch file' );

    eval{ App::Dest->add('db') };
    ok( !$@, 'add()' );

    ok( -d '/tmp/dest_testing/.dest/db', 'add() += directory' );
    is_deeply( [ App::Dest->_watches ], ['db'], 'add() -> (watch file)++' );

    _capture();
    eval{ App::Dest->make('db/schema') };
    my $make = _return();
    ok( !$@, 'make()' );
    ok( $make eq "db/schema/deploy db/schema/verify db/schema/revert\n", 'make() output correct' );

    _capture();
    eval{ App::Dest->status };
    my $status = _return();
    ok( !$@, 'status()' );
    ok( $status eq "diff - db\n  + db/schema\n", 'status() output correct' );

    eval{ App::Dest->clean };
    ok( !$@, 'clean()' );
}

sub _capture {
    undef $buffer;
    open( $buffer_handle, '>', \$buffer );
    select $buffer_handle;
}

sub _return {
    select STDOUT;
    close $buffer_handle;
    return $buffer;
}
