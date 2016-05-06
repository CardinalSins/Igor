#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 4;
use Test::Deep;
use IRC::Utils qw{:ALL};
use Regexp::Common qw{time};
use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Command};
my $schema = t::schema->new( config => $CONFIG )->schema();
use_ok($module);


my @base = (
    config  => $CONFIG,
    trigger => 'findintro',
    nick    => 'looky',
    args    => undef,
    context => '#my_hang_out',
    status  => $CONFIG->{status}->{aop},
);


subtest 'No search term provided' => sub{
    my $test = $module->new(@base);

    my $msg = 'Did you mean to add something to search for?';
    my $expect = [ [ 'notice', 'looky', $msg ] ];

    cmp_deeply ( $test->response(), $expect, q{Can't search for nothing} );

};


subtest 'Handle metachars and failure' => sub{
    my $test = $module->new( @base, args => '#@#@?[}.[{-_()*&^%$£' );

    my $msg = q{Sorry. I couldn't find any intros matching that text.};
    my $expect = [ [ 'notice', 'looky', $msg ] ];

    cmp_deeply ( $test->response(), $expect, q{Report coming up empty} );

    $test = $module->new(
        @base, args => '^.*\* Look?+ $@  .. ..{4 }  (ab )|[ ab] $  '
    );

    $msg = BOLD . 'Id: '        . BOLD . q{7}
         . BOLD . ' Saved by: ' . BOLD . q{seventh}
         . BOLD . ' Date: '     . BOLD
         . q{23:21:22, Friday, 13 March, 2009 UTC - }
         . q{^.*\*  Look?   + $@  ....{4}  (ab)|[ab] $};

    $expect = [ [ 'notice', 'looky', $msg ] ];

    cmp_deeply ( $test->response(), $expect, q{Not fooled by metachars} );
};


subtest 'Handle success' => sub{
    my $test = $module->new( @base, args => q{I'm a findintro limit test} );

    my $lim = q{Output limited to 3 matches. }
            . q{If the intro you're looking for isn't there, }
            . q{try a more specific search};

    my $id = BOLD . 'Id: '        . BOLD;
    my $by = BOLD . ' Saved by: ' . BOLD;
    my $on = BOLD . ' Date: '     . BOLD;

    my $one   = "${id}1${by}first${on}23:21:22, Saturday, 07 March, 2009 UTC - "
        . q{Yeah, baby, I'm a findintro LIMIT test};
    my $two   = "${id}2${by}second${on}23:21:22, Sunday, 08 March, 2009 UTC - "
        . q{I'm a findintro limit test, that's right};
    my $three = "${id}3${by}third${on}23:21:22, Monday, 09 March, 2009 UTC - "
        . q{I'm a       findintro       limit        test};

    my $whew = [
        [ 'notice', 'looky', $lim ],
        [ 'notice', 'looky', $one ],
        [ 'notice', 'looky', $two ],
        [ 'notice', 'looky', $three ],
    ];

    cmp_deeply ( $test->response(), $whew, q{Report coming up empty} );
};


( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
