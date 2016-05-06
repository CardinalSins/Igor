#!/usr/bin/env perl
use 5.014;
use warnings;

local $ENV{IGOR_TEST} = 1;

use Test::More tests => 25;
use Test::Exception;

our $VERSION = 3.009;


BEGIN {
    my $module = q{Igor::Types};
    use_ok( $module, qw{ BanMask Period ReasonableNum ValidNick } );
}

## no critic (ProhibitMagicNumbers)
ok(  is_ReasonableNum(10),   'Duration is accepted' );
ok( !is_ReasonableNum(-3),   'Negative number rejected' );
ok( !is_ReasonableNum(101),  'Big number rejected' );
ok(  is_ReasonableNum(3.14), 'Floating point number accepted' );

## use critic
ok (  is_Period('days'),       'Days accepted as period' );
ok (  is_Period('weeks'),      'Weeks accepted as period' );
ok (  is_Period('months'),     'Months accepted as period' );
ok (  is_Period('fortnights'), 'Fortnights accepted as period' );
ok (  is_Period('years'),      'Years accepted as period' );
ok ( !is_Period('minutes'),    'Minutes rejected as period' );
ok ( !is_Period('centuries'),  'Centuries rejected as period' );

## no critic (RequireInterpolationOfMetachars)
ok(  is_BanMask('abcdef'),          'Ban mask accepted' );
ok( !is_BanMask('a'),               'Short ban mask rejected' );
ok( !is_BanMask('*!*@*.*'),         'Over-general ban mask rejected' );
ok(  is_BanMask('host.server.tld'), 'Host address accepted as ban mask' );
ok(  is_BanMask('someone!*@some.place.nice'),
    'Full mask accepted as ban mask' );

## use critic
ok(  is_ValidNick('gil_gamesh'), 'Nick accepted' );
ok( !is_ValidNick('gil@gamesh'), 'Rejection is in place' );
ok(  is_ValidNick(q{[]{}-_`|^}), 'Some punctuation is allowed' );
ok( !is_ValidNick(q{}),          'Empty string rejected as nick' );
ok(  is_ValidNick('r'),          'But a short one is allowed' );
ok( !is_ValidNick('gil gamesh'), 'Blank spaces not allowed' );
ok( !is_ValidNick('2gil_gamesh'), 'A leading digit is not allowed' );
ok( !is_ValidNick('ridiculously_long_string_should_be_rejected_I_hope'),
    'Over-long string rejected as nick' );

1;
