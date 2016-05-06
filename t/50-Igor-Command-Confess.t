#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use DateTime::Format::Strptime;
use Regexp::Common qw{time};
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

# Use this file to test user responses under various circumstances when making
# a new profile. Use 50-Igor-Command-Refine.t to test the same when editing
# previously completed profiles and 40-Profile-Commands-Common.t to test the
# mechanics and error-checking that underlie either.

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();
my $now_dt = DateTime->now( time_zone => 'UTC' );

my $out_strp = DateTime::Format::Strptime->new(
    pattern   => $CONFIG->{timestamp_output},
    time_zone => 'UTC',
    on_error  => 'croak',
);
my $db_strp = DateTime::Format::Strptime->new(
    pattern   => $CONFIG->{timestamp_db},
    time_zone => 'UTC',
    on_error  => 'croak',
);

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'confess',
    status  => 1,
    args    => q{irrelevant},
    nick    => 'new_boy',
    context => $CONFIG->{channel},
);

my $init;

lives_ok { $init = $module->new(@base) } 'Create base test object';
subtest 'Confess for newbies and oldbies' => sub {
    @base = (
        config  => $CONFIG,
        trigger => 'confess',
        status  => 1,
        args    => q{irrelevant},
    );

    my $test = $module->new(
        @base,
        nick    => 'I_have_no_profile',
        context => $CONFIG->{channel},
    );

    my $expect = [
        [ 'privmsg', 'I_have_no_profile',
            q{Hurray! You want to make a new profile!} ],
        [ 'privmsg', 'I_have_no_profile',
            q{There are 10 short questions to answer, so let's go...} ],
        [ 'privmsg', 'I_have_no_profile',
            q{The commands must be entered here in tIgor's pm.} ],
        [ 'privmsg', 'I_have_no_profile',
            q{Enter your age with } . BOLD . q{!age} . BOLD
            . q{ - e.g. !age 32 or !age decrepit} ],
    ];

    is_deeply( $test->response(), $expect, 'Confess response ok' );

    # Test full profile
    $test = $module->new(
        @base,
        nick    => 'MrTurnipHead',
        context => $CONFIG->{channel},
    );

    $expect = q{You already have a full profile. Use }
            . BOLD . q{!refine} . BOLD
            . q{ for the list of commands to modify your profile.};

    is_deeply(
        $test->response(),
        [ [ 'privmsg', 'MrTurnipHead', $expect ] ],
        'Correct response for full profile'
    );

    my $profile  = $schema->resultset('Profile')->find( lc 'MrTurnipHead' );
    my $stamp_dt = $db_strp->parse_datetime( $profile->last_access() );
    ok( $stamp_dt >= $now_dt, 'Timestamp applied' );

    # Test partial profile
    $test = $module->new(
        @base,
        nick    => 'Partial_Profile',
        context => $CONFIG->{channel},
    );

    $expect = q{Enter your gender and/or sexual orientation with }
            . BOLD . q{!sex} . BOLD
            . q{ - e.g. !sex Straight, male or !sex dysfunctional};

    is_deeply(
        $test->response(),
        [ [ 'privmsg', 'Partial_Profile', $expect ] ],
        'Correct response for partial profile'
    );
};


subtest 'Write profile' => sub {
    @base = (
        config  => $CONFIG,
        context => 'privmsg',
        status  => $CONFIG->{status}->{bop},
        nick    => 'nopr0fi7E',
    );

    my $test = $module->new(
        @base,
        trigger => 'age',
        args    => 'blah age blah',
    );

    is( $schema->resultset('Profile')->find( lc 'nopr0fi7E' ),
        undef, 'No profile present before tests' );

    my $expect = [
        [ 'privmsg', 'nopr0fi7E', 'age: entry saved.' ],
        [ 'privmsg', 'nopr0fi7E',
            q{Enter your gender and/or sexual orientation with }
            . BOLD . q{!sex} . BOLD
            . q{ - e.g. !sex Straight, male or !sex dysfunctional} ]
    ];

    is_deeply( $test->response(), $expect,
        'Correct response to first profile entry' );

    my $rs = $schema->resultset('Profile')->find( lc 'nopr0fi7E' );

    my $dt;

    lives_ok
        { $dt = $db_strp->parse_datetime( $rs->last_access() ) }
        'Access time set...';

    ok( $now_dt <= $dt, ' ... and is (probably) correct' );

    is( $rs->age(), 'blah age blah', 'Age set' );

    $test = $module->new(
        @base,
        trigger => 'desc',
        args    => 'blah desc blah',
    );

    is( $rs->desc(), undef, 'No desc field present before tests' );

    $expect = [
        [ 'privmsg', 'nopr0fi7E', 'desc: entry saved.' ],
        [ 'privmsg', 'nopr0fi7E',
            q{Enter your gender and/or sexual orientation with }
            . BOLD . q{!sex} . BOLD
            . q{ - e.g. !sex Straight, male or !sex dysfunctional} ]
    ];

    is_deeply( $test->response(), $expect,
        'Correct response to second profile entry' );

    $rs = $schema->resultset('Profile')->find( lc 'nopr0fi7E' );
    is( $rs->desc(), 'blah desc blah', 'Description set' );

    $test = $module->new(
        config  => $CONFIG,
        context => 'privmsg',
        status  => $CONFIG->{status}->{bop},
        nick    => 'almost_dun',
        trigger => 'loc',
        args    => 'blah loc blah',
    );

    $rs = $schema->resultset('Profile')->find( lc 'almost_dun' );
    is( $rs->loc(),     undef, 'Last field not present before tests' );
    is( $rs->fanfare(), undef, 'Fanfare not set before tests' );
    $rs->quote('stop additional prompts');
    $rs->intro('As above');
    $rs->update;

    $expect = [
        [ 'privmsg', 'almost_dun', 'loc: entry saved.' ],
        [ 'privmsg', '#my_hang_out',
            q{Kill the fatted calf! } . BOLD . PURPLE . 'almost_dun' . NORMAL
            . q{ has made a new profile for us!} ],
        [ 'voice_user', 'almost_dun', q{+} ],
    ];

    is_deeply( $test->response(), $expect,
        'Correct response to last profile entry' );

    $rs = $schema->resultset('Profile')->find( lc 'almost_dun' );
    is( $rs->loc(), 'blah loc blah', 'Last field not present before tests' );
    ok( $rs->fanfare(), 'Fanfare flag set' );

    $expect = [ [ 'privmsg', 'almost_dun', 'loc: entry saved.' ] ];

    is_deeply( $test->response(), $expect, 'No fanfare the second time' );

    $test = $module->new(
        config  => $CONFIG,
        context => $CONFIG->{channel},
        status  => $CONFIG->{status}->{bop},
        nick    => 'almost_dun',
        trigger => 'loc',
        args    => 'blah loc blah',
    );
};


# We test in 20-Igor-Config.t that all Igor's actual triggers are represented.
subtest 'Full set of editing commands present' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        nick    => '__xXx__',
        trigger => 'age',
        args    => 'twenty seven and a half',
    );

    is( $schema->resultset('Profile')->find( lc '__xXx__' ),
        undef, 'Starting from a blank slate' );

    # These tests work because they write whatever is left in $self->args() to
    # the appropriate field - i.e. they don't need their own argument.
    $test->bot_age();

    my $test_row = $schema->resultset('Profile')->find( lc '__xXx__' );
    is( $test_row->age(), 'twenty seven and a half', 'Age set' );

    $test->bot_sex();
    $test_row->discard_changes();
    is( $test_row->sex(), 'twenty seven and a half', 'Sex set' );

    $test->bot_loc();
    $test_row->discard_changes();
    is( $test_row->loc(), 'twenty seven and a half', 'Location set' );

    $test->bot_bdsm();
    $test_row->discard_changes();
    is( $test_row->bdsm(), 'twenty seven and a half', 'Position set' );

    $test->bot_fantasy();
    $test_row->discard_changes();
    is( $test_row->fantasy(), 'twenty seven and a half', 'Fantasy set' );

    $test->bot_limits();
    $test_row->discard_changes();
    is( $test_row->limits(), 'twenty seven and a half', 'Limits set' );

    $test->bot_kinks();
    $test_row->discard_changes();
    is( $test_row->kinks(), 'twenty seven and a half', 'Kinks set' );

    $test->bot_desc();
    $test_row->discard_changes();
    is( $test_row->desc(), 'twenty seven and a half', 'Description set' );

    $test->bot_quote();
    $test_row->discard_changes();
    is( $test_row->desc(), 'twenty seven and a half', 'Description set' );

    $test->bot_intro();
    $test_row->discard_changes();
    is( $test_row->desc(), 'twenty seven and a half', 'Description set' );
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
