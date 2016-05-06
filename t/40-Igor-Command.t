#!/usr/bin/env perl
use 5.014;
use warnings;

local $ENV{IGOR_TEST} = 1;

use Test::More tests => 13;
use Test::Deep;
use Test::Exception;
use DateTime::Format::Strptime;
use Regexp::Common qw{time};
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $now_dt = DateTime->now();
my $schema = t::schema->new( config => $CONFIG )->schema();

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


subtest 'Sanity checks' => sub {
    use_ok($module);

    # All the 'bot_*' methods are tested separately.
    can_ok(
        $module,
        qw{
            args config context db_profile status fallback field_length nick
            first_args get_fortune have_fortune have_sendmail trigger_methods
            look_for next_prompt no_profile_response response command_unknown
            search_profile single_help sort_by_score_then_date start_profile
            trigger write_field _by_score_then_date _convert access_policy
        }
    );

};


subtest 'Basic functions' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'the_trigger',
        args    => 'one two a b three',
        nick    => 'someone',
        status  => 1,
        context => 'should_validate',
    );

    is( $test->trigger(),           'the_trigger',       'Trigger ok' );
    is( $test->args(),              'one two a b three', 'Args ok' );
    is( $test->nick(),              'someone',           'Nick ok' );
    is( $test->context(),           'should_validate',   'Context ok' );
    is( $test->config()->{channel}, '#my_hang_out',      'Config ok' );
    is( $test->status(),            1,                   'User status ok' );

    ## no critic (ProhibitMagicNumbers)
    is( scalar keys %{ $test->trigger_methods() }, 40, 'All commands present' );

    ## use critic
};


subtest 'Build config' => sub {
    my $test;

    lives_ok {
        $test = $module->new(
            trigger => 'the_trigger',
            args    => 'one two a b three',
            nick    => 'someone',
            status  => 1,
            context => 'notice',
        );
    }
    'Config not required';

    ok( scalar keys %{ $test->config() }, 'We can build our own' );

    throws_ok
        { $test->access_policy() }
        qr/No[ ]private[ ]policy[ ]defined[ ]for[ ]the_trigger/msx,
        'Undocumented trigger'
};


subtest 'Parse arguments' => sub {
    my @base = (
        config  => $CONFIG,
        trigger => 'e',
        nick    => 'testy',
        context => 'irrelevant',
        status  => 0,
    );

    my $test = $module->new( @base, args => q{blahdy blah blahblah}, );

    is_deeply(
        [ $test->first_args() ],
        [qw/blahdy blah blahblah/],
        'First args ok'
    );

    $test = $module->new( @base, args => qq{ blah\tand   more_blah }, );

    is_deeply(
        [ $test->first_args() ],
        [qw/blah and more_blah/],
        'Trims whitespace ok'
    );

};


subtest 'Known command' => sub {
    my @args = (
        config  => $CONFIG,
        nick    => 'testy',
        context => 'irrelevant',
        status  => 0,
        args    => q{won't be used},
    );

    my $test = $module->new(
        @args,
        trigger => 'b_rrX fs$$ __',
    );

    ok( $test->command_unknown(), 'Identify an unknown command' );

    $test = $module->new(
        @args,
        trigger => 'confess',
    );

    ok( !$test->command_unknown(), 'Recognise a known command' );

    $test = $module->new(
        @args,
        trigger => 'r2k',
    );

    ok( !$test->command_unknown(), 'Recognise a conversion command' );

    $test = $module->new(
        @args,
        trigger => 'desc',
    );

    ok( !$test->command_unknown(), 'Recognise a profile editing command' );
};


subtest 'Limit field length' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'e',
        nick    => 'testy',
        context => 'irrelevant',
        status  => 0,
        args    => q{won't be used},
    );

    throws_ok { $test->field_length() } qr/Profile field argument required/ms,
        'Insist on field argument';

    throws_ok { $test->field_length('gronkular') } qr/Unknown profile field/ms,
        q{Don't parse just anything};

    ## no critic (ProhibitMagicNumbers)
    my $long_text = q{this is too long} x 500;

    ## use critic
    is(
        length $test->field_length( 'age', $long_text ),
        $CONFIG->{longest_teaser_field},
        'Trim teaser fields'
    );

    is(
        length $test->field_length( 'desc', $long_text ),
        $CONFIG->{longest_profile_field},
        'Trim other fields'
    );
};


subtest 'Fallback' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'zTtx_rFg__l_',
        args    => q{},
        nick    => 'someone',
        status  => 1,
        context => 'should_validate',
    );

    my $expect = [
        [
            'notice',
            'someone',
            q{!zTtx_rFg__l_?!? I don't know what you're on about, someone. }
                . q{Try } . BOLD . q{!help} . BOLD
        ],
    ];

    is_deeply( $test->response(), $expect, 'Fall back response ok' );
};


