#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 8;
use Test::Deep;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'db_backup',
    nick    => 'archivist',
    context => 'notice',
    args    => q{},
    status  => $CONFIG->{status}->{bop},
);


subtest 'Devel and deputy' => sub {
    local $ENV{IGOR_DEVEL}  = 1;
    local $ENV{IGOR_DEPUTY} = 0;
    my $test = $module->new(@base);

    # We *do* want to send back-ups during testing - just not the normal ones.
    #is_deeply(
    #    $test->response(),
    #    [ [ 'notice', 'archivist', 'Backups disabled during testing.' ] ],
    #    'No (real) backups during devel'
    #);

    local $ENV{IGOR_DEVEL}  = 0;
    local $ENV{IGOR_DEPUTY} = 1;
    $test = $module->new(@base);

    my $expect = 'Backups disabled while tIgor is standing in for testIgor.';
    is_deeply(
        $test->response(),
        [ [ 'notice', 'archivist', $expect ] ],
        'Or for stand-ins'
    );
};


my $have_sendmail = readpipe(q{which sendmail}) ? 1 : 0;

SKIP: {
    skip 'sendmail is installed' => 3, if $have_sendmail == 1;

    my $test = $module->new(@base);

    ok( !$test->have_sendmail(), 'Test for sendmail fails' );

    is_deeply(
        $test->response(),
        [ [ 'notice', 'archivist', q{No access to sendmail on this host.} ] ],
        'No sendmail response ok'
    );

    ## no critic (ProhibitNoWarnings)
    no warnings 'redefine';
    no strict 'refs';

    my $class = ref $test;
    local *{"${class}::have_sendmail"} = sub { return 1; };

    ## use critic
    use strict;
    use warnings;
    my $expect = [ [ q{backup_db}, q{archivist} ] ];

    is_deeply( $test->response(), $expect,
        q{Correct response for db_backup trigger} );
}

SKIP: {
    skip 'sendmail is not installed' => 3, if $have_sendmail == 0;

    my $test = $module->new(@base);

    ok( $test->have_sendmail(), 'Test for sendmail passes' );

    my $expect = [ [ q{backup_db}, q{archivist}, q{} ] ];
    is_deeply( $test->response(), $expect,
        q{Correct response for db_backup trigger} );


    ## no critic (ProhibitNoWarnings)
    no warnings 'redefine';
    no strict 'refs';

    $test = $module->new(@base);
    is_deeply(
        $test->response(),
        [ [ 'notice', 'archivist', q{No access to sendmail on this host.} ] ],
        'No sendmail response ok'
    );
}

1;
