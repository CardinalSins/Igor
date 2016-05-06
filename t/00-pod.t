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

eval 'use Test::Pod 1.45; 1;'    ## no critic (ProhibitStringyEval)
    or do {
    plan skip_all => q{Needs Test::Pod 1.45. Skipping.};
    };

all_pod_files_ok();

1;
