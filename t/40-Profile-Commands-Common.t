#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 6;
use Test::Deep;
use Test::Exception;
use DateTime::Format::Strptime;
use Regexp::Common qw{time};
use IRC::Utils qw{:ALL};
use t::config;
use t::schema;

# Use 50-Igor-Command-Confess.t and 50-Igor-Command-Refine.t to test the
# responses to user input on the assumption that all checks pass.
# Use this file to test the underlying functionality common to all profile
# creation or editing triggers that gets the user to that point.

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

lives_ok { my $init = $module->new(@base) } 'Create basic test object';

# Start at the "deepest" methods and work out.

subtest 'Field length' => sub {
    my $test = $module->new(@base);

    throws_ok
        { $test->field_length() }
        qr/Profile field argument required/ms,
        'Require field name';

    throws_ok
        { $test->field_length('xFvv_rtY') }
        qr/Unknown profile field xFvv_rtY/ms,
        'Require real field name';

    ## no critic (ProhibitMagicNumbers)
    is(
        length $test->field_length( 'age', '123456789 ' x 70 ),
        $test->config->{longest_teaser_field},
        'Cut teaser field to correct length'
    );

    is(
        length $test->field_length( 'fantasy', '123456789 ' x 700 ),
        $test->config->{longest_profile_field},
        'Cut other fields to correct length'
    );
};


subtest 'Write field' => sub {
    my $test = $module->new( @base, args => q{age} );

    throws_ok
        { $test->write_field() }
        qr/Field parameter required/ms,
        'Require field name here too';
};

subtest 'No public profile writing' => sub {
    my $test = $module->new(@base);

    my $expect = [
        [
            'privmsg',
            $CONFIG->{channel},
            q{Oh, don't ruin the surprise, new_boy! Do that in my PM.}
        ]
    ];

    cmp_deeply( $test->write_field('age'), $expect, 'Public laughter ensues' );
};

subtest 'Reject blank profile entries' => sub {
    my $test = $module->new( @base, context => 'privmsg', args => q{} );

    my $expect = [
        'privmsg',
        'new_boy',
        q{C'mon! Any old rubbish is better than a blank entry.}
    ];


    my $response = $test->write_field('age');
    cmp_deeply( $response->[0], $expect, 'Told off for laziness' );
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;

