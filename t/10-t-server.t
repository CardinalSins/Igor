#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More;# tests => 3;

our $VERSION = 3.009;

# 30/05/2014 - Problems installing POE::Component::Server::IRC.
# That module was last updated in November, 2011. Prospects for a fix look poor!
# Until these are resolved this test is broken. Comment out rather than TODO
#BEGIN {
#    my $module = q{t::server};
#    use_ok($module);
#}

ok(1);

done_testing();
1;
