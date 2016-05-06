#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Exception;
use DateTime;
use t::config;

our $VERSION = 3.009;

my $module = q{Igor::Config};

use_ok($module);

my $test;

subtest 'Set up' => sub {
    lives_ok
        { $test = $module->new( file => 't/data/test.yaml' ) }
        'Test object ok';

    isa_ok( $test, 'Igor::Config' );
};

subtest 'Test merger' => sub {

    ## no critic (ProhibitMagicNumbers)
    my $scalar_1 = { no_problem => 1, blue => 12 };
    my $scalar_2 = { no_problem => 1, blue => 97 };
    my $array_1  = { no_problem => 1, blue => [12] };
    my $array_2  = { no_problem => 1, blue => [97] };
    my $hash_1   = { no_problem => 1, blue => { a => 12 } };
    my $hash_2   = { no_problem => 1, blue => { a => 97 } };

    ## use critic
    my $merge;

    lives_ok
        { $merge = $test->_merge_configs( $scalar_1, $scalar_2 ) }
        'Merge scalars ok';
    is( $merge->{blue} => 97, 'Correct scalar value' );

    lives_ok
        { $merge = $test->_merge_configs( $array_1, $array_2 ) }
        'Merge arrays ok';
    is( $merge->{blue}->[0] => 97, 'Correct array value' );


    lives_ok
        { $merge = $test->_merge_configs( $hash_1, $hash_2 ) }
        'Merge hashes ok';
    is( $merge->{blue}->{a} => 97, 'Correct hash value' );

    dies_ok
        { $test->_merge_configs( $scalar_1, $array_2 ) }
        q{Can't merge array into scalar};

    dies_ok
        { $test->_merge_configs( $scalar_1, $hash_2 ) }
        q{Can't merge hash into scalar};

    dies_ok
        { $test->_merge_configs( $array_1, $scalar_2 ) }
        q{Can't merge scalar into array};

    dies_ok
        { $test->_merge_configs( $array_1, $hash_2 ) }
        q{Can't merge hash into array};

    dies_ok
        { $test->_merge_configs( $hash_1, $scalar_2 ) }
        q{Can't merge scalar into hash};

    dies_ok
        { $test->_merge_configs( $hash_1, $array_2 ) }
        q{Can't merge array into hash};
};

subtest 'File argument' => sub {
    my $conf1 = Igor::Config->new->get_config_from_file();
    my $conf2 = Igor::Config->new->get_config_from_file( 't/data/test.yaml' );

    is( $conf1->{max_temp}, 1_000_000, 'Default file read' );
    is( $conf2->{max_temp},    98_765, 'File argument read' );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
