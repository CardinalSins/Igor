#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;

our $VERSION = 3.009;

BEGIN {
    my $module = q{t::config};
    use_ok($module);
}

is( ref $CONFIG,        'HASH',         'Right kind of object' );
is( $CONFIG->{channel}, '#my_hang_out', 'Sample value matches' );

1;
