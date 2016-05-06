#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 2;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

my @base = (
    config  => $CONFIG,
    trigger => 'copy',
    nick    => 'copier',
    context => $CONFIG->{channel},
    status  => $CONFIG->{status}->{bop},
);


subtest 'Basic tests' => sub {
    use_ok($module);

    my $test = $module->new( @base, args => q{}, );
    my $expect = [ [ 'notice', 'copier', 'You need to supply two nicks.' ] ];
    is_deeply( $test->response(), $expect, 'Response to no arguments' );

    $test = $module->new( @base, args => 'partial_profile', );
    is_deeply( $test->response(), $expect, 'Response to single argument' );

    $test = $module->new( @base, args => ' xxx bananaboy ', );
    $expect = q{Sorry, I don't have a profile for xxx.};
    is_deeply(
        $test->response(),
        [ [ 'notice', 'copier', $expect ] ],
        'Correct response to unknown source nick'
    );

    $test = $module->new( @base, args => ' mrsturnipbum #() ', );
    $expect = q{The character '#' is not allowed in user nicks.};
    is_deeply(
        $test->response(),
        [ [ 'notice', 'copier', $expect ] ],
        'Correct response to strange target nick'
    );
};


subtest 'Responses' => sub {
    my $test = $module->new( @base, args => ' mrsturnipbum MrTurnipHead ', );

    my $expect = q{MrTurnipHead already has a full profile.};
    is_deeply(
        $test->response(),
        [ [ 'notice', 'copier', $expect ] ],
        'Correct response to full target profile'
    );

    $test = $module->new( @base, args => ' partial_profile xxx ', );
    is_deeply(
        $test->response(),
        [ [ 'notice', 'copier', 'Profile copied.' ] ],
        'Correct response to successful copy'
    );

    my $target = $schema->resultset('Profile')->find('xxx');
    is( $target->age(), '33', 'Target updated' );
    ok( !$target->fanfare(), 'Fanfare not set after copying partial profile' );

    $test = $module->new( @base, args => 'almost_dun partial_Profile' );
    $expect = 'partial_Profile already has an entry for age. Skipping.';
    is_deeply(
        $test->response(),
        [
            [ 'notice', 'copier', $expect ],
            [ 'notice', 'copier', 'Profile copied.' ],
        ],
        'Partial copy successful'
    );

    $target = $schema->resultset('Profile')->find('partial_profile');
    is( $target->sex(), 'a-hem', 'Target updated' );
    ok( !$target->fanfare(), 'Fanfare not set' );


    $target = $schema->resultset('Profile')->find('xxx');
    $target->age(undef);
    $target->update();

    $test = $module->new( @base, args => 'MrTurnipHead xxx', );
    is_deeply(
        $test->response(),
        [
            [ 'voice_user', 'xxx',    q{+} ],
            [ 'notice',     'copier', 'Profile copied.' ],
        ],
        'Include voice response for completed profile'
    );
    $target->discard_changes();
    is( $target->fanfare(), 1, 'Fanfare set' );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
