#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use DateTime;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

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

# Will fail if the methods are called on each side of a second changing?
is(
    $test->now_time(),
    DateTime->now->strftime( $CONFIG->{timestamp_db} ),
    'Get the current time in storage format'
);

my $example = q{2002-04-18 14:00:30};


subtest 'Normalise' => sub {
    my $dt = $test->normalise_time($example);
    isa_ok( $dt, 'DateTime', 'Converted db time' );
    my $expect =
        $dt->ymd() . q{ } . $dt->hms();
    is( $example, $expect, 'Accurately' );

    throws_ok
        { $test->normalise_time() }
        qr/Timestamp string required as argument/ms,
        'Insist on an argument';

    dies_ok
        { $test->normalise_time('blah') }
        q{But don't accept any old rubbish};
};


subtest 'Convert' => sub {
    my $convert = $test->convert_time($example);

    is(
        $convert, '14:00:30, Thursday, 18 April, 2002 UTC', 'Converted ok'
    );

    throws_ok
        { $test->convert_time() }
        qr/Timestamp string required as argument/ms,
        'Insist on an argument';

    dies_ok
        { $test->covnert_time('fish') }
        q{But don't accept any old rubbish};
};


subtest 'Add' => sub {

    ## no critic (ProhibitMagicNumbers)
    dies_ok { $test->add_time( 12, 'banana' ) } q{Die with bad units};
    dies_ok
        { $test->add_time( 'orange', 'month' ) }
        q{First argument must be a number};

    my $add  = $test->add_time( 5, 'minutes' );
    my $five = DateTime->now->add( minutes => 5 );

    ## use critic
    my $expect =
        $five->ymd() . q{ } . $five->hms();
    is( $add, $expect, 'Add five minutes' );
};

1;
