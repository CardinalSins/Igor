#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 8;
use Test::Deep;
use Test::Exception;
use IRC::Utils qw{:ALL};

our $VERSION = 3.009;

my $module            = q{Igor::Config};
my $default_conf_file = q{IgorConfig.json};
my $test_conf_file    = q{t/data/test.yaml};


subtest 'Sanity checks' => sub {
    use_ok($module);
    can_ok( $module, qw{get_config_from_file} );
    ok( -e $default_conf_file, 'Default config is present' );
    ok( -e $test_conf_file,    'Test config is present' );
};

# Because profile field names are tightly bound to the triggers and to method
# names, we need to make sure that all the actual triggers are listed in the
# test config.
subtest 'Realistic config' => sub {
    my $real_conf =
        $module->new( file => $default_conf_file )->get_config_from_file();
    my $test_conf =
        $module->new( file => $test_conf_file    )->get_config_from_file();

    cmp_bag(
        $real_conf->{all_fields}, $test_conf->{all_fields}, 'all_fields ok'
    );

    cmp_bag(
        $real_conf->{optional_fields},
        $test_conf->{optional_fields},
        'optional_fields ok'
    );

    cmp_bag(
        $real_conf->{teaser_fields},
        $test_conf->{teaser_fields},
        'teaser_fields ok'
    );
};


my $temp = q{/does/_not_/exist.jayson};
lives_ok { my $test = $module->new( file => $temp ) } 'Does this blow up?';


subtest 'Basic functioning' => sub {
    my $test = $module->new();
    isa_ok( $test, $module );

    is( $test->deputy(), undef,              'Deputy is off by default' );
    is( $test->devel(),  undef,              'Devel is off by default' );
    is( $test->file(),   $default_conf_file, 'Find the default config file' );
};

