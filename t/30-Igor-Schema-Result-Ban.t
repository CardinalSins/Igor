#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 2;
use Test::Exception;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Schema::Result::Ban};


subtest 'Sanity checks' => sub {
    use_ok($module);

    can_ok(
        $module,
        qw{ id mask set_on lift_on duration units set_by expired }
    );
};


subtest 'Load config' => sub {
    my $schema = t::schema->new( config => $CONFIG )->schema();

    my $hash_ref = {
        mask    => 'anything',
        lift_on => 'will',
        set_by  => 'do',
        reason  => 'here',
    };
    my $test;

    lives_ok { $test = $schema->resultset('Ban')->new($hash_ref) }
        q{Object creation ok};
    is( $test->config->{max_temp}, 1000000, 'Default config' );

    $test->config($CONFIG);
    is( $test->config->{max_temp}, 98765, 'Config argument' );
};

1;
