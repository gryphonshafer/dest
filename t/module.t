use strict;
use warnings;

use Test::Most;
use Cwd 'getcwd';
use File::Path qw( mkpath rmtree );

use constant {
    MODULE => 'App::Dest',
    DIR    => ( ($ENV{APPDESTDIR}) ? $ENV{APPDESTDIR} . $$ : '/tmp/dest_testing_' . $$ ),
};

my ( $buffer_handle, $buffer );
exit main(@ARGV);

sub main {
    require_ok(MODULE);

    my $pwd = getcwd();
    mkpath(DIR);
    chdir(DIR);

    init();
    add();
    rm();
    make();
    list();
    status();
    clean();
    diff();

    chdir($pwd);
    rmtree(DIR);

    done_testing();
    return 0;
}

#-----------------------------------------------------------------------------

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

#-----------------------------------------------------------------------------

sub init {
    eval{ MODULE->init };
    ok( !$@, 'init' );

    ok( -d DIR . '/.dest', 'init() += directory' );
    ok( -f DIR . '/.dest/watch', 'init() += watch file' );
}

sub add {
    mkpath( DIR . '/db' );

    eval{ MODULE->add('db') };
    ok( !$@, 'add' );

    ok( -d DIR . '/.dest/db', 'add() += directory' );
    is_deeply( [ MODULE->_watches ], ['db'], 'add() -> (watch file)++' );
}

sub rm {
    mkpath( DIR . '/db2' );
    MODULE->add('db2');

    eval{ MODULE->rm('db2') };
    ok( !$@, 'rm' );
    ok( ! -d DIR . '/.dest/db2', 'rm() -= directory' );
    is_deeply( [ MODULE->_watches ], ['db'], 'rm() -> (watch file)--' );
}

sub make {
    _capture();
    eval{ MODULE->make('db/schema') };
    my $make = _return();
    ok( !$@, 'make' );
    ok( $make eq "db/schema/deploy db/schema/verify db/schema/revert\n", 'make() output correct' );
}

sub list {
    mkpath( DIR . '/new' );
    MODULE->add('new');

    _capture();
    MODULE->list;
    my $list = _return();
    ok( $list eq "db\n  db/schema\nnew\n", 'list (blank)' );

    _capture();
    MODULE->list('db/schema');
    my $list2 = _return();
    ok( $list2 eq "db/schema/deploy db/schema/verify db/schema/revert\n", 'list (action)' );

    MODULE->rm('new');

    _capture();
    MODULE->list;
    my $list3 = _return();
    ok( $list3 eq "db\n  db/schema\n", 'list (again)' );
}

sub status {
    _capture();
    eval{ MODULE->status };
    my $status = _return();
    ok( !$@, 'status' );
    ok( $status eq "diff - db\n  + db/schema\n", 'status() output correct' );
}

sub clean {
    eval{ MODULE->clean };
    ok( !$@, 'clean' );
}

sub diff {
    _capture();
    eval{ MODULE->diff };
    my $diff = _return();
    ok( !$@, 'diff' );
    ok( $diff eq undef );
}
