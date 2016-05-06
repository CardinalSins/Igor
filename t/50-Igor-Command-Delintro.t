#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Deep;
use IRC::Utils qw{:ALL};
use Regexp::Common qw{time};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();
use_ok($module);


my @base = (
    config  => $CONFIG,
    trigger => 'delintro',
    nick    => 'wipey',
    args    => 3,
    context => '#my_hang_out',
    status  => $CONFIG->{status}->{aop},
);


subtest 'Basic function' => sub {
    my $sanity = $schema->resultset('IntroPool')->find(3);
    ok( $sanity, 'Row 3 exists in DB' );

    my $before = scalar $schema->resultset('IntroPool')->all();
    is( $before, 7, 'There are seven entries' );

    my $test = $module->new(@base);

    my $report = 'Intro no.: ' . BOLD . 3 . BOLD . ' has been deleted.';
    my $expect = [ [ 'notice', 'wipey', $report ] ];

    cmp_deeply( $test->response(), $expect, 'Correct confirmation' );

    my $after = scalar $schema->resultset('IntroPool')->all();
    is( $after, 6, 'There are now six entries' );

    my $check = $schema->resultset('IntroPool')->find(3);
    ok( !$check, 'Row 3 no longer exists in DB' );
};


subtest 'No such entry' => sub {
    my $sanity = $schema->resultset('IntroPool')->find(9999);
    ok( !$sanity, 'Row 9999 does not exist in DB' );

    my $test = $module->new( @base, args => 9999 );

    my $report = q{I don't have a saved intro with id 9999.};
    my $expect = [ [ 'notice', 'wipey', $report ] ];

    cmp_deeply( $test->response(), $expect, q{Report find failure} );

};


subtest 'We need a number' => sub {
    my $report = q{You need to provide the intro id number. Use }
                . BOLD . q{!findintro} . BOLD . q{ to get this.};

    my $expect = [ [ 'notice', 'wipey', $report ] ];

    my $test = $module->new( @base, args => q{   } );
    cmp_deeply( $test->response(), $expect, q{Balk at blank argumens} );

    $test = $module->new( @base, args => q{four} );
    cmp_deeply( $test->response(), $expect, q{Balk at text arguments} );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
