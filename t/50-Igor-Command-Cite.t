#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 8;
use Test::Deep;
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

my @base = (
    config  => $CONFIG,
    trigger => 'cite',
    status => $CONFIG->{status}->{bop},
    context => '#my_hang_out',
);


my ( $test, $expect, $msg );
use_ok($module);


subtest 'No profile' => sub {
    $test = $module->new( @base, nick => 'yer`man', args => 'noprofileguy' );

    $msg = q{Sorry, noprofileguy doesn't have a profile, let alone a quote!.};
    $expect = [ [ 'notice', 'yer`man', $msg ] ];

    cmp_deeply( $test->response(), $expect, 'They have no profile' );
};


subtest 'No quote' => sub {
    $test = $module->new( @base, nick => 'yer`man', args => 'mrsturnipbum' );

    $msg = q{Sorry, mrsturnipbum mustn't have felt inspired that day :-(};
    $expect = [ [ 'notice', 'yer`man', $msg ] ];

    cmp_deeply( $test->response(), $expect, 'They have no quote' );
};


subtest 'Has quote' => sub {
    $test = $module->new( @base, nick => 'yer`man', args => 'mrturniphead' );

    $msg = PURPLE . q{Deep thought from } . BOLD . 'mrturniphead' . BOLD . q{: }
         . PURPLE . q{That's what she said!};
    $expect = [ [ 'privmsg', '#my_hang_out', $msg ] ];

    cmp_deeply( $test->response(), $expect, 'Found their quote' );
};


subtest 'Own quote no profile' => sub {
    $test = $module->new( @base, nick => 'noprofileguy', args => '' );

    $msg = q{You need to make a profile first! Use }
        . BOLD . q{!confess} . BOLD;
    $expect = [ [ 'notice', 'noprofileguy', $msg ] ];

    cmp_deeply( $test->response(), $expect, 'We have no profile' );
};


subtest 'Own quote has profile no quote' => sub {
    $test = $module->new( @base, nick => 'mrsturnipbum', args => '' );

    $msg = q{You haven't stored one yet. Fix that with }
            . BOLD . q{!quote <text>} . BOLD;
    $expect = [ [ 'notice', 'mrsturnipbum', $msg ] ];

    cmp_deeply( $test->response(), $expect, 'We have a profile, but no quote' );
};


subtest 'Own quote has quote' => sub {
    $test = $module->new( @base, nick => 'mrturniphead', args => '' );

    $msg = PURPLE . q{Deep thought from } . BOLD . 'mrturniphead' . BOLD . q{: }
         . PURPLE . q{That's what she said!};
    $expect = [ [ 'privmsg', '#my_hang_out', $msg ] ];

    cmp_deeply( $test->response(), $expect, 'Found our own quote' );
};


subtest "Explicitly asks for own, doesn't have one" => sub {
    $test = $module->new(
        @base, nick => 'mrsturnipbum', args => 'mrsturnipbum'
    );

    $msg = q{You haven't stored one yet. Fix that with }
            . BOLD . q{!quote <text>} . BOLD;
    $expect = [ [ 'notice', 'mrsturnipbum', $msg ] ];

    cmp_deeply(
        $test->response(), $expect, 'Explicit is the same as implicit'
    );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
