use strict;
use warnings;

use Test::Most;
use File::Path 'mkpath';
use lib 't';
use TestLib qw( t_module t_startup t_teardown t_capture t_action_files );

exit main();

sub main {
    require_ok( t_module() );

    t_startup();
    t_action_files(
        [ 'adt/state_sixth',      'adt_alt/state_fifth',  undef                  ],
        [ 'adt/state_first',      undef,                  'adt_alt/state_second' ],
        [ 'adt/state_fourth',     'adt/_altstate_third',  'adt_alt/state_fifth'  ],
        [ 'adt_alt/state_third',  'adt_alt/state_second', 'adt/state_fourth'     ],
        [ 'adt_alt/state_fifth',  'adt/state_fourth',     'adt/state_sixth'      ],
        [ 'adt_alt/state_second', 'adt/state_first',      'adt_alt/state_third'  ],
    );
    t_module->init;
    t_module->add('adt');
    t_module->add('adt_alt');

    single_prereqs();
#    multi_prereqs();

    t_teardown();
    done_testing();
    return 0;
}

sub single_prereqs {
    is(
        ( t_capture( sub { t_module->status } ) )[0],
        join( "\n",
            'diff - adt',
            '  + adt/state_first',
            '  + adt/state_fourth',
            '  + adt/state_sixth',
            'diff - adt_alt',
            '  + adt_alt/state_fifth',
            '  + adt_alt/state_second',
            '  + adt_alt/state_third',
        ) . "\n",
        'status() of adt/* and adt_alt/* actions',
    );

    {
        my ( $out, $err, $exp ) = t_capture( sub { t_module->deploy('adt_alt/state_second') } );

        is(
            $out,
            join( "\n",
                'begin - deploy: adt/state_first',
                'ok - deploy: adt/state_first',
                'ok - verify: adt/state_first',
                'begin - deploy: adt_alt/state_second',
                'ok - deploy: adt_alt/state_second',
                'ok - verify: adt_alt/state_second',
            ) . "\n",
            'single deploy with single prereq',
        );

        ok( ! $err, 'no warnings in last command' );
        ok( ! $exp, 'no exceptions in last command' );
    }

    is(
        ( t_capture( sub { t_module->status } ) )[0],
        join( "\n",
            'diff - adt',
            '  + adt/state_fourth',
            '  + adt/state_sixth',
            'diff - adt_alt',
            '  + adt_alt/state_fifth',
            '  + adt_alt/state_third',
        ) . "\n",
        'status() of adt/* and adt_alt/* actions after limited deployment',
    );

    {
        my ( $out, $err, $exp ) = t_capture( sub { t_module->revert('adt/state_first') } );

        is(
            $out,
            join( "\n",
                'begin - revert: adt_alt/state_second',
                'ok - revert: adt_alt/state_second',
                'begin - revert: adt/state_first',
                'ok - revert: adt/state_first',
            ) . "\n",
            'single revert with single prereq',
        );

        ok( ! $err, 'no warnings in last command' );
        ok( ! $exp, 'no exceptions in last command' );
    }

    is(
        ( t_capture( sub { t_module->status } ) )[0],
        join( "\n",
            'diff - adt',
            '  + adt/state_first',
            '  + adt/state_fourth',
            '  + adt/state_sixth',
            'diff - adt_alt',
            '  + adt_alt/state_fifth',
            '  + adt_alt/state_second',
            '  + adt_alt/state_third',
        ) . "\n",
        'status() of adt/* and adt_alt/* actions after limited deployment',
    );
}

sub multi_prereqs {
    # {
    #     my ( $out, $err, $exp ) = t_capture( sub { t_module->deploy('adt_alt/state_fifth') } );

    #     is(
    #         $out,
    #         join( "\n",
    #             'begin - deploy: adt/state_first',
    #             'ok - deploy: adt/state_first',
    #             'ok - verify: adt/state_first',
    #             'begin - deploy: adt_alt/state_second',
    #             'ok - deploy: adt_alt/state_second',
    #             'ok - verify: adt_alt/state_second',
    #         ) . "\n",
    #         'single deploy with multiple prereqs',
    #     );

    #     ok( ! $err, 'no warnings in last command' );
    #     ok( ! $exp, 'no exceptions in last command' );
    # }
}
