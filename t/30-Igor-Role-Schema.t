#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;
use Test::Exception;
use DateTime;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Command};

use_ok($module);

my $test;

subtest 'Set up' => sub {
    lives_ok {
        $test = $module->new(
            config  => $CONFIG,
            trigger => 'ogle',
            nick    => 'somebody',
            args    => 'mrTurnIphead',
            context => $CONFIG->{channel},
            status  => $CONFIG->{status}->{bop},
        );
    }
    'Test object ok';

    isa_ok( $test->schema(), 'Igor::Schema' );
};


subtest 'Base table' => sub {
    throws_ok
        { $test->base_table() }
        qr/Table[ ]name[ ]required/msx,
        'Require table name';

    isa_ok( $test->base_table('Ban'), 'DBIx::Class::ResultSet' );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
