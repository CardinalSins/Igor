#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module  = q{Igor::BanMaker};
my @methods = qw{
    mask config duration units reason set_by error _db_row _is_set
    mask_obj validate current_bans apply _set_on _lift_on
};

my $test_schema = t::schema->new( config => $CONFIG )->schema();
my $strp        = DateTime::Format::Strptime->new(
    pattern  => $CONFIG->{timestamp_db},
    on_error => 'croak',
);

use_ok($module);

subtest 'Basic tests' => sub {
    can_ok( $module, @methods );

    my $test;

    lives_ok
        { $test = $module->new( config => $CONFIG, mask => 'abcd@efg' ) }
        'Object creation ok';

    # The actual values don't matter. They could change and still be ok.
    ok( $test->set_by(),   'Default used for set_by' );
    ok( $test->reason(),   'Default used for reason' );
    ok( $test->duration(), 'Default used for duration' );
    ok( $test->units(),    'Default used for units' );
    isa_ok( $test->mask_obj(), 'Igor::Mask' );
    is( $test->error(), undef, 'Error not yet defined' );

    warning_is
        { $test->apply() }
        { carped => 'Ban not validated yet' },
        'Apply is not allowed before validation';

    is( $test->validate,       1, 'Object validates with all defaults' );
    is( $test->error(),        0, 'Error set to zero' );
    is( $test->current_bans(), 0, 'No other bans set now' );

    lives_ok { $test->apply() } 'Written to database';

    my $matches =
        $test_schema->resultset('Ban')->search( { mask => q{abcd@efg} } );
    is( $matches->count(), 1, 'Ban found in database search' );

    lives_ok
        { $test = $module->new( mask => 'no@config.passed' ) }
        'Config object is not required';

    # The actual values don't matter. They could change and still be ok.
    ok( $test->config->{channel} ne $CONFIG->{channel}, 'Live value set' );
};


subtest 'Validation fails' => sub {
    my $test;

    lives_ok
        { $test = $module->new( config => $CONFIG, mask => 'a' ) }
        'Create with faulty mask ok';

    is( $test->validate(), 0, 'But validation returns false' );
    is( $test->error(), q{Mask isn't specific enough.},
        'And the reason why is correct' );

    warning_is
        { $test->apply() }
        { carped => 'Ban has invalid parameters' },
        'Apply is not allowed before validation';

    my @base = ( config => $CONFIG, mask => 'abcd@efg' );

    lives_ok
        { $test = $module->new( @base, duration => 'seven' ) }
        'Create with non-numeric duration ok';

    is( $test->validate(), 0, 'Validation returns false' );
    is(
        $test->error(),
        q{Period must be a number.},
        'Correct error string for non-numeric duration'
    );

    lives_ok
        { $test = $module->new( @base, duration => -3 ) }
        'Object creation with sub-zero duration ok';

    is( $test->validate(), 0, 'Negative duration detected' );
    is(
        $test->error(),
        q{Ban period is not greater than zero.},
        'Correct error string for minus duration'
    );

    lives_ok
        { $test = $module->new( @base, duration => 1_000_000 ) }
        'Create with over-long duration ok';

    is( $test->validate(), 0, 'Excessive duration detected' );
    is(
        $test->error(),
        q{Ban period is too long.},
        'Correct error string for long duration'
    );

    lives_ok
        { $test = $module->new( @base, units => 'decades' ) }
        'Create with unknown units ok';

    is( $test->validate(), 0, 'Invalid units detected' );
    is(
        $test->error(),
        q{Unrecognized ban period units.},
        'Correct reason for invalid units'
    );

    $test = $module->new( @base, duration => 0, units => 'decades' );
    $test->validate();
    is(
        $test->error(),
        q{Ban period is not greater than zero. Unrecognized ban period units.},
        'Simultaneous errors correctly identified'
    );

    ## no critic (RequireInterpolationOfMetachars)
    $test = $module->new(
        config => $CONFIG,
        mask   => '***that_guy***!**@***.**.***.awful.tld'
    );
    $test->validate();

    is( $test->mask(), '*that_guy*!*@*.awful.tld',
        'Trim excessive wildcards' );

    ## use critic
};

subtest 'Apply' => sub {
    my $test = $module->new(
        config   => $CONFIG,
        mask     => 'some*.ban@*.tld',
        set_by   => 'irate_op',
        duration => 10,
        units    => 'days',
    );

    lives_ok { $test->validate() } 'Test object validated';
    is(
        $test->apply(),
        'Ban on some*.ban@*.tld has been set.',
        'Confirm success'
    );
    ok( $test->_is_set(), 'Marked internally as set' );

    my $matches = $test_schema->resultset('Ban')->search(
        { mask => q{some*.ban@*.tld} }
    );

    is( $matches->count(), 1, 'Retrieve ban from database' );

    is( $test->apply(), undef, 'No response on second apply' );

    $matches = $test_schema->resultset('Ban')->search(
        { mask => q{some*.ban@*.tld} }
    );

    is( $matches->count(), 1, 'And still only one database row' );

    my $db_row = $matches->first();
    my ( $dt_on, $dt_off );

    ok( $db_row->set_on(), q{A value was set for the 'set_on' field} );

    lives_ok
        { $dt_on  = $strp->parse_datetime( $db_row->set_on() ) }
        'And is a recognisable timestamp';

    ok( $db_row->lift_on(), q{A value was set for the 'lift_on' field} );

    lives_ok
        { $dt_off = $strp->parse_datetime( $db_row->lift_on() ) }
        'And is also a timestamp';

    my $dur = $dt_off->subtract_datetime($dt_on);
    is( $dur->in_units('days'), '10', 'Ban period implemented properly' );

    # This is really a test of Igor::Role::DBTime
    lives_ok {
        $test = $module->new(
            config   => $CONFIG,
            mask     => 'fort@night',
            set_by   => 'irate_op',
            duration => 1,
            units    => 'fortnight',
        );

        $test->validate();
        $test->apply();

        $db_row = $test_schema->resultset('Ban')->search(
            { mask => q{fort@night} }
        )->first();

        $dt_on  = $strp->parse_datetime( $db_row->set_on() );
        $dt_off = $strp->parse_datetime( $db_row->lift_on() );
        $dur    = $dt_off->subtract_datetime($dt_on);
    }
    'New test object';
    is( $dur->in_units('weeks'), 2, 'A fortnight is two weeks' );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
