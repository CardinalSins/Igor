#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Deep;
use Test::Exception;
use IRC::Utils qw{:ALL};
use t::config;
use Igor::Config;


our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);


subtest 'Complete set of help lines' => sub {
    my $conf_obj = Igor::Config->new(
        file   => 'IgorConfig.json',
        devel  => 0,
        deputy => 0,
    );
    my $live_config = $conf_obj->get_config_from_file();

    my $test = $module->new(
        trigger => 'help',
        nick    => 'clueless',
        config  => $live_config,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        args    => q{},
    );

    my $policies = scalar keys %{ $live_config->{policy} };
    my $fields   = scalar @{ $live_config->{all_fields} };

    # No help line for any of the profile field editing commands.
    ok( scalar keys %{ $test->trigger_methods() } == $policies + $fields,
        q{There's a policy for each command} );

    my $no_help_text = 0;

    # Make sure there's a help entry in each policy and that none are blank.
    foreach my $command ( keys %{ $test->config->{policy} } ) {
        my $entry = $test->config->{policy}->{$command};

        if (   ( not exists $entry->{help} )
            || ( ref $entry->{help} ne 'ARRAY' ) )
        {
            $no_help_text++;
            next;
        }

        foreach my $text ( @{ $entry->{help} } ) {
            if ( length $text == 0 ) {
                $no_help_text++;
                next;
            }
        }
    }

    ok( !$no_help_text, qq{There are $no_help_text missing help texts} );
};


my @base = (
    trigger => 'help',
    nick    => 'clueless',
    args    => q{blah blah},
    config  => $CONFIG,
);


subtest 'Check input' => sub {
    my $test;

    dies_ok {
        $test = $module->new(
            @base,
            context => 'notice',
            status  => undef,
        );
    }
    'Require user status';

    $test = $module->new(
        @base,
        context => 'notice',
        status  => 0,
    );

    lives_ok { $test->response() } 'Even 0 will do';

    throws_ok { $test->single_help() } qr/Trigger name required/ms,
        'Require command name';
};


subtest 'Reponses' => sub {
    my $test = $module->new(
        @base,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        args    => q{},
    );

    my $expect_all = [
        [ 'notice', 'clueless', 'How to add an intro' ],
        [
            'notice', 'clueless',
            'Use ' . BOLD . '!banish <mask> <#> <time>' . BOLD
                . ' to set a ban, clueless'
        ],
        [
            'notice', 'clueless',
            'Note that tIgor checks these for #my_hang_out'
        ],
        [
            'notice', 'clueless',
            'PM ' . BOLD . '!banlist' . BOLD
                . ' to tIgor to get details of current timed bans.'
        ],
        [ 'notice', 'clueless', 'How to find last access date for profile' ],
        [ 'notice', 'clueless', 'How to get an inspirational quote' ],
        [ 'notice', 'clueless', 'How to confess your sins' ],
        [ 'notice', 'clueless', 'To convert x to y do blah, blah, blah.' ],
        [ 'notice', 'clueless', 'How to copy profiles' ],
        [ 'notice', 'clueless', 'How to delete an intro' ],
        [ 'notice', 'clueless', 'How to make a sock-puppet' ],
        [ 'notice', 'clueless', q{How to edit other people's profiles} ],
        [ 'notice', 'clueless', 'How to delete profiles' ],
        [ 'notice', 'clueless', 'How to find an intro' ],
        [ 'notice', 'clueless', 'How to delete bans' ],
        [ 'notice', 'clueless', 'Talk to the other guy about that' ],
        [ 'notice', 'clueless', 'How to get help' ],
        [ 'notice', 'clueless', 'How to look at profiles' ],
        [ 'notice', 'clueless', 'How many profiles' ],
        [ 'notice', 'clueless', 'Help for raw command.' ],
        [ 'notice', 'clueless',
            'Type ' . BOLD . '!refine' . BOLD
                . ' for the list of commands to modify your profile.'
        ],
        [ 'notice', 'clueless', 'Here are the rules' ],
        [ 'notice', 'clueless', 'How to get lost.' ],
        [ 'notice', 'clueless', 'How to sweep out old bans' ],
    ];

    readpipe(q{which fortune})
        && push @{$expect_all},
            [ 'notice', 'clueless', 'How to get fortune cookies' ];

    my $boilerplate =  'Wrought in the smithy of Gil_Gamesh. '
                    .  'Powered by Igor v' . $Igor::Command::VERSION
                    .   '. Finding brains for my Master(s) since 2008.';

    push @{$expect_all}, [ 'notice', 'clueless', $boilerplate ];


    cmp_bag( $test->response(), $expect_all,
        'Help on help returned as default' );

    $test = $module->new(
        @base,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        args    => q{_riddiklous__commandNNName},
    );

    my $expect = [ 'notice', 'clueless', 'How to get help' ];
    is_deeply( $test->response(), [$expect],
        'Full help returned for unrecognised command' );

    $test = $module->new(
        @base,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        args    => q{banlist},
    );

    is_deeply(
        $test->response(),
        [ [
            'notice', 'clueless',
            'PM ' . BOLD . '!banlist' . BOLD
                . ' to tIgor to get details of current timed bans.'
        ] ],
        'Help for single, specified, command'
    );

    $test = $module->new(
        @base,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        args    => q{loc},
    );

    is_deeply(
        $test->response(),
        [ [ 'notice', 'clueless', 'Type ' . BOLD . '!refine' . BOLD
                . ' for the list of commands to modify your profile.' ] ],
        'Translate profile editing command'
    );

    $test = $module->new(
        @base,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        args    => q{f2k},
    );

    is_deeply(
        $test->response(),
        [ [ 'notice', 'clueless', 'To convert x to y do blah, blah, blah.' ] ],
        'Translate conversion command'
    );

    $test = $module->new(
        @base,
        context => 'notice',
        status  => $CONFIG->{status}->{there},
        args    => q{f2k},
    );

    is_deeply( $test->response(), [],
        'Response to private command determined by status' );

    $test = $module->new(
        @base,
        context => '#my_hang_out',
        status  => $CONFIG->{status}->{there},
        args    => q{f2k},
    );

    is_deeply( $test->response(), [],
        'Response to public command determined by status' );

    $test = $module->new(
        @base,
        context => '#my_hang_out',
        status  => $CONFIG->{status}->{sop},
        args    => q{f2k},
    );

    is_deeply(
        $test->response(),
        [ [ 'notice', 'clueless', 'To convert x to y do blah, blah, blah.' ] ],
        'Status exceeding one cut-off is enough'
    );

    ## no critic (ProhibitMagicNumbers)
    $CONFIG->{policy}->{new_command} = {
        help    => [],
        private => [ 6, q{Some helpful text.} ],
        public  => [ 6, q{More helpful text.} ],
    };

    ## use critic
    $test = $module->new(
        @base,
        context => '#my_hang_out',
        status  => $CONFIG->{status}->{bop},
        args    => q{},
    );
    cmp_bag( $test->bot_help(), $expect_all, 'Missing help is skipped' );

};

1;
