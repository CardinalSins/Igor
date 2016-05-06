#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;
use Test::Deep;
use Test::Exception;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

my @base = (
    config  => $CONFIG,
    trigger => 'banish',
    nick    => 'banfan',
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);


subtest 'Basic tests' => sub {
    use_ok($module);

    is( scalar $schema->resultset('Ban')->all() => 5, 'Five bans to start' );

    my $test =
        $module->new( @base, args => q{target_boy 4 weeks General nuisance}, );

    my $dt      = DateTime->now( time_zone => 'UTC' );
    my $set_on  = $dt->strftime( $CONFIG->{timestamp_db} );
    my $expires = $dt->add( weeks => 4 )->strftime( $CONFIG->{timestamp_db} );
    my $expect = [
        [ 'notice', 'banfan', q{Ban on target_boy!*@* has been set.} ],
        [ 'check_bans' ]
    ];

    is_deeply( $test->response(), $expect,
        'Banish response ok (and normalized)' );

    is( scalar $schema->resultset('Ban')->all() => 6, 'Six bans now' );

    my $row = $schema->resultset('Ban')->
        search( { mask => q{target_boy!*@*} } )->first();

    is( $row->mask(),    'target_boy!*@*',    'Mask saved in database' );
    is( $row->set_on(),  $set_on,             'Date set saved in database' );
    is( $row->lift_on(), $expires,            'Lift date saved in database' );
    is( $row->reason(),  'General nuisance.', 'Reason saved in database' );
    is( $row->units(),   'weeks',             'Units saved in database' );
    is( $row->set_by(),  'banfan',            'Set by saved in database' );

    is( $row->duration() => 4, 'Duration saved in database' );
    is( $row->expired()  => 0, 'Expired flag saved in database' );

};


subtest 'Defaults' => sub {
    my $test = $module->new( @base, args => q{no_units 7}, );
    lives_ok { $test->bot_banish() } q{It's ok to not supply units};

    my $row = $schema->resultset('Ban')->
        search( { mask => q{no_units!*@*} } )->first();
    is( $row->units(), 'days', 'A default of days will be used' );


    $test = $module->new( @base, args => q{no_time}, );
    lives_ok { $test->bot_banish() } q{It's ok to not supply the time};

    $row = $schema->resultset('Ban')->
        search( { mask => q{no_time!*@*} } )->first();
    is( $row->duration() => 1, 'A default of 1 will be used' );


    $test = $module->new( @base, args => q{dodgy_sentence 2 microseconds}, );
    my $expect = [ [ 'notice', 'banfan', q{Unrecognized ban period units.} ] ];
    is_deeply( $test->response(), $expect, q{Restrict the time units} );


    $test = $module->new( @base, args => q{minus_time -10 days}, );
    $expect =
        [ [ 'notice', 'banfan', q{Ban period is not greater than zero.} ] ];
    is_deeply( $test->response(), $expect, q{Sentence must be greater than 0} );


    $test = $module->new( @base, args => q{stupid_time 1000 days}, );
    $expect = [ [ 'notice', 'banfan', q{Ban period is too long.} ] ];
    is_deeply( $test->response(), $expect, q{Sentence shouldn't be silly} );


    my $mask = q{arbi@*whim.ie};
    $test = $module->new( @base, args => qq{$mask 15 days}, );

    lives_ok { $test->response() } q{Reason not required};
    $row = $schema->resultset('Ban')->search( { mask => $mask } )->first();
    is( $row->reason(), 'No reason given.', 'Default reason used' );
};


subtest 'Setting bans' => sub {
    my $mask = q{arbi@*whim.ie};

    my $rs = $schema->resultset('Ban')->search( { mask => $mask } );
    is( $rs->count(), 1, 'Ban against mask already set' );

    my $test = $module->new( @base, args => qq{$mask 4 months I'm a copycat} );

    my $response = $test->response();
    my $expect   = [
        [ 'notice', 'banfan', "There is already 1 active ban set on $mask" ],
    ];
    is_deeply( $response, $expect, 'Ban already set once' );

    $test = $module->new( @base, args => qq{$mask 4 years Just coz} );

    # Add another ban to test finding more than 1 prior ban
    $schema->resultset('Ban')->create(
        {
            mask     => $mask,
            set_by   => 'tester',
            set_on   => '1845-04-13 12:13:14',
            lift_on  => '2845-04-13 12:13:14',
            duration => 1,
            units    => 'millenium',
            reason   => 'bored'
        }
    );

    $response = $test->response();
    $expect   = [
        [ 'notice', 'banfan', "There are already 2 active bans set on $mask" ],
    ];
    is_deeply( $response, $expect, 'Ban already set twice' );

    $mask = q{comma@*.is.ok};
    lives_ok {
        $test = $module->new( @base, args => qq{$mask 3 days, Test!} );
        $test->bot_banish();
    }
    'Punctuation is ok';

    $rs = $schema->resultset('Ban')->find( { mask => $mask } );
    is( $rs->units(), 'days', 'And not carried forward' );

    $mask = q{bad.grammar@*.will.be.fixed};
    lives_ok {
        $test = $module->new( @base, args => qq{$mask 1 weeks Tssk. Tssk.} );
        $test->bot_banish();
    }
    'Wrong plural ok';

    $mask = q{plurals.too@*.will.be.fixed};
    lives_ok {
        $test = $module->new( @base, args => qq{$mask 5 hour Terrible.} );
        $test->bot_banish();
    }
    'Missing plural ok';

    $rs = $schema->resultset('Ban')->find( { mask => $mask } );
    is( $rs->units(), 'hours', 'But quietly corrected' );

    $mask = q{case@*.insensi.ti.ve};
    lives_ok {
        $test = $module->new( @base, args => qq{$mask 3 MOnTHS, Caps lock} );
        $test->bot_banish();
    }
    'Case insensitive';

    $rs = $schema->resultset('Ban')->find( { mask => $mask } );
    is( $rs->units(), 'months', 'Lower case in database' );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
