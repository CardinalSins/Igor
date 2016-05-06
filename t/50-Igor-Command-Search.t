#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 7;
use Test::Exception;
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new(
                fixtures_dir => q{t/data/fixtures/search},
                config       => $CONFIG
             )->schema();

my $intro = q{I found the following matches to your search. Use }
          . BOLD . q{!ogle <nick>} . BOLD . q{ to see more.};

use_ok($module);


subtest 'Base method' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        trigger => 'wholikes',
        args    => 'one two a b three',
        nick    => 'searcher',
        status  => $CONFIG->{status}->{bop},
        context => 'notice',
    );

    ## no critic (RequireExtendedFormatting)
    throws_ok
        { $test->look_for() }
        qr/Field name required as first argument/ms,
        'Complain about first argument';

    throws_ok
        { $test->look_for( 'proofile', qr/banana/imsx ) }
        qr/Unrecognized field name: proofile/ms,
        q{Complain about unrecognised first argument};

    throws_ok
        { $test->look_for( 'profile', 'banana' ) }
        qr/Regex required as second argument/ms,
        q{Complain about second argument when it's the wrong type};

    throws_ok
        { $test->look_for('profile') }
        qr/Regex required as second argument/ms,
        q{Complain about second argument when it's not there};
};


## use critic
subtest 'Check user input' => sub {
    my @base = (
        config  => $CONFIG,
        nick    => 'searcher',
        status  => $CONFIG->{status}->{bop},
        trigger => 'wholikes',
        context => 'notice',
    );

    my $test = $module->new( @base, args => q{} );

    throws_ok
        { $test->search_profile() }
        qr/Field name required as first argument/ms,
        'Insist on first argument';

    throws_ok
        { $test->search_profile('banana') }
        qr/Unrecognised field name/ms,
        'Reject strange arguments';

    my $expect = [
        q{notice}, q{searcher},
        q{My time is valuable, you know.}
            . q{ Enter something to actually search for next time.}
    ];
    is_deeply( $test->search_profile('kinks'),
        [$expect], q{Insist on argument to original command} );

    $test = $module->new( @base, args => 'a' );

    $expect = [
        q{notice}, q{searcher},
        q{'a' is too short. Try searching for something longer - F'nar, F'nar!}
    ];
    is_deeply(
        $test->search_profile('kinks'),
        [$expect], q{Argument is too short},
    );

    $test = $module->new( @base,
        args => 'sesquipedalian polysyllabic in verbosity' );

    $expect = [
        q{notice}, q{searcher},
        q{'in' is too short. Try searching for something longer - F'nar, F'nar!}
    ];
    is_deeply(
        $test->search_profile('kinks'),
        [$expect], q{Reject short words among long ones},
    );
};


subtest 'Sorting' => sub {
    my @test_case = (
        { score => 3, date => '2005-07-03' },
        { score => 7, date => '2005-07-03' },
    );

    my @expect = (
        { score => 7, date => '2005-07-03' },
        { score => 3, date => '2005-07-03' },
    );

    # I can't use $module here.
    my @sorted = Igor::Command::sort_by_score_then_date(@test_case);
    is_deeply( \@sorted, \@expect, 'Sort by score' );

    push @test_case, { score => 3, date => '2005-07-04' };

    @expect = (
        { score => 7, date => '2005-07-03' },
        { score => 3, date => '2005-07-04' },
        { score => 3, date => '2005-07-03' },
    );

    @sorted = Igor::Command::sort_by_score_then_date(@test_case);
    is_deeply( \@sorted, \@expect, 'Sort by date' );

};


subtest 'Searches' => sub {
    my @base = (
        config  => $CONFIG,
        nick    => 'searcher',
        status  => $CONFIG->{status}->{bop},
        trigger => 'wholikes',
        context => 'notice',
    );

    my $test = $module->new( @base, args => q{neeever phynd enieth8ng} );

    is_deeply( $test->look_for( 'kinks', qr/neeever|phynd|enieth8ng/imsx ),
        [], q{Empty array for no results} );

    is_deeply(
        $test->search_profile('kinks'),
        [
            [
                'notice',
                'searcher',
                q{Sorry, I didn't find any matches.}
                    . q{ I guess you're a special kind of freak...}
            ]
        ],
        q{Report empty result to user}
    );


    $test = $module->new( @base, args => q{uniquely distinctive proclivities} );

    is_deeply(
        $test->look_for(
            'kinks', qr/uniquely|distinctive|proclivities/imsx
        ),
        [
            {
                nick  => q{udp_guy},
                text  => q{I have uniquely distinctive and odd proclivities},
                score => 3,
                date  => q{2011-01-15 12:34:01},
            }
        ],
        q{Find a single match}
    );

    my $expect = BOLD . q{udp_guy} . BOLD
               . q{: I have uniquely distinctive and odd proclivities};
    is_deeply(
        $test->search_profile('kinks'),
        [
            [ 'notice', 'searcher', $intro ],
            [ 'notice', 'searcher', $expect ],
        ],
        q{Report single match to user}
    );

    $test = $module->new( @base, args => q{distinctive proclivities uniquely} );

    is_deeply(
        $test->search_profile('kinks'),
        [
            [ 'notice', 'searcher', $intro ],
            [ 'notice', 'searcher', $expect ],
        ],
        q{Order of search terms doesn't matter}
    );

    $test = $module->new( @base, args => q{^^^^^ ch@r$ {awkward!}} );

    $expect = BOLD . q{metachars} . BOLD
            . q{: I have {awkward!} ch@r$ in ][ere ^^^^^^^};

    is_deeply(
        $test->search_profile('kinks'),
        [
            [ 'notice', 'searcher', $intro ],
            [ 'notice', 'searcher', $expect ],
        ],
        q{Metacharacters in the search time ok}
    );

    #>>>
    $test = $module->new( @base, args => q{mould inJection geNERic} );
    $expect = q{Generic injection mould profile};

    is(
        scalar @{
            $test->look_for( 'kinks', qr/mould|inJection|geNERic/imsx )
        },
        '4',
        q{Find all the matching profiles}
    );

    # Remember that there's a 'header' line.
    is(
        scalar @{ $test->search_profile('kinks') },
        '4',
        q{But only report the configured limit}
    );

    $test = $module->new( @base, args => q{fourteen thirteen twelve eleven} );

    $expect = [
        {
            nick  => 'first',  date => '2999-12-12 23:59:59',
            score => 4,        text => 'tWelve Thirteen FourTeen Eleven'
        },
        {
            nick  => 'second', date => '2999-12-12 23:59:58',
            score => 4,        text => 'Eleven FourTeen tWelve Thirteen'
        },
        {
            nick  => 'third',  date => '2999-12-12 23:59:59',
            score => 3,        text => 'Eleven tWelve Thirteen'
        },
        {
            nick  => 'fourth', date => '2999-12-12 23:59:58',
            score => 3,        text => 'Eleven Thirteen FourTeen'
        },
    ];

    is_deeply(
        $test->look_for( 'kinks', qr/fourteen|thirteen|twelve|eleven/imsx ),
        $expect,
        'Correct order of full results'
    );

    $expect = [
        [ 'notice', 'searcher', $intro ],
        [
            'notice', 'searcher',
            BOLD . 'first'  . BOLD . ': tWelve Thirteen FourTeen Eleven'
        ],
        [
            'notice', 'searcher',
            BOLD . 'second' . BOLD . ': Eleven FourTeen tWelve Thirteen'
        ],
        [
            'notice', 'searcher',
            BOLD . 'third'  . BOLD . ': Eleven tWelve Thirteen'
        ],
    ];

    is_deeply( $test->search_profile('kinks'),
        $expect, 'Search report is correct' );
};


subtest 'Other fields' => sub {
    my @base = (
        config  => $CONFIG,
        nick    => 'searcher',
        status  => $CONFIG->{status}->{bop},
        context => 'notice',
    );

    my $test = $module->new(
        @base,
        trigger => 'whowantsto',
        args    => 'finding fantasy test',
    );

    my $expect = BOLD . 'i_have_fantasy' . BOLD . ': test for finding fantasy';

    is_deeply(
        $test->search_profile('fantasy'),
        [
            [ 'notice', 'searcher', $intro ],
            [ 'notice', 'searcher', $expect ],
        ],
        'Search works for fantasy'
    );

    $test = $module->new(
        @base,
        trigger => 'whohates',
        args    => 'finding limits test',
    );

    $expect = BOLD . 'i_have_limits' . BOLD . ': test for finding limits';

    is_deeply(
        $test->search_profile('limits'),
        [
            [ 'notice', 'searcher', $intro ],
            [ 'notice', 'searcher', $expect ],
        ],
        'Search works for limits'
    );

    $test = $module->new(
        @base,
        trigger => 'whowrote',
        args    => 'finding description test',
    );

    $expect = BOLD . 'i_have_desc' . BOLD . ': test for finding description';

    is_deeply(
        $test->search_profile('desc'),
        [
            [ 'notice', 'searcher', $intro ],
            [ 'notice', 'searcher', $expect ],
        ],
        'Search works for description'
    );
};

# We've shown that the underlying method work, so just getting a 'not found'
# response for the four wrapper methods to show that they're calling the
# others will do.
subtest 'Wrapper methods' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        nick    => 'wraptest',
        status  => $CONFIG->{status}->{bop},
        context => 'notice',
        trigger => 'whowrote',
        args    => 'un1ik3lee_surchturm',
    );

    my $expect = [
        [
            'notice',
            'wraptest',
            q{Sorry, I didn't find any matches.}
                . q{ I guess you're a special kind of freak...}
        ]
    ];

    is_deeply( $test->bot_whowrote(),   $expect, 'whowrote wrapper ok' );
    is_deeply( $test->bot_wholikes(),   $expect, 'wholikes wrapper ok' );
    is_deeply( $test->bot_whowantsto(), $expect, 'whowantsto wrapper ok' );
    is_deeply( $test->bot_whohates(),   $expect, 'whohates wrapper ok' );
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
