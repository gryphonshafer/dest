#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Cwd 'getcwd';
use File::Path qw( mkpath rmtree );

use constant MODULE => 'App::Depst';

exit main(@ARGV);

my ( $buffer_handle, $buffer );

sub main {
    require_ok(MODULE);

    my $pwd = getcwd();
    mkpath('/tmp/depst_testing/db');
    chdir('/tmp/depst_testing');

    test_basics();

    done_testing();

    chdir($pwd);
    rmtree('/tmp/depst_testing');
    return 0;
}

sub test_basics {

    eval{ App::Depst->init };
    ok( !$@, 'init()' );

    ok( -d '/tmp/depst_testing/.depst', 'init() += directory' );
    ok( -f '/tmp/depst_testing/.depst/watch', 'init() += watch file' );

    eval{ App::Depst->add('db') };
    ok( !$@, 'add()' );

    ok( -d '/tmp/depst_testing/.depst/db', 'add() += directory' );
    is_deeply( [ App::Depst->_watches ], ['db'], 'add() -> (watch file)++' );

    _capture();
    eval{ App::Depst->make('db/schema') };
    my $make = _return();
    ok( !$@, 'make()' );
    ok( $make eq "db/schema/deploy db/schema/verify db/schema/revert\n", 'make() output correct' );

    _capture();
    eval{ App::Depst->status };
    my $status = _return();
    ok( !$@, 'status()' );
    ok( $status eq "diff - db\n  + db/schema\n", 'status() output correct' );

    eval{ App::Depst->clean };
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
