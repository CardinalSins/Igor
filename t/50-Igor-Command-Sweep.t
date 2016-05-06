#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 2;
use Test::Deep;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};
use_ok($module);


my @base = (
    config  => $CONFIG,
    trigger => 'sweep',
    args    => q{},
    status  => 6,
    context => 'notice',
);

my $test = $module->new( @base, nick => 'sweeper', );

my $expect = [
    ['expire_bans'],
    [ 'notice', 'sweeper', 'Sweep for expired bans complete' ]
];

is_deeply( $test->response, $expect, 'Sweep bans ok' );

1;
