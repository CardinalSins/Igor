#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 1;
our $VERSION = 3.009;

my $module = q{Igor::Schema};


subtest 'Sanity checks' => sub {
    use_ok($module);
    can_ok( $module, qw{ load_namespaces connect } );
};

1;