subtest 'Forum URL' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'rules',
        args    => q{},
        nick    => 'someone',
        status  => 1,
        context => 'should_validate_this',
    );

    my $expect = [ [ 'notice', 'someone', 'http://nah.what.for/' ] ];
    is_deeply( $test->bot_url(), $expect, 'URL response ok' );
};


subtest 'Rules' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'rules',
        args    => q{},
        nick    => 'someone',
        status  => 1,
        context => 'should_validate_this',
    );

    my $expect = [
        [ 'notice', 'someone', 'This is a rule' ],
        [ 'notice', 'someone', 'Mention #my_hang_out here' ],
        [ 'notice', 'someone', 'Then mention tIgor and tIgor' ],
        [
            'notice',
            'someone',
            'Two different tags. First tIgor then #my_hang_out here'
        ],
        [
            'notice',
            'someone',
            'There is no config entry for <<_this_tag_>> so leave it alone'
        ],
    ];

    is_deeply( $test->response(), $expect, 'Rules response ok' );
};


subtest 'Count profiles' => sub {
    my @base = (
        config  => $CONFIG,
        trigger => 'profiles',
        args    => q{not relevant},
        nick    => 'counter',
        context => 'notice',
    );

    my $test = $module->new( @base, status => $CONFIG->{status}->{bop}, );

    my $text = q{6 profiles, 3 complete.};
    my $expect = [ [ 'notice', 'counter', $text ] ];
    is_deeply( $test->response(), $expect, 'Response to profiles command ok' );
};


subtest 'Get database profile' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'profiles',
        args    => q{not relevant},
        nick    => 'tester',
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
    );

    throws_ok
        { $test->db_profile() }
        qr/Nick[ ]argument[ ]required/msx,
        q{Nick argument required to fetch the profile};

    is( $test->db_profile('cannot exist'),
        undef, 'Return undef if no profile found' );

    is(
        ref $test->db_profile('mrturniphead'),
        'Igor::Schema::Result::Profile',
        q{Otherwise return a profile object}
    );

    throws_ok { $test->no_profile_response() }
        qr/Nick[ ]argument[ ]required/msx,
        q{Nick argument required for response when it's not found};

    is_deeply(
        $test->no_profile_response('blahblah'),
        [
            [
                'notice', 'tester',
                q{Sorry, I don't have a profile for blahblah.},
            ],
        ],
        q{Correct response for missing profile}
    );
};

subtest 'Scram' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'scram',
        args    => q{},
        nick    => 'quitter',
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
    );

    is_deeply( $test->response(), [ ['disconnect'] ], 'Send kill signal' );
};


subtest 'Raw' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'raw',
        args    => q{           },
        nick    => 'uncooked',
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
    );

    is_deeply(
        $test->response(),
        [ [ 'notice', 'uncooked', 'No argument supplied.' ] ],
        'Reject raw command without args'
    );

    $test = $module->new(
        config  => $CONFIG,
        trigger => 'raw',
        args    => q{anything will do},
        nick    => 'uncooked',
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
    );

    is_deeply(
        $test->response(),
        [ [ 'send_raw', 'uncooked', 'anything will do' ] ],
        'Otherwise spit it back'
    );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
