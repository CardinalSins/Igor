#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 10;
use Test::Deep;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'fortune',
    nick    => 'gullible',
    context => 'should_validate_this',
    args    => q{},
    status  => $CONFIG->{status}->{bop},
);

my $test = $module->new(@base);

my $have_fortune = readpipe(q{which fortune}) ? 1 : 0;

## no critic (ProhibitMagicNumbers)
SKIP: {
    skip 'fortune not installed', 6, if $have_fortune == 0;

    ok( $test->have_fortune(), 'Test for fortune passes' );

    my $response = $test->bot_fortune();

    my ( $context, $target, $fortune ) = ( 0, 0, q{} );
    my $count = scalar @{$response};
    while ( my $line = shift @{$response} ) {
        ( $line->[0] eq 'privmsg' )      && $context++;
        ( $line->[1] eq '#my_hang_out' ) && $target++;
        $fortune .= $line->[1] . qq{\n};
    }

    is( $context, $count, 'All lines are privmsg' );
    is( $target,  $count, 'All lines to channel' );

    ok( length $fortune < $CONFIG->{longest_fortune},
        q{Fortune isn't too long} );
    ok( $fortune !~ m/^ \s* $/msx, 'Fortune contains no blank lines' );

    ## no critic (ProhibitNoWarnings)
    no warnings 'redefine';
    no strict 'refs';

    my $class = ref $test;
    local *{"${class}::have_fortune"} = sub { return 0; };

    ## use critic
    use strict;
    use warnings;
    my $expect = [
        [
            q{privmsg}, q{gullible},
            q{Sorry, my host doesn't seem to have the fortune command.}
        ]
    ];

    is_deeply( $test->response(), $expect,
        q{Correct response when there's no fortune command} );
}

SKIP: {
    skip 'fortune is installed', 3, if $have_fortune == 1;

    ok( !$test->have_fortune(), 'Test for fortune fails' );

    my $expect = [
        [
            q{privmsg}, q{gullible},
            q{Sorry, my host doesn't seem to have the fortune command.}
        ]
    ];

    is_deeply( $test->response(), $expect,
        q{Correct response when there's no fortune command} );


    ## no critic (ProhibitNoWarnings)
    no warnings 'redefine';
    no strict 'refs';

    my $class = ref $test;
    local *{"${class}::have_fortune"} = sub { return 1; };
    local *{"${class}::get_fortune"} =
        sub { return ( qq{a\n}, qq{ \n}, qq{b\n}, qq{c\n} ); };

    ## use critic
    use strict;
    use warnings;
    $expect = [
        [ 'privmsg', '#my_hang_out', 'a' ],
        [ 'privmsg', '#my_hang_out', 'b' ],
        [ 'privmsg', '#my_hang_out', 'c' ],
    ];

    is_deeply( $test->response(), $expect, 'Correct fortune response' );
}

1;
