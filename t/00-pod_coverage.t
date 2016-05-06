#!/usr/bin/env perl
use 5.014;
use warnings;
use Test::More;

our $VERSION = 3.009;

if ( !$ENV{TEST_AUTHOR} ) {
    ## no critic (RequireInterpolationOfMetachars)
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';

    ## use critic
    plan( skip_all => $msg );
}

eval 'use Test::Pod::Coverage 1.08; 1;'    ## no critic (ProhibitStringyEval)
    or do {
    plan skip_all => q{Needs Test::Pod::Coverage 1.08. Skipping.};
    };

# BOLD RED and NORMAL are imported by IRC::Utils
all_pod_coverage_ok( { trustme => [qr/ \A BOLD|RED|NORMAL \Z /msx] } );

1;
