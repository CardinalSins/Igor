#!/usr/bin/env perl
use 5.014;
use warnings;

local $ENV{IGOR_TEST} = 1;

use Test::More tests => 8;
use Test::Exception;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module  = q{Igor::Mask};
my @methods = qw{ good_mask config error input validate };

my $test_schema = t::schema->new( config => $CONFIG )->schema();

my $test;


use_ok($module);
can_ok( $module, @methods );


subtest 'Good mask' => sub {
    lives_ok {
        $test = $module->new( config => $CONFIG, input => 'abcd@efg' )
    }
        'Object creation ok';

    lives_ok { $test->validate() } 'Object validation ok';

    is $test->error(), 0, 'No errors reported';

    is $test->good_mask(), 'abcd@efg', 'Good masks are unaltered';
};


subtest 'Mask is too vague' => sub {
    lives_ok {
        $test = $module->new( config => $CONFIG, input => '**!*@**.*' );
        $test->validate();
    }
        'Create and validate ok';

    is $test->error(), q{Mask is all wildcards.},
        'All wildcards identified';
};


subtest 'Mask has unallowed text' => sub {
    lives_ok {
        $test = $module->new( config => $CONFIG, input => '*!*@cuff-link*' )
    }
        'Object creation ok';

    lives_ok { $test->validate() } 'Object still validates ok';

    is $test->error(), q{You can't have 'cuff-link' in the mask.},
        'Error correctly reported';

    is $test->good_mask(), undef, 'There is no good mask';
};


subtest 'Mask is too vague' => sub {
    lives_ok {
        $test = $module->new( config => $CONFIG, input => '*a*!*@*b*.*' );
        $test->validate();
    }
        'Create and validate ok';

    is $test->error(), q{Mask isn't specific enough.}, 'Vagueness identified';
};


subtest 'Nick-based mask' => sub {
    lives_ok {
        $test = $module->new( config => $CONFIG, input => 'nicklike' );
        $test->validate();
    }
        'Create and validate ok';

    is $test->error(), 0, 'Nick-based input causes no error';
    is $test->good_mask(), 'nicklike!*@*', 'Mask is what is should be';
};


subtest 'Host-based mask' => sub {
    lives_ok {
        $test = $module->new( config => $CONFIG, input => 'mask.like.this' );
        $test->validate();
    }
        'Create and validate ok';

    is $test->error(), 0, 'Address-based input causes no error';
    is $test->good_mask(), '*!*@mask.like.this', 'Mask is what it should be';
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
