#!/usr/bin/env perl
use 5.014;
use warnings;

use Test::More tests => 6;
use Test::Exception;
use Carp;
use DateTime::Format::Strptime;
use IRC::Utils qw{:ALL};

use t::config;
use t::schema;

our $VERSION = 3.009;

my $module = q{Igor::Schema::Result::Profile};
my $schema = t::schema->new( config => $CONFIG )->schema();

my $strp = DateTime::Format::Strptime->new(
    pattern   => $CONFIG->{timestamp_db},
    time_zone => 'UTC',
    on_error  => 'croak',
);

my $test;
subtest 'Sanity checks' => sub {
    use_ok($module);
    can_ok(
        $module,
        qw{
            fantasy limits nick age kinks loc first_blank_field stamp
            last_access fanfare bdsm sex desc teaser_core has_blank_optional
            teaser full_profile quote intro config is_complete
        }
    );

    lives_ok {
        $test = $schema->resultset('Profile')->find( lc 'MrTurnipHead' );
    }
    'Create test object';

    lives_ok {
        $test->last_access('2012-05-28 22:41:01 UTC');
        $test->update();
    }
    'Set up last_access test';
};


my $dt_pre;
subtest 'Basic functions' => sub {
    is( $test->nick(),    'mrturniphead',                'Nick is ok' );
    is( $test->age(),     '23',                          'Age is ok' );
    is( $test->sex(),     'banal',                       'Sex is ok' );
    is( $test->bdsm(),    'Yes please',                  'BDSM is ok' );
    is( $test->loc(),     'None of your business',       'Location is ok' );
    is( $test->kinks(),   'failing tests',               'Kinks is ok' );
    is( $test->limits(),  'denial',                      'Limits is ok' );
    is( $test->fantasy(), 'Big long-ass string of text', 'Fantasy is ok' );
    is( $test->intro(),   q{Heeere's Johnny!},           'Intro is ok' );
    is( $test->quote(),   q{That's what she said!},      'Quote is ok' );
    is( $test->desc(),    'Cool, witty and engaging',    'Desc is ok' );
    is( $test->fanfare(), 1,                             'Fanfare is ok' );
    is( $test->last_access(), '2012-05-28 22:41:01 UTC', 'Last access is ok' );

    lives_ok
        { $dt_pre = $strp->parse_datetime( $test->last_access() ) }
        'Last access time is well formatted';

    ok( $dt_pre < DateTime->now(), 'Clock is set reasonably' );
};


my $tease_dt;
subtest 'Teaser' => sub {

    throws_ok { $test->teaser('MsTurnipHead') } qr/Nick[ ]mismatch/msx,
        'Croak with wrong nick';

    my $core =
        BOLD . PURPLE . q{Age:}      . NORMAL . q{ 23  }
      . BOLD . PURPLE . q{Sex:}      . NORMAL . q{ banal  }
      . BOLD . PURPLE . q{Location:} . NORMAL . q{ None of your business  }
      . BOLD . PURPLE . q{BDSM:}     . NORMAL . q{ Yes please};

    my $expect =
        q{Make way for } . BOLD . PURPLE . q{mRtURniphEad} . NORMAL
      . q{! Here's a taste of their juiciness.  } . $core;

    is( $test->teaser_core(q{mRtURniphEad}),
        $core, 'Core part of teaser matches' );

    is( $test->teaser(q{mRtURniphEad}),
        $expect, 'Teaser, including nick case, matches' );

    lives_ok
        { $tease_dt = $strp->parse_datetime( $test->last_access() ) }
        'Access time is well formatted...';

    ok( $dt_pre < $tease_dt, '   ...and has been updated' );
    sleep 1;
};


my $full_dt;
subtest 'Full profile' => sub {
    throws_ok { $test->teaser('MrTurnipFeet') } qr/Nick[ ]mismatch/msx,
        'Croak with wrong nick';

    my $expect = [
        q{Profile for }
      . BOLD . PURPLE . q{mRtURniphEad} . NORMAL . q{  }
      . BOLD . PURPLE . q{Age:}         . NORMAL . q{ 23  }
      . BOLD . PURPLE . q{Sex:}         . NORMAL . q{ banal  }
      . BOLD . PURPLE . q{Location:}    . NORMAL . q{ None of your business  }
      . BOLD . PURPLE . q{BDSM:}        . NORMAL . q{ Yes please},

      BOLD . PURPLE . q{Limits:}      . NORMAL . q{ denial},
      BOLD . PURPLE . q{Fantasy:}     . NORMAL . q{ Big long-ass string of text},
      BOLD . PURPLE . q{Kinks:}       . NORMAL . q{ failing tests},
      BOLD . PURPLE . q{Description:} . NORMAL . q{ Cool, witty and engaging},
    ];

    is_deeply( $test->full_profile(q{mRtURniphEad}),
        $expect, 'Profile, including nick case, matches' );

    lives_ok
        { $full_dt = $strp->parse_datetime( $test->last_access() ) }
        'Access time is still well formatted...';

    ok( $tease_dt < $full_dt, '   ...and has been updated again' );

    throws_ok
        { $test->full_profile(q{I_am_not_mrturniphead}) }
        qr/Nick[ ]mismatch/msx,
        'Sanity check the cased argument';
};


subtest 'Test completeness' => sub {
    is( $test->first_blank_field(), undef, 'All fields are filled' );
    is( $test->is_complete(),       1,     'So is_complete returns true' );

    lives_ok { $test->limits(undef) } 'Set a field to undef';
    is( $test->first_blank_field(),
        'limits', q{And now it's the first blank field} );
    is( $test->is_complete(), 0, 'And is_complete returns false' );

    dies_ok
        { $test->loc(q{}); $test->update(); }
        q{Don't allow empty strings in the fields};

    lives_ok
        { $test->loc(undef); $test->update(); }
        'Set an earlier field to undef';

    is( $test->first_blank_field(), 'loc', q{It's the new first blank field} );

    lives_ok { $test->age(0); $test->update(); } 'Set the first field to 0';
    is( $test->first_blank_field(), 'loc', q{It's not a blank field} );

    lives_ok
        { $test->age(q{ }); $test->update(); }
        'Set the first field to q{ }';

    is( $test->first_blank_field(), 'loc', q{It's not a blank field} );
};


subtest 'Optional fields' => sub {
    $test = $schema->resultset('Profile')->find( lc 'MrsTurnipBum' );

    ok( !$test->quote(), 'Check that quote field is blank' );
    ok( $test->has_blank_optional(), q{Object knows something's missing} );

    is(
        $test->first_blank_field(0), 'quote', 'Find first blank optional field'
    );
    is( $test->first_blank_field(1), undef, 'But only when told to' );

    $test->quote('place filler');
    $test->update();

    is(
        $test->first_blank_field(0), 'intro',
        q{Don't just return the first optional field found}
    );
};

( -e $CONFIG->{db_file} ) && ( unlink $CONFIG->{db_file} );

1;