## no critic (ProhibitMagicNumbers)
my %core_policy = (
    addintro => {
        help => [ q{How to add an intro} ],
        private => [ 3, q{No, no, no} ],
        public  => [ 3, q{Still no} ],
    },
    delintro => {
        help => [ q{How to delete an intro} ],
        private => [ 3, q{Not a chance} ],
        public  => [ 3, q{Slim and f**k all} ],
    },
    findintro => {
        help => [ q{How to find an intro} ],
        private => [ 3, q{You again?} ],
        public  => [ 3, q{Get outta here} ],
    },
    banish => {
        help => [
            q{Use } . BOLD . q{!banish <mask> <#> <time>} . BOLD
                . q{ to set a ban, <<nick>>},
            q{Note that tIgor checks these for #my_hang_out}
        ],
        private => [ 4, q{That command is above your pay grade.} ],
        public  => [ 4, q{You're over-reaching there, bub.} ]
    },
    banlist => {
        help => [
            q{PM } . BOLD . q{!banlist} . BOLD
                . q{ to tIgor to get details of current timed bans.}
        ],
        private => [ 6, q{That information is classified.} ],
        public  => [ 6, q{Access denied, corporal.} ],
    },
    check => {
        help    => [q{How to find last access date for profile}],
        private => [ 3, q{Some excuse} ],
        public  => [ 4, q{More of the same} ],
    },
    cite => {
        help    => [q{How to get an inspirational quote}],
        private => [ 2, q{Set it low} ],
        public  => [ 2, q{Here too} ],
    },
    confess => {
        help    => [q{How to confess your sins}],
        private => [ 1, q{Whisper the reason} ],
        public  => [ 1, q{Why you can't do that goes here.} ],
    },
    convert => {
        help    => [q{To convert x to y do blah, blah, blah.}],
        private => [ 6, q{An exclusive club.} ],
        public  => [ 4, q{Won't convert for you.} ],
    },
    copy => {
        help    => [q{How to copy profiles}],
        private => [ 3, q{Njet, comrad} ],
        public  => [ 4, q{No, no, no.} ],
    },
    db_backup => {
        help    => [q{How to back-up the database}],
        private => [ 7, q{Backup up is off} ],
        public  => [ 6, q{Got a headache} ],
    },
    erase => {
        help    => [q{How to delete profiles}],
        private => [ 6, q{Running out of these} ],
        public  => [ 6, q{So boring} ],
    },
    e => {
        help    => [q{How to make a sock-puppet}],
        private => [ 7, q{Oh yawn} ],
        public  => [ 6, q{No way, Jose} ],
    },
    edit => {
        help    => [q{How to edit other people's profiles}],
        private => [ 2, q{Oppa, Gangnam style} ],
        public  => [ 3, q{Tum-te-tum} ],
    },
    forgive => {
        help    => [q{How to delete bans}],
        private => [ 4, q{You should just copy the live settings} ],
        public  => [ 3, q{That would make them set in stone though} ],
    },
    fortune => {
        help    => [q{How to get fortune cookies}],
        private => [ 5, q{Or would it?} ],
        public  => [ 3, q{Meh. Nearly done.} ],
    },
    guest_command => {
        help    => [q{Talk to the other guy about that} ],
        private => [ 1, q{I don't handle that} ],
        public  => [ 1, q{Or this, either} ],
    },
    help => {
        help    => [q{How to get help}],
        private => [ 1, q{You're hardly going to block this one anyway} ],
        public  => [ 1, q{Unless you're feeling mean} ],
    },
    ogle => {
        help    => [q{How to look at profiles}],
        private => [ 4, q{And finally...} ],
        public  => [ 3, q{This one!} ],
    },
    profiles => {
        help    => [q{How many profiles}],
        private => [ 2, q{Not telling} ],
        public  => [ 3, q{I said...} ],
    },
    raw => {
        help    => [q{Help for raw command.}],
        private => [ 2, q{Uncooked nonsense.} ],
        public  => [ 5, q{Can't let you do this, Dave.} ],
    },
    refine => {
        help    => [
            q{Type } . BOLD . q{!refine} . BOLD
                . q{ for the list of commands to modify your profile.}
        ],
        private => [ 1, q{} ],
        public  => [ 1, q{} ],
    },
    rules => {
        help    => [q{Here are the rules}],
        private => [ 1, q{Who are you?} ],
        public  => [ 1, q{I said...} ],
    },
    scram => {
        help    => [q{How to get lost.}],
        private => [ 6, q{Sorry. No.} ],
        public  => [ 6, q{Not today.} ],
    },
    sweep => {
        help    => [q{How to sweep out old bans}],
        private => [ 4, q{Gibberish} ],
        public  => [ 4, q{Here's your broom} ],
    },
);
my @core_expect = (
    all_fields => [qw/ age sex loc bdsm limits kinks fantasy desc quote intro/],
    backup_email_address => [ 'someone@some.where.tld', 'another@one.to.email' ],
    db_file   => 't/data/profiles.db',
    bot_nick  => 'tIgor',
    channel   => '#my_hang_out',
    guest_bot => q{smashy_n_nicey},
    guest_function => q{radio},
    guest_commands => [qw/ tunein 8ball /],
    have_guest_bot => 1,
    examples       => {
        age  => q{!age 32 or !age decrepit},
        bdsm => q{!bdsm painslut or !bdsm switch},
        desc => q{whatever you want - physical, psychological, spiritual or}
              . q{ stream of consciousness},
        kinks   => q{!kinks clowns, intimacy, the cold, cold, ground},
        loc     => q{!loc Paris, Texas or !loc Ummm, look under your desk...},
        limits  => q{!limits txtspeek, profilebots, wet spots},
        fantasy => q{!fantasy literacy, legs, being hogtied},
        sex     => q{!sex Straight, male or !sex dysfunctional},
        quote   => q{!quote smart stuff here},
        intro   => q{!intro ta-daaaa!},
    },
    forum_url             => 'http://nah.what.for/',
    log_directory         => 'save/logs/here',
    longest_ban           => 100,
    longest_fortune       => 480,
    longest_intro         => 50,
    longest_nick          => 30,
    longest_profile_field => 410,
    longest_teaser_field  => 66,
    max_temp              => 98_765,
    optional_fields => [qw/ quote intro /],
    policy                => \%core_policy,
    prompts => {
        age     => q{Enter your age with },
        bdsm    => q{Enter your position on the BDSM spectrum with },
        desc    => q{Enter a word picture with },
        kinks   => q{Tell us about things that scare you with },
        loc     => q{Enter your location with },
        limits  => q{Tell us some of the things that tick you off with },
        fantasy => q{Share what makes you hot under the collar with },
        sex     => q{Enter your gender and/or sexual orientation with },
        quote   => q{Inspire us with },
        intro   => q{Impress us with },
    },
    real_bot => 'testIgor',
    rules    => [
        'This is a rule',
        'Mention #my_hang_out here',
        'Then mention tIgor and tIgor',
        'Two different tags. First tIgor then #my_hang_out here',
        'There is no config entry for <<_this_tag_>> so leave it alone',
    ],
    search_result_max => 3,
    shortest_mask     => 5,
    shortest_search   => 4,
    status            => {
        aop   => 4,
        bop   => 7,
        hop   => 3,
        out   => 0,
        owner => 6,
        sop   => 5,
        there => 1,
        voice => 2,
    },
    tags => {
        age     => q{Age},
        bdsm    => q{BDSM},
        desc    => q{Description},
        limits  => q{Limits},
        loc     => q{Location},
        kinks   => q{Kinks},
        fantasy => q{Fantasy},
        sex     => q{Sex},
        quote   => q{Quote},
        intro   => q{Intro},
    },
    teaser_fields    => [qw/ age sex loc bdsm /],
    timestamp_db     => q{%F %T},
    timestamp_output => q{%T, %A, %d %B, %Y %Z},
);

subtest 'Reading config values' => sub {
    my $test = $module->new( file => $default_conf_file );
    my $config = $test->get_config_from_file($test_conf_file);

    is( ref $config,         'HASH',        'Config object created' );
    is( $config->{username}, 'i_am_config', 'Over-ride constructor file' );
    ok( !exists $config->{deputy}, 'Deputy section is ignored' );
    ok( !exists $config->{devel},  'Devel section is ignored' );

    my $expect = {
        @core_expect,
        server_list => [qw/ irc.chatrooms.com irc.gossip.com /],
        username    => 'i_am_config',
        style       => { colour => 'red', size => 12 },
    };

    is_deeply( $config, $expect, 'Config values are as expected' );

    lives_ok {
        $test = $module->new( file => 'IgorConfig.json' );
        $config = $test->get_config_from_file();
    }
    'Can get config without specific file argument';

    is( $config->{bot_nick}, 'Igor', 'Live argument confirms read' );
};


my %deputy_policy = (
    %core_policy,
    refine => {
        private => [ 10, q{Profile editing commands disabled for a while.}, ],
        public  => [ 10, q{Profile commands are disabled for a while.}, ],
        help    => [ q{Profile editing disabled for now.}, ],
    },
);


subtest 'Set deputy' => sub {
    my $test = $module->new( deputy => 1 );
    my $config = $test->get_config_from_file($test_conf_file);

    is( $test->deputy(), 1,     'Deputy is switched on' );
    is( $test->devel(),  undef, 'Devel is still off' );

    my $expect = {
        @core_expect,
        server_list => [qw/ irc.deputy.com irc.deputy.org /],
        username    => 'deputy_config',
        style       => { colour => 'red', size => 12 },
        policy      => \%deputy_policy,
    };

    is_deeply( $config, $expect, 'Config values are as expected' );
};


subtest 'Set test' => sub {
    my $test = $module->new( devel => 1 );
    my $config = $test->get_config_from_file($test_conf_file);

    is( $test->devel(),  1,     'Devel is switched on' );
    is( $test->deputy(), undef, 'Deputy is off' );

    my $expect = {
        @core_expect,
        server_list => [qw/ irc.chatrooms.com irc.gossip.com /],
        username    => 'test_config',
        style       => { emphasis => 'bold', size => 15, colour => 'red' },
    };

    is_deeply( $config, $expect, 'Config values are as expected' );
};

subtest 'Test settings override deputy settings' => sub {
    my $test = $module->new( devel => 1, deputy => 1 );
    my $config = $test->get_config_from_file($test_conf_file);

    is( $test->devel(),  1, 'Devel is switched on' );
    is( $test->deputy(), 1, 'Deputy is switched on' );

    my $expect = {
        @core_expect,
        server_list => [qw/ irc.deputy.com irc.deputy.org /],
        username    => 'test_config',
        style       => { emphasis => 'bold', size => 15, colour => 'red' },
        policy      => \%deputy_policy,
    };

    is_deeply( $config, $expect, 'Config values are as expected' );
};

1;
