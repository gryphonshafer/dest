# dest - Deployment State Manager

dest is a simple "deployment state" change management tool. Inspired by
what Sqitch does for databases, it provides a simple mechanism for writing
deploy, verify, and revert parts of a change action. The typical use of
dest is in a development context because it allows for simplified state
changes when switching between branches (as an example).

[![Build Status](https://travis-ci.org/gryphonshafer/dest.svg)](https://travis-ci.org/gryphonshafer/dest)
[![Coverage Status](https://coveralls.io/repos/gryphonshafer/dest/badge.png)](https://coveralls.io/r/gryphonshafer/dest)

Let's say you're working with a group of other software engineers on a
particular software project using your favorite revision control system.
Let's also say that you have a database that undergoes schema changes as
features are developed, and you have various system activities like the
installation of libraries or other applications. Then let's also say the team
braches, works on stuff, shares those branches, reverts, merges, etc. And also
from time to time you want to go back in time a bit so you can reproduce a bug.
Maintaining the database state and the state of the system across all that
activity can be problematic. dest tries to solve this in a very simple way,
letting you be able to deploy, revert, and verify to any point in time in
the development history.

Using dest for production deployment, provisioning, or configuration management
is not advised. Use something like Angular et al instead. Angular (or whatever
CM tool you prefer) can use dest to perform some actions.

## Installation

To install this module, run the following commands:

    perl Makefile.PL
    make
    make test
    make install

## Support and Documentation

After installing, you can find documentation for this module with the
perldoc command.

    dest help
    dest man
    man dest
    perldoc App::Dest

You can also look for information at:

- [GitHub](https://github.com/gryphonshafer/App-Dest "GitHub")
- [AnnoCPAN](http://annocpan.org/dist/App-Dest "AnnoCPAN")
- [CPAN Ratings](http://cpanratings.perl.org/m/App-Dest "CPAN Ratings")
- [Search CPAN](http://search.cpan.org/dist/App-Dest "Search CPAN")

## Author and License

Gryphon Shafer, [gryphon@cpan.org](mailto:gryphon@cpan.org "Email Gryphon Shafer")

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
