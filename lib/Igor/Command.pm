package Igor::Command 3.009;

use 5.014;
use Moose;
use MooseX::StrictConstructor;
use Carp;
use Const::Fast;
use IRC::Utils qw{:ALL};
use List::Util qw{min};
use List::MoreUtils qw{ any none uniq };
use Scalar::Util qw{looks_like_number};
use Igor::BanMaker;
use Igor::Config;
use Igor::DB;
use Igor::Mask;
use namespace::autoclean;

const my $CONVERSION_TRIGGER_REGEX => qr/ \A [[:lower:]]2[[:lower:]] \z /imsx;

has [qw/ trigger nick context /] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has args => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    writer   => '_set_args',
    required => 1,
);

has status => ( is => 'ro', isa => 'Int', required => 1, );

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my ($self) = @_;
    return Igor::Config->new->get_config_from_file();
}


with 'Igor::Role::Schema';
with 'Igor::Role::DBTime';

has trigger_methods => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_trigger_methods',
);

sub _build_trigger_methods {
    my ($self) = @_;

    my $package = __PACKAGE__;

    my $trigger_list = {};

    # Symbol table magic.
    no strict 'refs';
    foreach my $name ( keys %{"${package}::"} ) {
        next if not defined &{"${package}::$name"};
        next if $name !~ m/ \A bot_ /msx;
        $trigger_list->{$name}++;
    }

    return $trigger_list;
}


sub first_args {
    my ($self) = @_;

    no warnings 'uninitialized';
    my $args = $self->args() =~ s/ \A \s* //rmsx;

    use warnings;
    return split m/\s+/msx, $args;
}


sub response {
    my ($self) = @_;

    # Check whether the command was meant for a guest bot (if we have one).
    if ( $self->config->{have_guest_bot} ) {
        my @guest_comms = @{ $self->config->{guest_commands} };
        return $self->bot_guest_command()
            if any { $self->trigger() eq lc $_ } @guest_comms;
    }

    # If we don't recognize the trigger use a default method.
    return $self->fallback() if $self->command_unknown();

    # Is the user allowed to call the command in that context - or at all?
    my $reason = $self->access_policy();
    return [ [ 'notice', $self->nick(), $reason ] ] if $reason;

    # Temperature conversion triggers don't have individual 'bot_' methods.
    if ( $self->trigger() =~ $CONVERSION_TRIGGER_REGEX ) {
        my ($number) = $self->first_args();
        $self->_set_args( $self->trigger() . qq{ $number} );
        return $self->bot_convert();
    }

    my $command = q{bot_} . $self->trigger();
    return $self->$command();
}


sub command_unknown {
    my ($self) = @_;

    return 0 if $self->trigger() =~ $CONVERSION_TRIGGER_REGEX;

    my $known   = $self->trigger_methods();
    my $command = q{bot_} . $self->trigger();
    return $known->{$command} ? 0 : 1;
}


# Figure out if the user is allowed use the command in that context.
sub access_policy {
    my ($self) = @_;

    my $source =
        ( lc $self->context() eq lc $self->config->{channel} )
        ? 'public'
        : 'private';

    # Profile editing triggers don't have individual policies.
    # Neither do the conversion triggers.
    my @fields = @{ $self->config->{all_fields} };

    my $trigg =
          ( any { $self->trigger() eq lc $_ } @fields )     ? 'refine'
        : ( $self->trigger() =~ $CONVERSION_TRIGGER_REGEX ) ? 'convert'
        :                                                     $self->trigger();


    croak qq{No $source policy defined for $trigg}
        if !exists $self->config->{policy}->{$trigg}->{$source};

    my $policy = $self->config->{policy}->{$trigg}->{$source};
    my ( $required, $why_not ) = @{$policy};

    return $why_not if $required > $self->status();

    return 0;
}


sub bot_addintro {
    my ($self) = @_;

    my @words = $self->first_args();

    my $no_text = 'Did you mean to add some text for that intro?';
    return [ [ 'notice', $self->nick(), $no_text ] ]  if ! scalar @words;

    my $content = join q{ }, @words;

    # If the content is too long, silently prune it.
    $content = substr $content, 0, $self->config->{longest_intro};

    # We should really check for success here - and at other DB access points.
    my $rs = $self->schema->resultset('IntroPool')->new(
        {
            content  => $content,
            given_by => $self->nick(),
            saved_on => $self->now_time(),
        }
    );
    $rs->insert();

    my $success = 'Intro no.: ' . BOLD . $rs->id() . BOLD . ' saved.';
    my $response = [ [ 'notice', $self->nick(), $success ] ];

    return $response;
}


