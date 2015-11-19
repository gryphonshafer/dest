use strict;
use warnings;

use Test::Most;
use File::Path 'mkpath';
use lib 't';
use TestLib qw( t_module t_startup t_teardown t_capture );

exit main();

sub main {
    require_ok( t_module() );
    t_startup();

    t_module->init;

    add();
    rm();
    make();
    list();
    watches();

    t_teardown();
    done_testing();
    return 0;
}

sub add {
    mkpath('atd');

    eval{ t_module->add('atd') };

    ok( !$@, 'add' );
    ok( -d '.dest/atd', 'add() += directory' );
    is_deeply( [ t_module->_watches ], ['atd'], 'add() -> (watch file)++' );

    throws_ok(
        sub { t_module->add() },
        qr/No directory specified; usage: dest add \[directory\]/,
        'no dir specified',
    );

    throws_ok(
        sub { t_module->add('notexists') },
        qr/Directory specified does not exist/,
        'dir not exists',
    );

    throws_ok(
        sub { t_module->add('atd') },
        qr/Directory atd already added/,
        'dir already exists',
    );
}

sub rm {
    mkpath('atd2');
    t_module->add('atd2');

    eval{ t_module->rm('atd2') };
    ok( !$@, 'rm' );
    ok( ! -d '.dest/atd2', 'rm() -= directory' );
    is_deeply( [ t_module->_watches ], ['atd'], 'rm() -> (watch file)--' );

    throws_ok(
        sub { t_module->rm() },
        qr/No directory specified; usage: dest rm \[directory\]/,
        'no dir specified for rm',
    );

    throws_ok(
        sub { t_module->rm('untracked') },
        qr/Directory untracked not currently tracked/,
        'dir not tracked',
    );
}

sub make {
    my ( $out, $err, $exp ) = t_capture( sub { t_module->make('atd/state') } );
    ok( ! $exp, 'make' );
    ok( $out eq "atd/state/deploy atd/state/verify atd/state/revert\n", 'make() output correct' );

    throws_ok(
        sub { t_module->make() },
        qr/No name specified; usage: dest make \[path\]/,
        'no name specified for make',
    );
}

sub list {
    mkpath('new');
    t_module->add('new');

    ok( ( t_capture( sub { t_module->list } ) )[0] eq "atd\n  atd/state\nnew\n", 'list (blank)' );
    ok(
        ( t_capture(
            sub { t_module->list('atd/state') }
        ) )[0] eq "atd/state/deploy atd/state/verify atd/state/revert\n",
        'list (action)',
    );

    t_module->rm('new');

    ok( ( t_capture( sub { t_module->list } ) )[0] eq "atd\n  atd/state\n", 'list (again)' );
}

sub watches {
    is( ( t_capture( sub { t_module->watches } ) )[0], "atd\n", 'watches()' );
}
