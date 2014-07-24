use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::Dest',
    AUTHOR           => q{Gryphon Shafer <gryphon@cpan.org>},
    VERSION_FROM     => 'lib/App/Dest.pm',
    LICENSE          => 'perl',
    EXE_FILES        => ['bin/dest'],
    MAN1PODS         => { 'bin/dest' => '$(INST_MAN1DIR)/dest.1' },
    MIN_PERL_VERSION => '5.10.1',
    PREREQ_PM        => {
        'File::Basename'        => 0,
        'File::Copy::Recursive' => 0,
        'File::DirCompare'      => 0,
        'File::Find'            => 0,
        'File::Path'            => 0,
        'IPC::Run'              => 0,
        'Test::More'            => 0,
        'Text::Diff'            => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'App-Dest-*' },
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ('LICENSE'=> 'perl') : () ),
);