sub bot_delintro {
    my ($self) = @_;

    my ($intro_id) = $self->first_args();
    $intro_id //= q{};

    my $not_a_number = 'You need to provide the intro id number. Use '
                     . BOLD . '!findintro' . BOLD
                     . ' to get this.';
    return [ [ 'notice', $self->nick(), $not_a_number ] ]
        if $intro_id !~ m/ \A \d+ \Z /amsx;

    my $rs = $self->schema->resultset('IntroPool')->find($intro_id);

    my $not_found = qq{I don't have a saved intro with id $intro_id.};
    return [ [ 'notice', $self->nick(), $not_found ] ] if ! $rs;

    # Again, we should be checking the success of this.
    $rs->delete();

    my $success =
        q{Intro no.: } . BOLD . $intro_id . BOLD . q{ has been deleted.};

    my $response = [ [ 'notice', $self->nick(), $success ] ];

    return $response;
}


sub bot_findintro {
    my ($self) = @_;

    my @terms = $self->first_args();

    my $no_text = 'Did you mean to add something to search for?';
    return [ [ 'notice', $self->nick(), $no_text ] ] if ! scalar @terms;

    my $search_string = join q{ }, @terms;
    $search_string =~ s/\s+//gmsx;

    my $search_re = qr/\Q$search_string\E/imsx;

    # I wish we could use regexes in the search criteria.
    my $rs = $self->schema->resultset('IntroPool')->search(
        {}, { order_by => 'id' }
    );
    my @intros = $rs->all();

    my @matches;
    my $found = 0;
    my $limit = $self->config->{search_result_max};

    foreach my $intro (@intros) {
        last if $found >= $limit;
        my $content = $intro->content() =~ s/\s+//gmrsx;

        if ( $content =~ $search_re ) {
            $found++;
            push @matches, $intro;
        }
    }

    my $none = q{Sorry. I couldn't find any intros matching that text.};
    return [ [ 'notice', $self->nick(), $none ] ] if $found == 0;

    my @response;

    my $full = qq{Output limited to $limit matches. }
             . q{If the intro you're looking for isn't there, }
             . q{try a more specific search};

    if ( $found == $limit ) {
        push @response, [ 'notice', $self->nick(), $full ];
    }

    foreach my $match (@matches) {
        my $when = $self->convert_time( $match->saved_on() );

        my $text = BOLD . 'Id: '        . BOLD . $match->id()
                 . BOLD . ' Saved by: ' . BOLD . $match->given_by()
                 . BOLD . ' Date: '     . BOLD . $when . q{ - }
                 . $match->content();

        push @response, [ 'notice', $self->nick(), $text ];
    }

    return \@response;
}

sub bot_banish {
    my ($self) = @_;

    my ( $mask, $duration, $unit, @reason ) = $self->first_args();
    $duration ||= 1;
    $unit     ||= q{days};
    $unit =~ s/[,.]//msx;

    my $message = join( q{ }, @reason ) || q{No reason given.};
    $message =~ s/([^.])\z/$1./msx;

    my $ban = Igor::BanMaker->new(
        mask     => lc $mask,
        units    => lc $unit,
        duration => $duration,
        reason   => $message,
        config   => $self->config(),
        set_by   => $self->nick(),
    );

    my $ban_ok = $ban->validate();
    return [ [ 'notice', $self->nick(), $ban->error() ] ] if not $ban_ok;

    # Make sure there aren't already bans set against that mask.
    my $rs = $self->schema->resultset('Ban')->search(
        {
            mask    => lc $ban->mask(),
            expired => 0,
        },
        { order_by => 'id' },
    );

    my $count = scalar $rs->all();

    if ($count) {
        my $text = qq{There are already $count active bans set on $mask};

        if ( $count == 1 ) {
            $text =~ s/are/is/msx;
            $text =~ s/bans/ban/msx;
        }

        return [ [ 'notice', $self->nick(), $text ] ];
    }

    # The apply method returns a string saying what's happened - either way.
    my $outcome  = $ban->apply();
    my $response = [ [ 'notice', $self->nick(), $outcome ], ['check_bans'] ];

    return $response;
}


sub bot_banlist {
    my ($self) = @_;

    # Check to see if we should include expired bans
    my ($all) = $self->first_args();

    no warnings 'uninitialized';
    ( $all eq 'all' ) || ( $all = 0 );

    use warnings;
    my $condition = $all ? {} : { expired => 0 };

    # Look for bans.
    my @bans =
        $self->schema->resultset('Ban')
        ->search( $condition, { order_by => [qw{ mask id }] } );

    # Bail out if we don't find any.
    return [ [ 'notice', $self->nick(), q{No bans set right now.} ] ]
        if scalar @bans == 0;

    # Format the list nicely.
    my $response = [];
    foreach my $ban (@bans) {

        my $lift = $self->convert_time( $ban->lift_on() );

        my $report = BOLD . ' Mask: '    . BOLD . $ban->mask()
                   . BOLD . ' Expires: ' . BOLD . $lift
                   . BOLD . ' Set by: '  . BOLD . $ban->set_by()
                   . BOLD . ' Reason: '  . BOLD . $ban->reason();

        push @{$response}, [ 'notice', $self->nick(), $report ];
    }

    # Include the local time at the bottom of the report.
    my $time_now = DateTime->now->strftime( $self->config->{timestamp_output} );
    push @{$response}, [ 'notice', $self->nick(), qq{Time now: $time_now} ];

    return $response;
}


sub bot_check {
    my ($self) = @_;

    # Bail silently if we haven't been supplied a nick to check.
    my ($name) = $self->first_args();
    return [] if !$name;

    # Equally, bail if the nick doesn't have a profile anyway.
    my $profile = $self->schema->resultset('Profile')->find( lc $name );
    my $text    = qq{Sorry, I don't have a profile for $name.};
    return [ [ 'notice', $self->nick(), $text ] ] if !$profile;

    my $formatted = $self->convert_time( $profile->last_access() );

    $text = qq{${name}'s profile last accessed $formatted};
    my $response = [ [ 'notice', $self->nick(), $text ] ];

    return $response;
}


sub bot_cite {
    my ($self) = @_;

    # Figure out if the user wants their own quote.
    my $want_own = 0;
    my ($name) = $self->first_args();
    $name ||= $self->nick();
    ( lc $name eq lc $self->nick() ) && ( $want_own = 1 );

    # Does the target even have a profile?
    my $profile = $self->schema->resultset('Profile')->find( lc $name );
    my $text =
        $want_own
        ? q{You need to make a profile first! Use } . BOLD . q{!confess} . BOLD
        : qq{Sorry, $name doesn't have a profile, let alone a quote!.};
    return [ [ 'notice', $self->nick(), $text ] ] if !$profile;

    # If so, does the profile have a quote?
    $text = $want_own
          ?   q{You haven't stored one yet. Fix that with }
            . BOLD . q{!quote <text>} . BOLD
          : qq{Sorry, $name mustn't have felt inspired that day :-(};
    return [ [ 'notice', $self->nick(), $text ] ] if !$profile->quote();

    # Got one - send it back to Igor.
    $text =
        PURPLE . q{Deep thought from } . BOLD . $name . BOLD . q{: } . PURPLE
        . $profile->quote();
    return [ [ 'privmsg', $self->config->{channel}, $text ] ];
}


# This method really just gets people started.
sub bot_confess {
    my ($self) = @_;

    my $response = [];

    # Does they user already have a profile - even a partial one?
    my $rs = $self->schema->resultset('Profile')->find( lc $self->nick() );

    # If not, tell them what's involved.
    $rs || ( $response = $self->start_profile() );

    # Ask them for the first blank part of the profile.
    push @{$response}, $self->next_prompt();

    # If the profile is already complete, row back on that and tell them so.
    if ( ref $response->[0] ne 'ARRAY' ) {
        shift @{$response};

        my $text =
            q{You already have a full profile. Use } . BOLD . q{!refine} . BOLD
            . q{ for the list of commands to modify your profile.};

        push @{$response}, [ 'privmsg', $self->nick(), $text ];

        $rs->stamp();
    }

    return $response;
}


sub start_profile {
    my ($self) = @_;

    my $response = [];

    my @start_text = (
        q{Hurray! You want to make a new profile!},
        q{There are } . scalar @{ $self->config->{all_fields} }
            . q{ short questions to answer, so let's go...},
        q{The commands must be entered here in } . $self->config->{bot_nick}
            . q{'s pm.},
    );

    foreach my $t (@start_text) {
        push @{$response}, [ 'privmsg', $self->nick(), $t ];
    }

    return $response;
}


sub next_prompt {
    my ($self) = @_;

    my $profile = $self->schema->resultset('Profile')->find_or_create(
        { nick => lc $self->nick() }
    );

    my $field = $profile->first_blank_field();

    # Bail out if the profile is complete.
    return if !defined $field;

    my $text = $self->config->{prompts}->{$field}
             . BOLD . qq{!$field} . BOLD . q{ - e.g. }
             . $self->config->{examples}->{$field};

    return [ 'privmsg', $self->nick(), $text ];
}


sub write_field {
    my ( $self, $field ) = @_;
    croak 'Field parameter required' if !defined $field;

    # Only accept input in private.
    if ( $self->context() eq $self->config->{channel} ) {

        my $text = q{Oh, don't ruin the surprise, } . $self->nick()
            . q{! Do that in my PM.};

        return [ [ 'privmsg', $self->config->{channel}, $text ] ];
    }

    # Get the profile (so far).
    my $profile = $self->schema->resultset('Profile')->find_or_create(
        { nick => lc $self->nick() }
    );

    # Prune the input, if need be, to the allowed length.
    my $content = $self->field_length( $field, $self->args() );

    # Write it - if it's not blank.
    my $reply;
    if ( length $content ) {
        $profile->$field($content);
        $profile->update();

        # Let the guest know we got it...
        $reply = qq{$field: entry saved.};
    }
    else {
        $reply = q{C'mon! Any old rubbish is better than a blank entry.};
    }

    # If the user was just tweaking an existing profile, we're done.
    my $response = [ [ 'privmsg', $self->nick(), $reply ] ];

    # Then check if that update has now completed the profile.
    if ( $profile->is_complete() ) {

        if ( !$profile->fanfare() ) {

            my $text = q{Kill the fatted calf! }
                . BOLD . PURPLE . $self->nick() . NORMAL
                . q{ has made a new profile for us!};

            push @{$response}, [ 'privmsg', $self->config->{channel}, $text ];
            push @{$response}, [ 'voice_user', $self->nick(), q{+} ];

            # Only do the fanfare once.
            $profile->fanfare(1);
            $profile->update();
        }
    }

    # Ask them the next question - if there is one - it may be optional.
    my $next_prompt = $self->next_prompt();

    if ( ref $next_prompt eq 'ARRAY' ) {
        push @{$response}, $next_prompt;
    }

    return $response;
}


sub field_length {
    my ( $self, $field, $content ) = @_;

    croak 'Profile field argument required' if !$field;
    croak qq{Unknown profile field $field}
        if !any { $_ eq lc $field } @{ $self->config->{all_fields} };

    my $pruned_text =
          ( any { $_ eq lc $field } @{ $self->config->{teaser_fields} } )
        ? ( substr $content, 0, $self->config->{longest_teaser_field} )
        : ( substr $content, 0, $self->config->{longest_profile_field} );

    return $pruned_text;
}


# These method names break the configurability of Igor. We should generate them
# dynamically.
sub bot_age     { my ($self) = @_; return $self->write_field('age'); }
sub bot_sex     { my ($self) = @_; return $self->write_field('sex'); }
sub bot_loc     { my ($self) = @_; return $self->write_field('loc'); }
sub bot_bdsm    { my ($self) = @_; return $self->write_field('bdsm'); }
sub bot_desc    { my ($self) = @_; return $self->write_field('desc'); }
sub bot_limits  { my ($self) = @_; return $self->write_field('limits'); }
sub bot_kinks   { my ($self) = @_; return $self->write_field('kinks'); }
sub bot_fantasy { my ($self) = @_; return $self->write_field('fantasy'); }
sub bot_quote   { my ($self) = @_; return $self->write_field('quote'); }
sub bot_intro   { my ($self) = @_; return $self->write_field('intro'); }


# This hash holds the details we need to convert temperatures, in the form:
#
# conversion =>
#   [ min_input, min_output, factor, offset, in_units, out_units]
#
# 'conversion' is the code for the conversion to run - named using the units of
# the two temperature scales.
#
# 'min_input' and 'min_output' are absolute zero in the two scales.
#
# All the conversions are of the form ax + b. 'factor' and 'offset' are a and b
# respectively.
#
# 'in_units' and 'out_units' are the symbols used in the two temperature
# scales.
#
# It would probably be simpler to convert everything to Kelvin and then back
# out to the desired scale. Especially if you add any more. An advantage of
# this method is we can use the keys of %FORMULA to keep track of what we know
# how to do.
#
# Don't use Const::Fast here - it breaks when we try to look up keys that
# don't exist.
#
## no critic (ProhibitMagicNumbers)
#<<<
my %FORMULA = (
    c2f => [ -273.15, -459.67, 1.8,   32,            '°C', '°F', ],
    f2c => [ -459.67, -273.15, 5/9,  (5/9) * -32,    '°F', '°C', ],
    c2k => [ -273.15,    0,    1,    273.15,         '°C',  'K', ],
    k2c => [    0,    -273.15, 1,   -273.15,          'K', '°C', ],
    f2k => [ -459.67,    0,    5/9,  (5/9) * 459.67, '°F',  'K', ],
    k2f => [    0,    -459.67, 1.8, -459.67,          'K', '°F', ],
    r2k => [    0,       0,    5/9,    0,            '°R',  'K', ],
    k2r => [    0,       0,    1.8,    0,             'K', '°R', ],
    r2c => [    0,    -273.15, 5/9, (5/9) * -491.67, '°R', '°C', ],
    c2r => [ -273.15,    0,    1.8,  1.8 * 273.15,   '°C', '°R', ],
    r2f => [    0,    -459.67, 1,   -459.67,         '°R', '°F', ],
    f2r => [ -459.67,    0,    1,    459.67,         '°F', '°R', ],
);

#>>>
## use critic
sub _convert {
    my ( $conversion, $number ) = @_;

    # Get the details we need for the particular conversion.
    my ( $min_in, $min_out, $factor, $offset, $in_units, $out_units ) =
        @{ $FORMULA{$conversion} };

    # If the input is less than or equal to absolute zero, we're already done.
    return $number . qq{$in_units = $min_out} . $out_units
        if $number <= $min_in;

    # Otherwise do the conversion.
    my $out = ( $number * $factor ) + $offset;

    return sprintf q{%s%s = %0.f%s}, $number, $in_units, $out, $out_units;
}

sub bot_convert {
    my ($self) = @_;
    my ( $conversion, $number ) = $self->first_args();

    # Make sure we recognise the conversion.
    my $text = q{Sorry, I don't know how to do that conversion.};
    return [ [ 'notice', $self->nick(), $text ] ]
        if !defined $FORMULA{$conversion};

    # Don't try to convert, e.g., banana°C to Kelvin.
    $text = qq{My tiny robotic brain doesn't recognise '$number' as a number.};
    return [ [ 'notice', $self->nick(), $text ] ]
        if !looks_like_number($number);

    # If the number is ridiculously large, just bail out.
    $text = qq{$number is f'ing HOT in any scale!!! Pack sunblock.};
    return [ [ 'notice', $self->nick(), $text ] ]
        if $number > $self->config->{max_temp};

    # Just get on with it.
    $text = _convert( $conversion, $number );
    return [ [ 'privmsg', $self->config->{channel}, $text ] ];
}


sub bot_copy {
    my ($self) = @_;

    # Insist on getting two nicks.
    my ( $from, $to ) = $self->first_args();
    my $text = q{You need to supply two nicks.};
    return [ [ 'notice', $self->nick(), $text ] ]
        if ( !defined $from ) || ( !defined $to );

    # Make sure the source profile exists.
    my $from_profile = $self->db_profile($from);
    return $self->no_profile_response($from) if !$from_profile;

    # Check that $to is a legal string for nicks.
    # How can we get Igor::Types to do this?
    if ( $to =~ m/([^[:alnum:]{}[\]`|_^-])/msx ) {
        my $illegal = $1;
        $text = qq{The character '$illegal' is not allowed in user nicks.};
        return [ [ 'notice', $self->nick(), $text ] ];
    }

    # Don't allow an existing profile to be overwritten.
    my $to_profile =
        $self->schema->resultset('Profile')->find_or_new( { nick => lc $to } );
    return [ [ 'notice', $self->nick(), qq{$to already has a full profile.} ] ]
        if $to_profile->is_complete();

    # It's ok to fill in the blanks in a partial profile though.
    my $response = [];
    foreach my $field ( @{ $self->config->{all_fields} } ) {

        # We don't like blanks fields in profiles.
        # Technically, this will also ignore '0' entries.
        next if !$from_profile->$field();

        # Let the user know about fields that are not being over-written.
        if ( $to_profile->$field() ) {
            push @{$response},
                [
                'notice', $self->nick(),
                qq{$to already has an entry for $field. Skipping.}
                ];
            next;
        }
        $to_profile->$field( $from_profile->$field() );
    }
    $to_profile->in_storage() ? $to_profile->update() : $to_profile->insert();

    # Don't have a fanfare for completing a profile this way. But do voice the
    # target nick. Don't worry whether they're in channel or not. Igor will
    # take care of that.
    if ( $to_profile->is_complete() ) {
        $to_profile->fanfare(1);
        push @{$response}, [ 'voice_user', $to, q{+} ];
    }

    # Write to the database, then let the user know it's done.
    $to_profile->update();
    push @{$response}, [ 'notice', $self->nick(), 'Profile copied.' ];

    return $response;
}


sub bot_db_backup {
    my ($self) = @_;

    my $response;

    # Are we in deputy mode?
    $response = q{Backups disabled while } . $self->config->{bot_nick}
        . q{ is standing in for } . $self->config->{real_bot} . q{.};
    return [ [ 'notice', $self->nick(), $response ] ] if $ENV{IGOR_DEPUTY};

    # If we can't email, then bail now.
    $response = q{No access to sendmail on this host.};
    return [ [ 'notice', $self->nick(), $response ] ]
        if !$self->have_sendmail();

    # Pass the nick back so that they can be informed of success/failure.
    return [ [ 'backup_db', $self->nick() ] ];
}


sub have_sendmail {
    return readpipe(q{which sendmail}) ? 1 : 0;
}


sub bot_e {
    my ($self) = @_;

    my $chan = $self->config->{channel};
    my $annoyed = q{ACTION looks at } . $self->nick() . q{ stonily...};

    return [ [ 'ctcp', $chan, $annoyed ] ] if lc $self->context() eq lc $chan;

    my $text = $self->args();

    # Don't bother with empty commands like "/me   ".
    return if $text =~ m{ \A (?: /me )? \s* \z }imsx;

    my $means = q{privmsg};

    # Actions are carried out via ctcp. True story.
    if ( $text =~ s{ \A /me \s+ }{ACTION }imsx ) {
        $means = q{ctcp};
    }

    return [ [ $means, $chan, $text ] ];
}


sub bot_edit {
    my ($self) = @_;

    my ( $target, $field, @rest ) = $self->first_args();

    # Just silently return if there are no arguments.
    return if !$target || !$field;

    # Make sure the target has a profile.
    my $profile = $self->db_profile($target);
    return $self->no_profile_response($target) if !$profile;

    # Reject spurious field names.
    my $text = qq{There's no $field field in the profiles.};
    return [ [ 'notice', $self->nick(), $text ] ]
        if not any { $_ eq lc $field } @{ $self->config->{all_fields} };

    # Prune the length of the new entry, if necessary. If there is no new entry
    # text, use undef and set the entry to NULL. As only ops/admin will use
    # this we do allow blanks fields here.
    my $entry = $self->field_length( lc $field, qq{@rest} ) || undef;

    # Write it to the database. If a field has been deleted, give the owner of
    # the changed nick a shot at a whole new fanfare. Also (de)voice
    # appropriately.
    my @response = ( [ 'notice', $self->nick(), 'Profile altered.' ] );

    $profile->$field($entry);
    if ( $profile->is_complete() ) {
        $profile->fanfare(1);
        push @response, [ 'voice_user', $target, q{+} ];
    }
    else {
        $profile->fanfare(0);
        push @response, [ 'voice_user', $target, q{-} ];
    }
    $profile->update();

    return \@response;
}


sub bot_erase {
    my ($self) = @_;

    my ($target) = $self->first_args();

    # Return silently if no target nick was given.
    return if !$target;

    # Make sure the target has a profile.
    my $profile = $self->db_profile($target);
    return $self->no_profile_response($target) if !$profile;

    $profile->delete();

    return [
        [ 'notice',     $self->nick(), 'Profile erased.' ],
        [ 'voice_user', $target,       q{-} ],
    ];
}


sub bot_forgive {
    my ($self) = @_;

    my ($text) = $self->first_args();
    my $error_msg = q{Did you forget the ban mask?};
    return [ [ 'notice', $self->nick(), $error_msg ], ] if not defined $text;

    my $mask = Igor::Mask->new( input => $text );
    my $ok = $mask->validate();

    if ( not $ok ) {
        $error_msg = q{That's an unforgivable mask! } . $mask->error();
        return [ [ 'notice', $self->nick(), $error_msg ] ];
    }

    my $rs = $self->schema->resultset('Ban')->search(
        { mask => lc $mask->good_mask() },
        { order_by => 'id' }
    );
    $error_msg = qq{I don't have a ban for $text};
    return [ [ 'notice', $self->nick(), $error_msg ], ] if not $rs->count();

    my ( @response, @bans_to_unset );
    while ( my $ban = $rs->next() ) {
        my $msg;

        my $own_ban = lc $ban->set_by() eq lc $self->nick();
        my $can_override = $self->status() >= $self->config->{status}->{owner};

        my $lift = $self->convert_time( $ban->lift_on() );

        # If both are true, prefer the $own_ban text.
        $can_override && ( $msg = q{Deleted ban set by } . $ban->set_by() );
        $own_ban && ( $msg = q{Deleted your ban set to expire on } . $lift );

        if ( $own_ban || $can_override ) {
            push @response, [ 'notice', $self->nick(), $msg ];
            push @bans_to_unset, $ban->mask();
            $ban->delete();
            next;
        }

        $msg = q{Cannot delete ban set by } . $ban->set_by();
        push @response, [ 'notice', $self->nick(), $msg ];
    }

    foreach my $b ( uniq @bans_to_unset) {
        push @response, [ 'apply_ban_to_channel', $b, q{-} ];
    }

    return \@response;
}


sub bot_fortune {
    my ($self) = @_;

    # Bail out early if we don't have a fortune command.
    my $text = q{Sorry, my host doesn't seem to have the fortune command.};
    return [ [ 'privmsg', $self->nick(), $text ] ] if !$self->have_fortune();

    # Get the fortune text.
    my @fortune_lines = $self->get_fortune();
    chomp @fortune_lines;

    # Convert it into a response.
    my $response = [];
    foreach my $i (@fortune_lines) {
        push @{$response}, [ 'privmsg', $self->config->{channel}, $i ];
    }

    return $response;
}


sub have_fortune {
    return readpipe(q{which fortune}) ? 1 : 0;
}


sub get_fortune {
    my ($self) = @_;
    return readpipe q{fortune -san } . $self->config->{longest_fortune};
}


sub bot_guest_command {
    my ($self) = @_;

    my $text = q{Hi, } . $self->nick() . q{, our resident }
             . $self->config->{guest_function} . q{ bot, }
             . $self->config->{guest_bot} . q{, will brb, but until then !}
             . $self->trigger() . q{ doesn't do anything.};

    return [ [ 'privmsg', $self->config->{channel}, $text ] ]
        if $self->context() eq $self->config->{channel};

    return [ [ $self->context(), $self->nick(), $text ] ];
}


sub bot_help {
    my ($self) = @_;

    my ($trigger) = $self->first_args();

    # Put the list of commands to return help for, in here.
    my $help_list;

    # Keep things legible.
    my $shorthand = [ sort keys %{ $self->config->{policy} } ];

    # Look out for some special cases.
    for ($trigger) {

        no warnings 'experimental';    ## no critic (ProhibitNoWarnings)

        # If no specific command is requested return the help for all commands.
        when ( ! defined $_ )                { $help_list = $shorthand; }

        # The conversion commands don't have individual policies.
        when ( defined $FORMULA{ lc $_ } )   { $help_list = [ 'convert' ]; }

        # Neither do the profile field editing commands.
        when ( $self->config->{all_fields} ) { $help_list = [ 'refine' ]; }

        # If we don't recognise the command, return the help for help.
        when ( ! defined $self->trigger_methods->{ 'bot_' . lc $_ } )
                                             { $help_list = [ 'help' ]; }

        # And if get through all that, there's just one, regular, command.
        default { $help_list = [$trigger]; }
    }

    # Prepare the response.
    my $response = [];
    foreach my $command ( @{$help_list} ) {
        my @help = $self->single_help($command);
        next if scalar @help == 0;

        push @{$response}, map { [ 'notice', $self->nick(), $_ ] } @help;
    }

    # If we're listing the works, tag on a little boilerplate
    my $boilerplate =  'Wrought in the smithy of Gil_Gamesh. '
                    .  'Powered by Igor v' . $Igor::Command::VERSION
                    .   '. Finding brains for my Master(s) since 2008.';

    ( scalar @{$help_list} > 1 )
        && ( push @{$response}, [ 'notice', $self->nick(), $boilerplate ] );

    return $response;
}


sub single_help {
    my ( $self, $command ) = @_;

    croak 'Trigger name required' if !$command;

    # Don't explain about the guest bot if we don't have one.
    return if $command eq 'guest_command' && !$self->config->{have_guest_bot};

    # Don't explain about fortune cookies if we can't get any.
    return if $command eq 'fortune' && !$self->have_fortune();

    # Don't explain about backups if we can't get use email.
    return if $command eq 'db_backup' && !$self->have_sendmail();

    # Once is already too often to type this.
    my $shorthand = $self->config->{policy}->{$command};

    # If the user's status is too low for both public and private use of a
    # command then they don't need to see the help for it.
    my $min_status = min(
        $shorthand->{public}->[0],
        $shorthand->{private}->[0]
    );

    return if $min_status > $self->status();

    my $help = $self->config->{policy}->{$command}->{help};
    my @specific;

    # Replace <<nick>> tags in the help text with $self->nick().
    # Other tags were already swapped by Igor::Config
    foreach my $text ( @{$help} ) {
        $text =~ s/<<nick>>/$self->nick()/egmsx;
        push @specific, $text;
    }

    return @specific;
}


sub bot_ogle {
    my ($self) = @_;

    # Insist on a target nick.
    return [ [ 'notice', $self->nick(), q{Ogle who?} ] ] if !$self->args();

    my $name = ( split m/ \s+ /msx, $self->args() )[0];
    return [ [ 'notice', $self->nick(), q{Ogle who?} ] ] if !$name;

    # Make sure the target has a profile.
    my $profile = $self->db_profile($name);
    return $self->no_profile_response($name) if !$profile;

    # Retrieve the profile and format it into a response.
    my $text = $profile->full_profile($name);
    my @output = map { [ 'notice', $self->nick(), $_ ] } @{$text};

    return [@output];
}


sub db_profile {
    my ( $self, $nick ) = @_;
    croak 'Nick argument required' if !defined $nick;
    return $self->schema->resultset('Profile')->find( lc $nick );
}


sub no_profile_response {
    my ( $self, $nick ) = @_;
    croak 'Nick argument required' if !defined $nick;
    my $text = qq{Sorry, I don't have a profile for $nick.};
    return [ [ 'notice', $self->nick(), $text ] ];
}


sub bot_profiles {
    my ($self) = @_;

    my $entries = scalar $self->schema->resultset('Profile')->all();
    my $complete =
        scalar $self->schema->resultset('Profile')->search( { fanfare => 1 } );

    my $text = qq{$entries profiles, $complete complete.};

    return [ [ 'notice', $self->nick(), $text ] ];
}


# Really all we do here is sanitize the args and bounce everything right back.
# But of course it will also pass through the permission vetting in
# $self->response().
sub bot_raw {
    my ($self) = @_;

    # If args are nothing but white-space, this will catch them.
    my ($first_arg) = $self->first_args();
    return [ [ 'notice', $self->nick(), 'No argument supplied.' ] ]
        if not $first_arg;

    return [ [ 'send_raw', $self->nick(), $self->args() ] ];
}


sub bot_refine {
    my ($self) = @_;

    # Make a response telling the user how to edit.
    my $text =
          q{Change a particular entry by pm'ing }
        . $self->config->{bot_nick}
        . q{ with one of these commands...};

    # Add a line for each field.
    my $response = [ [ 'notice', $self->nick(), $text ] ];
    foreach my $i ( @{ $self->config->{all_fields} } ) {
        $text = $self->config->{prompts}->{$i} . BOLD . q{!} . $i . BOLD;

        push @{$response}, [ 'notice', $self->nick(), $text ];
    }

    return $response;
}


sub bot_rules {
    my ($self) = @_;

    # Prepare a response line for each rule.
    my @response =
        map { [ 'notice', $self->nick(), $_ ] } @{ $self->config->{rules} };

    return \@response;
}


sub bot_scram { return [ ['disconnect'] ]; }


sub bot_sweep {
    my ($self) = @_;

    return [
        ['expire_bans'],
        [ 'notice', $self->nick(), 'Sweep for expired bans complete' ],
    ];

}


# These functions break the configurability of Igor. They're closely bound to
# the profile field names.
sub bot_wholikes   { my ($self) = @_; return $self->search_profile('kinks'); }
sub bot_whohates   { my ($self) = @_; return $self->search_profile('limits'); }
sub bot_whowantsto { my ($self) = @_; return $self->search_profile('fantasy'); }
sub bot_whowrote   { my ($self) = @_; return $self->search_profile('desc'); }

sub search_profile {
    my ( $self, $field ) = @_;

    # Make sure we know what we're searching.
    croak q{Field name required as first argument} if !defined $field;
    croak q{Unrecognised field name}
        if $field !~ m/\A kinks | limits | fantasy | desc \Z/msx;

    # Insist on having something to search for.
    my $text = 'My time is valuable, you know.'
        . ' Enter something to actually search for next time.';

    return [ [ 'notice', $self->nick(), $text ] ] if !$self->args();

    # Don't allow any short words in the search.
    my @short = sort { length $a <=> length $b }
        grep { length $_ < $self->config->{shortest_search} }
        $self->first_args();

    if ( scalar @short ) {
        $text = qq{'$short[0]' is too short.}
            . q{ Try searching for something longer - F'nar, F'nar!};

        return [ [ 'notice', $self->nick(), $text ] ];
    }

    # Build the search regexp. Excape metacharacters, it's only a regex in
    # the sense of allowing multiple terms as alternatives.
    # We could allow metacharacters, but the command "!whowrote ************"
    # crashed Igor once. I think it's too problematic to protect against this
    # kind of thing and that allowing the users to build their own regex isn't
    # worth the time. Plus many metacharacters could be used literally in
    # profiles.
    my @terms = map { qq{\Q$_\E} } $self->first_args();
    my $regex = join q{|}, @terms;
    $regex = qr/$regex/imsx;

    # Do the search
    my $matches = $self->look_for( $field, $regex );

    # Bail out early if nothing was found.
    if ( !scalar @{$matches} ) {
        $text = q{Sorry, I didn't find any matches.}
            . q{ I guess you're a special kind of freak...};

        return [ [ 'notice', $self->nick(), $text ] ];
    }


    # Build the report.
    $text = q{I found the following matches to your search. Use }
          . BOLD . q{!ogle <nick>} . BOLD . q{ to see more.};

    my $response = [ [ 'notice', $self->nick(), $text ] ];

    # Don't return too many matches.
    my $limit = $self->config->{search_result_max};
    foreach my $h ( @{$matches} ) {
        last if !$limit;
        $text = BOLD . $h->{nick} . BOLD . qq{: $h->{text}};
        push $response, [ 'notice', $self->nick(), $text ];
        $limit--;
    }

    return $response;
}


sub look_for {
    my ( $self, $field, $regex ) = @_;

    # Check input.
    croak q{Field name required as first argument} if !defined $field;
    croak q{Regex required as second argument} if ref $regex ne 'Regexp';

    croak qq{Unrecognized field name: $field}
        if none { $_ eq $field } @{ $self->config->{all_fields} };

    #Get all profiles with an entry in the field to be searched.
    my $rs = $self->schema->resultset('Profile')->search(
        { $field => { q{!=}, undef } }
    );

    my @result;

    while ( my $profile = $rs->next() ) {
        my @matches = $profile->$field() =~ m/$regex/gimsx;
        next if scalar @matches == 0;

        # Save the details of each match.
        my $detail = {
            nick  => $profile->nick(),
            text  => $profile->$field(),
            score => scalar @matches,
            date  => $profile->last_access(),
        };
        push @result, $detail;
    }

    # Rank the results - highest score, most recently accessed.
    my @ordered = sort_by_score_then_date(@result);

    return \@ordered;
}


# PBP doesn't like 'return sort @input'.
sub sort_by_score_then_date {
    my @input  = @_;
    my @output = sort _by_score_then_date @input;
    return @output;
}


# Do it this way so that we can test the sorting in isolation. Remember $a, $b
# are package variables, and are lost if tests use this directly.
sub _by_score_then_date {
    return ( $b->{score} <=> $a->{score} ) || ( $b->{date} cmp $a->{date} );
}


sub bot_url {
    my ($self) = @_;

    return [ [ 'notice', $self->nick(), $self->config->{forum_url} ] ];
}


sub fallback {
    my ($self) = @_;

    my $text = q{!} . $self->trigger()
             . q{?!? I don't know what you're on about, } . $self->nick()
             . q{. Try } . BOLD . q{!help} . BOLD;

    my $response = [ 'notice', $self->nick(), $text ];

    return [$response];
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Igor::Command - respond to user commands

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Command;

    my $command = Igor::Command->new(
        trigger => $trigger,
        args    => $args,
        nick    => $nick,
        context => $context,
    );

    my $response = $command->response();

=head1 DESCRIPTION

Channel guests can send commands to Igor in channel or via notice or private
message. These consist of a trigger - the particular command to execute - and
zero or more arguments.

This module looks at the nick of the guest that issued the command, the
context it was issued in (in channel, notice, etc.), whether the guest is a
channel op, the command arguments and other factors and produces an appropriate
response.

Most responses will be something for the bot to say, either in channel or in
private to the person who issued the command, but some responses will be an
instruction for the bot to do something. Also, in some cases, there can be
several responses to a command.

To any given command an array ref holding one or more responses is returned. The
responses are themselves three-member array refs contained within that outer
array ref.

The first element of those inner references is the medium for what the bot is to
say, the second element is who to say it to (which can be the channel for public
things) and the third element is what to say.

In the case of instructions to the bot, the first element is the name of the
Igor.pm method to call and any other elements are arguments to that method.

It is possible to mix things to say and instructions within the outer array ref
in any order.

All the methods in this class that have names that begin with 'bot_' handle the
actual command (which makes up the rest of the method name). The other methods
are helpers, called by the 'bot_' methods.

=head1 ACCESSORS

=head2 trigger

Required, read-only. The command that was issued.

=head2 nick

Required, read-only. The nickname of the user that issued the command.

=head2 args

Required (but may be undef) read-only. The arguments to the command.

=head2 context

Required, read-only. Where the command was issued from. Either the channel name
or one of 'notice' or 'privmsg'.

=head2 config

Required, read-only. A hashref holding various configuration parameters. We
could create a new instance of Igor::Config but this way protects against
changes between launching the bot (which might run for weeks) and it calling
this class.

=head2 status

Required, read-only. An integer giving the status of the nick issuing the
the command. The higher the integer the higher the status, though the meanings
of the integers (op, bot-admin, voice, present in channel, etc) are coded and
ranked in the config, making it possible to mess around with the heirarchy.
Whether this is advisable is another question.

=head2 trigger_methods

Badly named. This is the list of methods that respond to trigger commands
passed on from IRC users by the main script. There are more methods involved
but these are the ones named after the triggers. This list is used to keep
track of what legitimate trigger commands are.

=head1 METHODS/SUBROUTINES

=head2 first_args

Sometimes we only want the first one or two words of the command argument, and
will ignore any others. This method splits the args attribute on white space
and returns the "words" as a list, without changing their order.

=head2 response

The response to any command is an array reference that itself consists of one
or more three-member array references. The inner array references consist of
the method to use in replying (privmsg, notice or ctcp) the target of the reply
(channel name, or nick) and the content of the reply.

If the response is an instruction to the bot, the first member is the method
name to use and the others are arguments to that method.

If we have a guest bot consider adding a response to its triggers too.

A response is returned even if the trigger command is unrecognised.

=head2 command_unknown

Returns a false value if the trigger attribute is for a recognised command, or
a true value otherwise.

=head2 access_policy

Determine whether the user has permission to access the particular command under
the context used. Returns false if they can, and the reason why not otherwise.

=head2 bot_addintro

Write a supplied intro text to the intro_pool table.

=head2 bot_delintro

Delete an entry from the intro_pool table that matches the supplied id number.

=head2 bot_findintro

Find the top 5 (or whatever the configuration entry search_result_max says)
entries that match the supplied string.

Whitespace is ignored and metachars are escaped.

=head2 bot_banish

Write a ban to the database. Bans are validated by L<Igor::BanMaker|Igor::BanMaker> and
details are explained in the documentation of that class.

If no time period or units are specified this method defaults to one day.

If there is already one or more active bans on the mask, include that
information in the response.

Also instruct the bot to enforce the ban in channel.

=head2 bot_banlist

Show the list of current bans.

Include the mask used, when it expires, who set it and the reason given for
each one. Also add the  bot's local time in UTC so that users can convert to
their local time zone.

If it gets the argument 'all' it will also show expired bans. This can be
useful for re-setting bans, or as reminders to who caused trouble before.

=head2 bot_check

Find the last access date for a profile. This is the last time the profile was
changed, used to announce the owner's entry into channel or read by another
user.

=head2 bot_cite

Prints a quote stored by the supplied user nick. If no nick is supplied it
looks for a quote stored by the command issuer.

=head2 bot_confess

Handle the confess command - which could be issued by someone who already has
a full profile. If they have, it points them at the profile editing commands.
If they have a partial profile it prompts them for the next missing field. If
they have no profile at all, it starts them off.

Profile writing is a chained process, when the guest writes a field, the module
looks for the next blank field (which is the first field if the guest has no
profile) and responds with the appropriate prompt.

=head2 start_profile

If the guest is starting a profile from scratch an additional bit of text,
showing them how it's done, is prefixed to the prompt.

=head2 next_prompt

Look for the first profile field that has not been filled and build the
appropriate prompt. Return undef if the profile is complete.

=head2 write_field

Write a profile field to the database.

Mock the guest if they use the command in public. Also, don't permit blank
entries. Otherwise let them know their entry was saved and send them the prompt
for the next field. If the profile is too long, silently prune it.

If the entry completes the profile make a fuss in channel and give the user
voice. But still ask them for input to optional fields if any are blank.

The optional fields aren't anything to do with the profile really, it's just
convenient to store them there and provide the ops/admin with the same methods
to delete and alter them.

=head2 field_length

Trim the input for a profile field to the longest permissible length. This is
shorter for teaser fields.

=head2 bot_age

Call the write_field method for the age field.

=head2 bot_sex

Call the write_field method for the sex field.

=head2 bot_loc

Call the write_field method for the loc field.

=head2 bot_bdsm

Call the write_field method for the bdsm field.

=head2 bot_desc

Call the write_field method for the description field.

=head2 bot_limits

Call the write_field method for the limits field.

=head2 bot_kinks

Call the write_field method for the kinks field.

=head2 bot_fantasy

Call the write_field method for the fantasy field.

=head2 bot_quote

Call the write_field method for the quote field.

=head2 bot_intro

Call the write_field method for the intro field.

=head2 bot_convert

Perform temperature conversions. Do some input checking first. Don't convert
below absolute zero, or above some configurable upper limit.

=head2 bot_copy

Copy a profile from one nick to another. This should probably be restricted in
the configuration to ops but that's up to the config.

Don't allow existing profiles to be over-written, or new profiles to be
created for nicks that wouldn't otherwise be allowed. Do allow gaps in partial
profiles to be filled by copying though.

=head2 bot_db_backup

Backup the database. This just checks that we're not a stand-in or a testing
copy, and that the host has sendmail, and then sends the command back for
implementation by the main script, along with the arguments it was passed

=head2 have_sendmail

Return TRUE if Igor's host has the sendmail command.

=head2 bot_e

Parrot the arguments in channel. If the first word is '/me', do an ACTION.
Ignore commands with no arguments - i.e. nothing to say or do.

If the command is issued in channel, which kind of defeats the purpose, provide
a pointed response - regardless of config settings.

=head2 bot_edit

Change a profile entry - for channel staff but that's up to the config. Giving
no new value for the field wipes it - sets it to NULL.

Channel guests can edit their own profile with the bot_refine method (!refine
command).

=head2 bot_erase

Delete a profile - for channel staff, but it's the config that enforces that
not this class. Tell the bot to remove voice from the target if they're in
channel.

=head2 bot_forgive

Delete a ban from the database. People can only delete bans they themselves
set. Except bot-admins and owners. That's hard-coded, not configurable.

Let the user know whether they were allowed to delete the ban or not.

=head2 bot_fortune

Handle a guest request for a fortune.

=head2 have_fortune

Return TRUE if Igor's host has the fortune command. Limit the length according
to the config.

=head2 get_fortune

Run the fortune command and return the output.

=head2 bot_guest_command

If the guest bot is absent point that out to the user who issued one of its
commands.

=head2 bot_help

Show the list of available commands and their help lines. It only lists
commands that the user is allowed to call.

The method takes one optional argument - the name of one of the bot commands.
If supplied it responds with the help text for that command only.

=head2 single_help

Extract the help text for a given command. Convert any place-marker tags in it
and pass it back as an array (though usually it's only a single text line).

=head2 bot_ogle

Show a user profile.

=head2 db_profile

Retrieve the database profile table row for the supplied nick.

=head2 no_profile_response

Return the response to use when a particular profile has not been found.

=head2 bot_profiles

Report on the number of profiles in the database.

=head2 bot_raw

Execute raw IRC commands. This method just makes sure there is some content to
send as raw commands. The main script takes care of actually sending it.

=head2 bot_refine

Tell the user how to change their own profile. Staff can use bot_edit to change
anyone's.

This method actually just returns a response giving them the individual command
for each field in the profile. Those methods are the same ones used to create
a new profile.

=head2 bot_rules

Show the list of channel rules. These are stored in the config file.

=head2 bot_scram

Handle an order to exit. All this does is send the command straight back to
the main script to be handled there. But the user will be vetted for authority
by the $self->response() method beforehand.

=head2 bot_sweep

Look through the list of stored bans to find any that are still current but
that the lift date has passed on. Set the expired flag to true on any found.

The only point of this is to get ahead of the automatic sweep that is performed
every hour and in fact that's what the method does - is call the same method in
Igor that does the scheduled scan.

For that reason, we can't report back to the user whether any bans were expired
or not.

=head2 bot_wholikes

Looks for profiles that contain particular words in the penchants field.

=head2 bot_whohates

Looks for profiles that contain particular words in the limits field.

=head2 bot_whowantsto

Looks for profiles that contain particular words in the fantasy field.

=head2 bot_whowrote

Looks for profiles that contain particular words in the desc field.

=head2 search_profile

Parse the input, call the 'look_for' method, and format the output for the
above methods.

Only report a limited number of matching profiles - determined by the config.

=head2 look_for

Search profile fields. Takes two arguments, the name of the field to search
and a regex to use in the search.

sqlite3 can't perform regex searches by default, so we retrieve the field we're
to search in from all profiles and take care of the regex ourselves.

Returns a sorted array of hashes. Each hash with the keys nick, text, score and
date, and the corresponding values being the nick from the matching the profile,
the text of the matching field, the score (how many times the regex matched) and
the profile's last_access date.

Sorting is done in decreasing order of score first, then by most recent
last_access date.

=head2 sort_by_score_then_date

Does the sorting for the look_for method.

=head2 bot_url

Show the address of the channel web-page or forum pages.

=head2 fallback

Respond to an unrecognised command.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
