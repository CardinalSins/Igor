#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;
use Test::Exception;
use Carp;
use DateTime;
use DateTime::Format::Strptime;
use DBI;
use File::Slurp;
use List::MoreUtils qw{any};
use autodie qw{:all};
use t::config;

our $VERSION = 3.009;

my $module  = q{Igor::DB};
my $db_file = q{t/data/profiles.db};
( -e $db_file ) && ( unlink $db_file );

my $test_db;
my $fixtures_dir = q{t/data/fixtures};

subtest 'Sanity checks' => sub {
    use_ok($module);
    can_ok( $module, qw{build_db} );

    ok( !-e $db_file, 'No old database files lying around' );

    lives_ok
        { $test_db = $module->new( { db_file => $db_file } ) }
        'Connect to database';

    throws_ok
        { $test_db->_load_fixtures('lib') }
        qr/No[ ]fixtures[ ]found[ ]at[ ]lib/msx,
        'Croak if no fixtures found';

    lives_ok { $test_db->build_db($fixtures_dir) } 'Populate the database';
};


my $schema     = $test_db->schema();
my $profile_rs = $schema->resultset('Profile');
my $ban_rs     = $schema->resultset('Ban');


## no critic (ProhibitMagicNumbers)
subtest 'Check contents' => sub {
    my @profiles = $profile_rs->all();
    is( scalar @profiles, 6, 'All profiles present' );

    my @bans = $ban_rs->all();
    is( scalar @bans, 5, 'All bans present' );
};

## use critic
# There's some disconnect with this test. Database (server) triggers are
# not translated by dbicdump into the Schema::Result classes, so we add them
# in Igor::DB::build_db by reading a file of the SQL code that generates the
# database.
# This depends on that file being properly maintained but that doesn't seem
# like much of an ask.

my $strp = DateTime::Format::Strptime->new(
    pattern  => '%Y-%m-%d %H:%M:%S',
    on_error => 'croak',
);

subtest 'Check triggers' => sub {
    my $trigger_file = q{t/data/trigger_test.db};
    ( -e $trigger_file ) && ( unlink $trigger_file );

    my $trigger_db;

    lives_ok
        { $trigger_db = $module->new( { db_file => $trigger_file } ) }
        'Connect to new database for trigger test';

    $trigger_db->build_db($fixtures_dir);

    $profile_rs = $trigger_db->schema->resultset('Profile');

    my $new = $profile_rs->find( { nick => 'test_breaks_if_exists' } );

    ok( !$new, 'Test profile does not exist yet' );

    $new = $profile_rs->create( { nick => 'test_breaks_if_exists' } );
    $new->update();

    $new = $new->get_from_storage();
    ok( $new, 'Profile created' );

    # This test will fail on a leap second.
    like(
        $new->last_access(),
        qr/\d{4}-[01]\d-[0123]\d[ ][012]\d(?::[0-5]\d){2}/msx,
        'Last access field has been set'
    );

    my $old_time = $strp->parse_datetime( $new->last_access() );

    foreach my $field ( @{ $CONFIG->{all_fields} } ) {
        next if $field eq 'nick';
        next if any { $_ eq $field } @{ $CONFIG->{optional_fields} };
        sleep 1;
        $new->$field('something');
        $new->update();
        $new = $new->get_from_storage();
        my $new_time = $strp->parse_datetime( $new->last_access() );
        ok( $new_time->subtract_datetime($old_time)->in_units('seconds') > 0,
            qq{$field update triggers last_access update} );
        $old_time = $new_time;
    }


    ####
    # Need to test that optional fields do NOT update last_access


    unlink $trigger_file;
};

( -e $db_file ) && ( unlink $db_file );

1;
