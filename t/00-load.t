#!/usr/bin/env perl -T
use Test::More tests => 1;

BEGIN {
    use_ok( 'App::Depst' ) || print "Bail out!\n";
}

diag( "Testing App::Depst $App::Depst::VERSION, Perl $], $^X" );
