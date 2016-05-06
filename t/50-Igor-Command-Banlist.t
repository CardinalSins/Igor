#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 5;
use Test::Deep;
use IRC::Utils qw{:ALL};
use Regexp::Common qw{time};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

# Regexp::Common::time doesn't seem to handle %P properly.
#use DateTime;
#my $now_dt = DateTime->now();
#my $time_now = DateTime->now->strftime( $CONFIG->{timestamp_output} );

my $curr_time = [ 'notice', 'yer`man', ignore() ];


my @expired_expect = (
    [ 'notice', 'yer`man',
          BOLD . ' Mask: '    . BOLD . q{*!*@} . q{*.telcom.ua}
        . BOLD . ' Expires: ' . BOLD . q{22:41:01, Thursday, 28 May, 3012 UTC}
        . BOLD . ' Set by: '  . BOLD . q{Gil}
        . BOLD . ' Reason: '  . BOLD . q{arbitrary whim} ],
    [ 'notice', 'yer`man',
          BOLD . ' Mask: '    . BOLD . q{*!*@} . q{*.telcom.ua}
        . BOLD . ' Expires: ' . BOLD . q{22:41:01, Monday, 28 May, 2012 UTC}
        . BOLD . ' Set by: '  . BOLD . q{I_am_not_Gil}
        . BOLD . ' Reason: '  . BOLD . q{copy_cat} ],
    [ 'notice', 'yer`man',
          BOLD . ' Mask: '    . BOLD . q{*!upper@*.cynisp.ro}
        . BOLD . ' Expires: ' . BOLD . q{14:14:14, Monday, 28 May, 2012 UTC}
        . BOLD . ' Set by: '  . BOLD . q{katy}
        . BOLD . ' Reason: '  . BOLD . q{Rudeness} ],
    [ 'notice', 'yer`man',
          BOLD . ' Mask: '    . BOLD . q{*!zzperky@*.ro}
        . BOLD . ' Expires: ' . BOLD . q{22:41:01, Sunday, 22 July, 2012 UTC}
        . BOLD . ' Set by: '  . BOLD . q{katy}
        . BOLD . ' Reason: '  . BOLD . q{Contractual obligation} ],
);

my @all_expect = @expired_expect;
push @all_expect,
    [ 'notice', 'yer`man',
          BOLD . ' Mask: '    . BOLD . q{*!zzperky@*.ro}
        . BOLD . ' Expires: ' . BOLD . q{14:41:01, Monday, 23 July, 2012 UTC}
        . BOLD . ' Set by: '  . BOLD . q{I_am_not_katy}
        . BOLD . ' Reason: '  . BOLD . q{Boilerplate} ],
    $curr_time;

push @expired_expect, $curr_time;

use_ok($module);


my @base = (
    config  => $CONFIG,
    trigger => 'banlist',
    nick    => 'yer`man',
    args    => undef,
    context => '#my_hang_out',
    status  => $CONFIG->{status}->{bop},
);

my $test = $module->new(@base);

my $response = $test->response();

cmp_deeply( $response, \@expired_expect, 'Default response to banlist' );


my $pattern  = $CONFIG->{timestamp_output};

## no critic (RequireExtendedFormatting)
like(
    $response->[-1][2],
    qr/Time now: $RE{time}{strftime}{-pat => $pattern}/ms,
    'Current time looks about right'
);


$test = $module->new(@base, args => 'all' );
cmp_deeply( $test->response(), \@all_expect, 'Show all bans' );


## use critic
$schema->resultset('Ban')->delete();

$test = $module->new(@base);

is_deeply(
    $test->response(),
    [ [ 'notice', 'yer`man', q{No bans set right now.} ] ],
    'Correct response for empty list'
);


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
