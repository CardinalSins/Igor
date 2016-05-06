#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;
use Test::Exception;
use autodie qw{:all};

our $VERSION = 3.009;

my $module = q{t::schema};

# Shame to hardcode these, but is it worth using the config file?
my $test_db = q{t/data/profiles.db};
my $fix_dir = q{t/data/fixtures};
my $config  = q{t/data/test.yaml};
( -e $test_db ) && ( unlink $test_db );


subtest 'Sanity checks' => sub {
    use_ok($module);
    can_ok( $module, qw{ fixtures_dir config_file config schema } );

    ok( -e $config,  'Test config file is present' );
    ok( -d $fix_dir, 'Fixtures directory is present' );
    ok(
        scalar( glob qq{$fix_dir/*.yml} ),
        'There are fixture files in the directory'
    );
};


subtest 'Basic functioning' => sub {
    my $test = $module->new();
    isa_ok( $test, $module );

    my $schema = $test->schema();

    ok( $schema->resultset('Profile')->count() > 0, 'We have test profiles' );
    ok( $schema->resultset('Ban')->count() > 0,     'We have test bans' );

    my ( $profile, $ban );

    lives_ok
        { $profile = $schema->resultset('Profile')->find('mrturniphead') }
        'Can find a profile';

    is( $profile->age(), '23', 'Sample detail checks out' );

    ok( $ban = $schema->resultset('Ban')->find(2), 'Can find a ban' );

    is( $ban->set_by(), 'katy', 'Sample detail good here too' );
};

open my $fh, q{>}, $test_db;
close $fh;

lives_ok
    { my $test = $module->new() }
    'Presence of a database file does not break anything';

# Clean up.
( -e $test_db ) && ( unlink $test_db );

1;
