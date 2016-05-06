#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 18;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);

my @base = (
    config  => $CONFIG,
    status  => 7,
    nick    => 'temperature',
    context => $CONFIG->{channel},
);


my $test = $module->new( @base, trigger => 'x2x', args => q{12}, );

my $expect = [
    [
        'notice', 'temperature',
        q{Sorry, I don't know how to do that conversion.}
    ],
];

is_deeply( $test->response(), $expect, 'Handle unknown conversions' );


$test = $module->new( @base, trigger => 'c2f', args => q{twelve}, );

$expect = [
    [
        'notice', 'temperature',
        q{My tiny robotic brain doesn't recognise 'twelve' as a number.}
    ],
];

is_deeply( $test->response(), $expect, 'Handle suspect arguments' );


$test = $module->new( @base, trigger => 'c2f', args => 10_000_000, );

$expect = [
    [
        'notice', 'temperature',
        q{10000000 is f'ing HOT in any scale!!! Pack sunblock.}
    ],
];

is_deeply( $test->response(), $expect, 'Handle big numbers' );


$test = $module->new( @base, trigger => 'c2f', args => -500, );
is(
    $test->response->[0][2],
    '-500°C = -459.67°F',
    q{Can't go below absolute zero}
);


$test = $module->new( @base, trigger => 'c2f', args => 40, );
is( $test->response->[0][2], '40°C = 104°F', q{c2f ok} );


$test = $module->new( @base, trigger => 'f2c', args => 40, );
is( $test->response->[0][2], '40°F = 4°C', q{f2c ok} );


$test = $module->new( @base, trigger => 'c2k', args => 40, );
is( $test->response->[0][2], '40°C = 313K', q{c2k ok} );


$test = $module->new( @base, trigger => 'k2c', args => 40, );
is( $test->response->[0][2], '40K = -233°C', q{k2c ok} );


$test = $module->new( @base, trigger => 'c2r', args => 40, );
is( $test->response->[0][2], '40°C = 564°R', q{c2r ok} );


$test = $module->new( @base, trigger => 'r2c', args => 40, );
is( $test->response->[0][2], '40°R = -251°C', q{r2c ok} );


$test = $module->new( @base, trigger => 'f2k', args => 40, );
is( $test->response->[0][2], '40°F = 278K', q{f2k ok} );


$test = $module->new( @base, trigger => 'k2f', args => 40, );
is( $test->response->[0][2], '40K = -388°F', q{k2f ok} );


$test = $module->new( @base, trigger => 'f2r', args => 40, );
is( $test->response->[0][2], '40°F = 500°R', q{f2r ok} );


$test = $module->new( @base, trigger => 'r2f', args => 40, );
is( $test->response->[0][2], '40°R = -420°F', q{r2f ok} );


$test = $module->new( @base, trigger => 'k2r', args => 40, );
is( $test->response->[0][2], '40K = 72°R', q{k2r ok} );


$test = $module->new( @base, trigger => 'r2k', args => 40, );
is( $test->response->[0][2], '40°R = 22K', q{r2k ok} );

$test = $module->new( @base, trigger => 'r2k', args => 40, status => 1 );
is(
    $test->response->[0][2],
    q{Won't convert for you.},
    q{Policy is being checked} );
1;
