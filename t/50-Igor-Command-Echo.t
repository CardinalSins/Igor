#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 6;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'e',
    nick    => 'someone',
);


my $test = $module->new(
    @base,
    args    => q{ },
    context => 'notice',
    status  => $CONFIG->{status}->{bop},
);
is( $test->response(), undef, 'No response to blank args' );


$test = $module->new(
    @base,
    args    => q{/me  },
    context => 'notice',
    status  => $CONFIG->{status}->{bop},
);
is( $test->response(), undef, 'No response to blank action' );


$test = $module->new(
    @base,
    args    => q{how's it going?},
    context => 'notice',
    status  => $CONFIG->{status}->{bop},
);

my $expect = [ [ 'privmsg', '#my_hang_out', q{how's it going?} ] ];
is_deeply( $test->response(), $expect, 'Echo response ok' );


$test = $module->new(
    @base,
    args    => q{/me runs amok!},
    context => 'notice',
    status  => $CONFIG->{status}->{bop},
);

$expect = [ [ 'ctcp', '#my_hang_out', q{ACTION runs amok!} ] ];
is_deeply( $test->response(), $expect, 'Echo action response ok' );

$test = $module->new(
    @base,
    args    => q{loose lips sink ships},
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);

$expect = [ [ 'ctcp', '#my_hang_out', q{ACTION looks at someone stonily...} ] ];
is_deeply( $test->response(), $expect, 'Glare at blabbermouths' );

1;
