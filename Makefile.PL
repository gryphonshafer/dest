use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'App::Depst',
    AUTHOR           => q{Gryphon Shafer <gryphon@cpan.org>},
    VERSION_FROM     => 'lib/App/Depst.pm',
    LICENSE          => 'perl',
    EXE_FILES        => ['bin/depst'],
    MAN1PODS         => { 'bin/depst' => '$(INST_MAN1DIR)/depst.1' },
    MIN_PERL_VERSION => '5.10.1',
    PREREQ_PM        => {
        'File::Basename'        => 0,
        'File::Copy::Recursive' => 0,
        'File::DirCompare'      => 0,
        'File::Find'            => 0,
        'File::Path'            => 0,
        'IPC::Run'              => 0,
        'Test::More'            => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'App-Depst-*' },
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ('LICENSE'=> 'perl') : () ),
);
