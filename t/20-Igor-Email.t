#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use Carp;
use Email::Sender::Failure;
use English qw{-no_match_vars};
use Sub::Override;
use Regexp::Common qw{time};
use t::config;

our $VERSION = 3.009;

my $re_localtime = $RE{time}{strftime}{ -pat => '%a %b  ?%_d %T %Y' };

my $module = q{Igor::Email};


subtest 'Sanity checks' => sub {
    use_ok($module);
    can_ok( $module, qw{ dispatch get_error } );
};


subtest 'Config' => sub {
    my $test;

    lives_ok { $test = $module->new() } q{Constructor doesn't need a config};

    is( ref $test->config(), 'HASH', 'It can make its own' );
    ok( $test->config->{bot_nick}, q{And it's usable} );
};


subtest 'Defaults' => sub {
    my $test = $module->new( config => $CONFIG );

    is( $test->file_name(), $CONFIG->{db_file},         'Correct file name' );
    is( $test->path(),      q{./} . $CONFIG->{db_file}, 'Correct path' );

    ## no critic (RequireExtendedFormatting)
    like(
        $test->subject(),
        qr/Weekly backup $re_localtime/ms,
        'Correct subject'
    );

    ## use critic
    is( $test->addresses(), 'someone@some.where.tld, another@one.to.email',
        'Correct address' );
    is( $test->from(), $CONFIG->{bot_nick}, 'Correct sender' );
    is( $test->content_type(), 'application/x-sqlite3',
        'Correct content type' );
    is( $test->encoding, 'base64', 'Correct encoding' );
};


subtest 'Message creation and sending' => sub {
    my $override = Sub::Override->new(
        'Email::Sender::Simple::send',
        sub {
            return Email::Sender::Failure->throw(
                { message => q{Deliberate failure} } );
        }
    );

    open my $fh, q{>}, $CONFIG->{db_file} or croak $OS_ERROR;
    close $fh or croak $OS_ERROR;

    my $test = $module->new(
        config => $CONFIG,
        path   => $CONFIG->{db_file},
    );

    my $msg;

    lives_ok { $msg = $test->message() } 'Message created ok';

    is( ref $msg, 'Email::MIME', 'Message is what it should be' );


    is( $test->get_error(), undef, 'No error set yet' );
    lives_ok { $test->dispatch() } q{Dispatch method doesn't die};
    is( $test->get_error(), 'Deliberate failure', 'But error is set now' );

    $override->replace( 'Email::Sender::Simple::send', sub { return 1; } );
    ok( $test->dispatch(), 'Send again, mocked for success' );
    is( $test->get_error(), undef, 'Error unset' );
};


subtest 'Subject in constructor' => sub {
    my $test = $module->new( config => $CONFIG, subject => 'This is about...' );

    is( $test->subject(), q{This is about...}, 'Default subject not used' );
};





( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
