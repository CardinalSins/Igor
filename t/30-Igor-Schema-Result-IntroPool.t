#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 2;
use Test::Exception;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Schema::Result::IntroPool};


subtest 'Sanity checks' => sub {
    use_ok($module);

    can_ok( $module, qw{ id given_by saved_on content } );
};


subtest 'Load config' => sub {
    my $schema = t::schema->new( config => $CONFIG )->schema();

    my $hash_ref = {
        given_by => 'SomeOne',
        saved_on => '2012-08-21 14:04:01',
        content  => 'Hilarious text designed to embarass here',
    };
    my $test;

    lives_ok { $test = $schema->resultset('IntroPool')->new($hash_ref) }
        q{Object creation ok};
    is( $test->config->{max_temp}, 1000000, 'Default config' );

    $test->config($CONFIG);
    is( $test->config->{max_temp}, 98765, 'Config argument' );
};

1;
