#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'edit',
    nick    => 'editor',
    context => 'private',
    args    => q{no_such_nick age 55},
    status  => $CONFIG->{status}->{bop},
);

subtest 'Error checks' => sub {
    my $test = $module->new( @base, args => q{}, );
    is( $test->response(), undef, 'Do nothing without a target nick' );

    $test = $module->new( @base, args => q{mrturniphead}, );
    is( $test->response(), undef, 'Do nothing without a target field' );


    $test = $module->new(@base);
    is_deeply(
        $test->response(),
        [
            [
                'notice', 'editor',
                q{Sorry, I don't have a profile for no_such_nick.}
            ]
        ],
        q{Don't create a new profile via edit}
    );


    $test = $module->new( @base, args => q{mrturniphead splorgle 55}, );
    is_deeply(
        $test->response(),
        [
            [
                'notice', 'editor',
                q{There's no splorgle field in the profiles.}
            ]
        ],
        q{Don't invent a new profile field}
    );

};

subtest 'Voicing' => sub {
    my $db_row = $schema->resultset('Profile')->find('mrturniphead');
    is( $db_row->age(), '23', 'Check test case' );

    my $test = $module->new( @base, args => q{mrturniphead age 55}, );
    is_deeply(
        $test->response(),
        [
            [ 'notice',     'editor',       q{Profile altered.} ],
            [ 'voice_user', 'mrturniphead', q{+} ],
        ],
        q{Correct response for successful edit}
    );

    $db_row->discard_changes();
    is( $db_row->age(), '55', 'Profile updated' );


    $test = $module->new( @base, args => q{mrturniphead age}, );
    is_deeply(
        $test->response(),
        [
            [ 'notice',     'editor',       q{Profile altered.} ],
            [ 'voice_user', 'mrturniphead', q{-} ],
        ],
        q{Correct response for successful deletion}
    );

    $db_row->discard_changes();
    ok( !$db_row->fanfare(), 'No fanfare for incomplete profile' );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
