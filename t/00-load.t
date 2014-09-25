#!/usr/bin/env perl
use Test::Most;

BEGIN { use_ok('App::Dest') }
diag( "Testing App::Dest $App::Dest::VERSION, Perl $], $^X" );
done_testing();
