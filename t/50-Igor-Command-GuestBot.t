#!/usr/bin/env perl
use 5.014;
use warnings;

use IRC::Utils qw{:ALL};

use Test::More tests => 6;
use Test::Deep;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'tunein',
    nick    => 'listener',
    context => 'notice',
    args    => q{blah blah},
    status  => 0,
);

my $test = $module->new(@base);

my $text = q{Hi, listener, our resident radio bot, smashy_n_nicey,}
    . q{ will brb, but until then !tunein doesn't do anything.};

is_deeply(
    $test->response(),
    [ [ 'notice', 'listener', $text ] ],
    'Correct response to private guest bot command'
);

$test = $module->new( @base, context => $CONFIG->{channel} );
is_deeply(
    $test->response(),
    [ [ 'privmsg', '#my_hang_out', $text ] ],
    'Correct response to public guest bot command'
);

$test = $module->new(
    config  => $CONFIG,
    trigger => 'help',
    nick    => 'whiney',
    args    => 'tunein',
    context => $CONFIG->{channel},
    status  => 2,
);

cmp_deeply(
    $test->single_help('guest_command'),
    ( q{Talk to the other guy about that} ),
    q{Correct help response}
);


$CONFIG->{have_guest_bot} = 0;
$test = $module->new( @base, context => $CONFIG->{channel} );
$text = q{!tunein?!? I don't know what you're on about, listener. Try }
      . BOLD . q{!help} . BOLD;
is_deeply(
    $test->response(),
    [ [ 'notice', 'listener', $text ] ],
    q{If the guest bot is switched off its commands are unrecognised},
);

is $test->single_help('guest_command'), undef,
    q{No help if we don't have a guest bot};


1;
