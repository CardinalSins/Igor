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
    require Test::Perl::Critic;
    Test::Perl::Critic->import(
        -severity => 1,
        -exclude  => [qw/ProhibitUnrestrictedNoCritic/],
        -profile  => 't/perlcriticrc',
    );
    1;
} or do {
    plan skip_all => 'Test::Perl::Critic not installed. Skipping.';
};

if ( $ENV{TEST_AUTHOR} == 1 ) {
    all_critic_ok();
}
else {
    all_critic_ok(qw/lib t/);
}

1;
