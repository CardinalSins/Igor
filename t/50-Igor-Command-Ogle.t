#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 5;
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'ogle',
    nick    => 'somebody',
);

my $test = $module->new(
    @base,
    args    => 'mrTurnIphead',
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);

my @text = (
    q{Profile for }
    . BOLD . PURPLE . q{mrTurnIphead} . NORMAL . q{  }
    . BOLD . PURPLE . q{Age:}         . NORMAL . q{ 23  }
    . BOLD . PURPLE . q{Sex:}         . NORMAL . q{ banal  }
    . BOLD . PURPLE . q{Location:}    . NORMAL . q{ None of your business  }
    . BOLD . PURPLE . q{BDSM:}        . NORMAL . q{ Yes please},

      BOLD . PURPLE . q{Limits:}      . NORMAL . q{ denial},
      BOLD . PURPLE . q{Fantasy:}     . NORMAL . q{ Big long-ass string of text},
      BOLD . PURPLE . q{Kinks:}       . NORMAL . q{ failing tests},
      BOLD . PURPLE . q{Description:} . NORMAL . q{ Cool, witty and engaging},
);

my @expect = map { [ 'notice', 'somebody', $_ ] } @text;

is_deeply( $test->response(), \@expect, 'Ogle ok' );
$test = $module->new(
    @base,
    args    => q{  },
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);


my $text = q{Ogle who?};
is_deeply(
    $test->response(),
    [ [ 'notice', 'somebody', $text ] ],
    'Handle whitespace args'
);

$test = $module->new(
    @base,
    args    => undef,
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);
is_deeply(
    $test->response(),
    [ [ 'notice', 'somebody', $text ] ],
    'Handle undef args'
);

$test = $module->new(
    @base,
    args    => '#~~nMmN',
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);
$text = q{Sorry, I don't have a profile for #~~nMmN.};
is_deeply(
    $test->response(),
    [ [ 'notice', 'somebody', $text ] ],
    'No profile found'
);

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
