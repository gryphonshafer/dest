#!/usr/bin/env perl -T
use Test::More tests => 1;

BEGIN {
    use_ok( 'App::Dest' ) || print "Bail out!\n";
}

diag( "Testing App::Dest $App::Dest::VERSION, Perl $], $^X" );
