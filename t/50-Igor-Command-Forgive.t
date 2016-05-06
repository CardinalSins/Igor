#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 3;
use Test::Deep;
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();

use_ok($module);


my @base = (
    config  => $CONFIG,
    trigger => 'forgive',
    context => $CONFIG->{channel},
);

subtest 'Basic tests' => sub {
    is( scalar $schema->resultset('Ban')->all(), '5', 'Starting bans' );

    my $test = $module->new(
        @base,
        nick   => q{Xtian},
        args   => q{},
        status => $CONFIG->{status}->{sop},
    );

    my $expect = [ [ 'notice', 'Xtian', q{Did you forget the ban mask?} ] ];
    is_deeply( $test->response, $expect, 'No ban mask' );

    $test = $module->new(
        @base,
        nick   => q{Xtian},
        args   => q{***********************},
        status => $CONFIG->{status}->{sop},
    );

    my $msg = q{That's an unforgivable mask! Mask is all wildcards.};
    $expect = [ [ 'notice', 'Xtian', $msg ] ];
    is_deeply( $test->response(), $expect, 'Illegal ban mask' );

    $test = $module->new(
        @base,
        nick   => q{Xtian},
        args   => q{_m*ask_},
        status => $CONFIG->{status}->{sop},
    );

    $expect = [ [ 'notice', 'Xtian', q{I don't have a ban for _m*ask_} ] ];
    is_deeply( $test->response(), $expect, 'Unknown ban mask' );
};

subtest 'Output' => sub {
    my $test = $module->new(
        @base,
        nick   => q{Xtian},
        args   => q{*!upper@*.cynisp.ro},
        status => $CONFIG->{status}->{sop},
    );
    my $expect = [ [ 'notice', 'Xtian', q{Cannot delete ban set by katy} ] ];
    is_deeply( $test->response(), $expect, q{Can't delete another's ban} );

    $test = $module->new(
        @base,
        nick   => q{Katy},
        args   => q{*!upper@*.cynisp.ro},
        status => $CONFIG->{status}->{sop},
    );
    my $text =
        q{Deleted your ban set to expire on 14:14:14, Monday, 28 May, 2012 UTC};
    $expect = [
        [ 'notice', 'Katy', $text ],
        [ 'apply_ban_to_channel', '*!upper@*.cynisp.ro', q{-} ]
    ];
    is_deeply( $test->response(), $expect, q{Can delete own ban} );

    $test = $module->new(
        @base,
        nick   => q{I_am_NOT_katy},
        args   => q{*!zzperky@*.*.ro},
        status => $CONFIG->{status}->{sop},
    );

use Data::Printer;
    $text = 'Deleted your ban set to expire on '
          . '14:41:01, Monday, 23 July, 2012 UTC';
    $expect = [
        [ 'notice', 'I_am_NOT_katy', 'Cannot delete ban set by katy' ],
        [ 'notice', 'I_am_NOT_katy', $text ],
        [ 'apply_ban_to_channel', '*!zzperky@*.ro', q{-} ]
    ];
    is_deeply( $test->response(), $expect, q{Multiple matches. Not botop} );

    ## no critic (RequireInterpolationOfMetachars)
    $test = $module->new(
        @base,
        nick   => q{Gil},
        args   => q{*!*@*.telcom.ua},
        status => $CONFIG->{status}->{bop},
    );

    ## use critic
    $text = 'Deleted your ban set to expire on '
          . '22:41:01, Thursday, 28 May, 3012 UTC';

    $expect = [
        [ 'notice', 'Gil', $text ],
        [ 'notice', 'Gil', 'Deleted ban set by I_am_not_Gil' ],
        [ 'apply_ban_to_channel', '*!*@*.telcom.ua', q{-} ],
    ];
    cmp_deeply( $test->response(), $expect, q{Multiple matches. Is botop} );
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
