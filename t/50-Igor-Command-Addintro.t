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
    trigger => 'addintro',
    nick    => 'talky',
    args    => q{lots of texty   goodness in here},
    context => '#my_hang_out',
    status  => $CONFIG->{status}->{aop},
);


subtest 'Basic function' => sub {
    my $sanity = $schema->resultset('IntroPool')->find(8);
    ok( !$sanity, 'Row 8 does not exist yet' );

    my $test = $module->new(@base);

    my $report = 'Intro no.: ' . BOLD . 8 . BOLD . ' saved.';
    my $expect = [ [ 'notice', 'talky', $report ] ];

    cmp_deeply( $test->response(), $expect, 'Trigger works - when done right' );

    my $recent = $schema->resultset('IntroPool')->find(8);
    is(
        $recent->content(),
        q{lots of texty goodness in here},
        'Whitespace trimmmed'
    );
};


subtest 'Prune long intros' => sub {
    my $sanity = $schema->resultset('IntroPool')->find(9);
    ok( !$sanity, 'Row 9 does not exist yet' );

    my $too_long   = '0123456789' x 20;
    my $just_right = '0123456789' x 5;

    my $test = $module->new( @base, args => $too_long );
    $test->response();

    my $recent = $schema->resultset('IntroPool')->find(9);
    is( $recent->content(), $just_right, 'Verbiage curtailed' );
};


subtest 'Blank intros are bad too' => sub {
    my $test = $module->new( @base, args => q{    } );

    my $msg = 'Did you mean to add some text for that intro?';
    my $expect = [ [ 'notice', 'talky', $msg ] ];

    cmp_deeply ( $test->response(), $expect, 'Reject blank intros' );
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
