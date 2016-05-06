#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 5;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'erase',
    nick    => 'del_boy',
    context => 'private',
    args    => q{xxx},
    status  => $CONFIG->{status}->{bop},
);

my $test = $module->new( @base, args => q{}, );
is( $test->response(), undef, 'Do nothing without a target nick' );

$test = $module->new( @base, args => q{No_sUch_nick}, );
is_deeply(
    $test->response(),
    [
        [
            'notice', 'del_boy',
            q{Sorry, I don't have a profile for No_sUch_nick.}
        ]
    ],
    q{Can't delete a profile that's not there}
);

$test = $module->new( @base, args => q{almost_dun}, );
is_deeply(
    $test->response(),
    [
        [ 'notice',     'del_boy',    q{Profile erased.} ],
        [ 'voice_user', 'almost_dun', q{-} ],
    ],
    'Correct response to erase command'
);

my $profile = $schema->resultset('Profile')->find('almost_dun');
ok( !$profile, 'Profile deleted' );


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
