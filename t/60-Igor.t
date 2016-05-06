#!/usr/bin/env perl
use 5.014;
use warnings;

use Cwd;
use Test::More 'no_plan';# tests => ??;
use Test::Exception;

use lib('t');
use t::config;

our $VERSION = 3.009;

my $module = q{Igor};

subtest 'Sanity checks' => sub {
    use_ok($module);

    # All the 'bot_*' methods are tested separately.
    can_ok(
        $module,
        qw{
            devel deputy config log_path command_rgx no_nick_rgx schema irc
            nsplugin rcplugin logger session run irc_001 irc_public irc_notice
            irc_msg irc_ctcp irc_join irc_nick handled_by_guest_bot announce
            process_command voice_user has_profile detail_user BUILD
            check_bans backup_db have_sendmail send_raw disconnect enforce_ban
            apply_ban_to_channel get_random_intro afk_nick_rgx
        }
    );

    throws_ok { $module->new( devel => 1, deputy => 1 ) }
            qr/Either be a devel test or be a deputy - not both/ms,
            q{Don't allow devel and deputy together};

    lives_ok { $module->new( devel  => 1 ) } 'Start in devel mode';
    lives_ok { $module->new( deputy => 1 ) } 'Start in deputy mode';

};

my $test;
subtest 'Load config' => sub {
    lives_ok { $test = $module->new() } q{Object creation ok};
    is( $test->config->{max_temp}, 1_000_000, 'Default config' );

    $test = $module->new( config => $CONFIG );
    is( $test->config->{max_temp},    98_765, 'Config argument accepted' );

    is(
        $test->log_path(), getcwd() . q{/save/logs/here},
        'log_path attribute ok'
    );
};

subtest 'Guest bot' => sub {
    ok(1);
};


subtest 'Process commands' => sub {
    ok(1);
};

subtest 'Process commands' => sub {
    ok(1);
};

subtest 'Voice user' => sub {
    ok(1);
};

subtest 'Look for profile' => sub {
    ok(1);
};

subtest 'User detail' => sub {
    ok(1);
};

subtest 'Check for bans' => sub {
    ok(1);
};

subtest 'Look for sendmail' => sub {
    ok(1);
};

subtest 'Raw commands' => sub {
    ok(1);
};

subtest 'Shut down' => sub {
    ok(1);
};

1;
