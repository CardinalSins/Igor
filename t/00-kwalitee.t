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

eval {
    require Test::Kwalitee;

    # Leave redundant tests out here - e.g. pod, pod_coverage.
    Test::Kwalitee->import();
    1;
} or do {
    plan skip_all => q{Test::Kwalitee not installed. Skipping.};
};

1;
