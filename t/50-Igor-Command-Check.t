#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 4;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

use_ok($module);

my @base = (
    config  => $CONFIG,
    nick    => 'checker',
    trigger => 'check',
    context => $CONFIG->{channel},
);

my $profile = $schema->resultset('Profile')->find( lc 'MrsTurnipBum' );
$profile->last_access('2009-03-07 23:21:22 UTC');
$profile->update();

my $expect = [
    [
        'notice',
        'checker',
        q{MrsTurnipBum's profile last accessed 23:21:22, Saturday, 07 March,}
            . q{ 2009 UTC}
    ]
];

my $test = $module->new(
    @base,
    status => 5,
    args   => 'MrsTurnipBum',
);

is_deeply( $test->response(), $expect, 'Check date response ok' );


$test = $module->new(
    @base,
    status => 5,
    args   => 'MrsTurnipBump',
);

$expect = [
    [
        'notice', 'checker',
        q{Sorry, I don't have a profile for MrsTurnipBump.}
    ]
];

is_deeply( $test->response(), $expect, 'Correct response when no profile' );

$test = $module->new(
    @base,
    status => 6,
    args   => q{},
);

is_deeply( $test->response(), [], 'No response when name not supplied' );


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
