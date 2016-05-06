#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 7;
use Test::Deep;
use Test::Exception;
use DateTime::Format::Strptime;
use Regexp::Common qw{time};
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

# Use this file to test user responses under various circumstances when editing
# previously completed profiles. Use 50-Igor-Command-Confess.t to test the same
# when creating a new profile and 40-Profile-Commands-Common.t to test the
# mechanics and error-checking that underlie either.

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

use_ok($module);

my @base = (
    config  => $CONFIG,
    trigger => 'confess',
    status  => 1,
    args    => q{irrelevant},
    nick    => 'new_boy',
    context => $CONFIG->{channel},
);

my $init;

lives_ok { $init = $module->new(@base) } 'Create base test object';

subtest 'Write field' => sub {
    throws_ok
        { $init->write_field() }
        qr/Field parameter required/ms,
        'Require field name';
};



subtest 'Help on editing' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        nick    => 'oil_or_sugar',
        trigger => 'refine',
        args    => q{},
    );

    my @expect = (
        q{Change a particular entry by pm'ing tIgor with one of these }
            .q{commands...},
        q{Enter your age with }
            . BOLD . q{!age} . BOLD,
        q{Enter your gender and/or sexual orientation with }
            . BOLD . q{!sex} . BOLD,
        q{Enter your location with }
            . BOLD . q{!loc} . BOLD,
        q{Enter your position on the BDSM spectrum with }
            . BOLD . q{!bdsm} . BOLD,
        q{Tell us some of the things that tick you off with }
            . BOLD . q{!limits} . BOLD,
        q{Tell us about things that scare you with }
            . BOLD . q{!kinks} . BOLD,
        q{Share what makes you hot under the collar with }
            . BOLD . q{!fantasy} . BOLD,
        q{Enter a word picture with }
            . BOLD . q{!desc} . BOLD,
        q{Inspire us with }
            . BOLD . q{!quote} . BOLD,
        q{Impress us with }
            . BOLD . q{!intro} . BOLD,
    );

    my $response = [ map { [ 'notice', 'oil_or_sugar', $_ ] } @expect ];
    is_deeply( $test->response(), $response, 'List editing commands' );
};


# This could happen if an op deleted a field in the profile.
subtest 'Has had fanfare, optional fields done, but profile was not complete' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        nick    => 'oldtimer',
        trigger => 'kinks',
        args    => q{Here's some text},
    );

    my $expect = [ [ 'privmsg', 'oldtimer', 'kinks: entry saved.' ] ];

   cmp_deeply $test->response(), $expect, 'Just confirm update';
};


subtest 'As before but also has an optional fields unfilled' => sub {
    my $test = $module->new(
        config  => $CONFIG,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        nick    => 'oldertimer',
        trigger => 'kinks',
        args    => q{Here's some more text},
    );

    my $prompt = q{Inspire us with } . BOLD . q{!quote} . BOLD
               . q{ - e.g. !quote smart stuff here};

    my $expect = [
        [ 'privmsg', 'oldertimer', 'kinks: entry saved.' ],
        [ 'privmsg', 'oldertimer', $prompt ],
    ];

   cmp_deeply $test->response(), $expect, 'Confirm update and prompt for quote';
};


subtest 'Refine disabled' => sub {
    $CONFIG->{policy}->{refine} = {
        private => [ 99, q{Switched off} ],
        public  => [ 99, q{Not accessible} ],
        help    => [ q{Nothing helpful here} ],
    };

    my $test = $module->new(
        config  => $CONFIG,
        context => 'notice',
        status  => $CONFIG->{status}->{bop},
        nick    => 'cant_doit',
        trigger => 'desc',
        args    => q{},
    );

    is_deeply(
        $test->response(),
        [ [ 'notice', 'cant_doit', 'Switched off' ] ],
        q{Access to editing commands determined by refine policy}
    );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
