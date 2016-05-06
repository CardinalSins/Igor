package Igor 3.009;

use 5.014;
use Moose;

with 'MooseX::Getopt';

use Carp;
use Const::Fast;
use Cwd;
use DateTime;
use DateTime::Set;
use DateTime::Format::Human::Duration;
use English qw{-no_match_vars};
use IRC::Utils qw{:ALL};
use List::MoreUtils qw{ any firstval };
use POE qw{
    Component::IRC::State
    Component::IRC::Plugin::Connector
    Component::IRC::Plugin::Logger
    Component::IRC::Plugin::NickServID
    Component::Schedule
};

$Carp::Verbose = 1;
const my $LESS_THAN => -1;

has [qw/ devel deputy /] => ( is => 'ro', isa => 'Bool', default => 0, );

sub BUILD {
    my ($self) = @_;

    croak 'Either be a devel test or be a deputy - not both'
        if $self->devel() && $self->deputy();

    local $ENV{IGOR_DEVEL}  = $self->devel();
    local $ENV{IGOR_DEPUTY} = $self->deputy();

    require Igor::Command;
    require Igor::Config;
    require Igor::DB;
    require Igor::Email;

    return;
}


has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

with 'Igor::Role::DBTime';

sub _build_config {
    my ($self) = @_;

    my $conf = Igor::Config->new->get_config_from_file();

    $conf->{ctcp_response}{version} .= qq{ v$Igor::VERSION};

    return $conf;
}


has log_path => (
    is      => 'ro',
    isa     => 'Str',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_log_path',
);

sub _build_log_path {
    my ($self) = @_;
    return getcwd() . q{/} . $self->config->{log_directory};
}


# Try to pass $2 (args) with leading and trailing space already trimmed.
has command_rgx => (
    is      => 'ro',
    isa     => 'RegexpRef',
    traits  => ['NoGetopt'],
    default => sub { return qr/ \A !{1,2} (\S+) \s* (.+)? \s* \z /msx; },
);


# This matches nicks that aren't proper nicks.
has no_nick_rgx => (
    is      => 'ro',
    isa     => 'RegexpRef',
    traits  => ['NoGetopt'],
    default => sub {
        return qr/ \A (?: andchat | guest | cuff | flashcuff ) \d+ \z /imsx;
    },
);


# This matches nicks that are often used when afk
has afk_nick_rgx => (
    is      => 'ro',
    isa     => 'RegexpRef',
    traits  => ['NoGetopt'],
    default => sub { return qr/[|`_-] (?: afk | away| brb | bbiab ) \z /imsx; },
);


has schema => (
    is      => 'ro',
    isa     => 'Igor::Schema',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_schema',
);

sub _build_schema {
    my ($self) = @_;
    return Igor::DB->new( db_file => $self->config->{db_file} )->schema();
}


has 'irc' => (
    is      => 'ro',
    isa     => 'POE::Component::IRC::State',
    traits  => ['NoGetopt'],
    lazy    => 1,
    writer  => 'set_irc',
    clearer => 'clear_irc',
    builder => '_build_irc',
);

sub _build_irc {
    my ($self) = @_;

    say {*STDOUT} 'Spawning...' || carp;

    my $irc = POE::Component::IRC::State->spawn(
        Nick         => $self->config->{bot_nick},
        Server       => $self->config->{server},
        Port         => $self->config->{port},
        Ircname      => $self->config->{ircname},
        Username     => $self->config->{username},
        Raw          => $self->devel(),
        debug        => $self->devel(),              # General debug
        plugin_debug => $self->devel(),              # Plugin debug
    ) or croak "Failed to spawn: $OS_ERROR";

    return $irc;
}


has nsplugin => (
    is      => 'ro',
    isa     => 'POE::Component::IRC::Plugin::NickServID',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_nsplugin',
);

sub _build_nsplugin {
    my ($self) = @_;

    my $plugin = POE::Component::IRC::Plugin::NickServID->new(
        Password => $self->config->{nickserv_password}
    );

    return $plugin;
}


has rcplugin => (
    is      => 'ro',
    isa     => 'POE::Component::IRC::Plugin::Connector',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_rcplugin',
);

sub _build_rcplugin {
    my ($self) = @_;

    my $plugin = POE::Component::IRC::Plugin::Connector->new(
        servers => $self->config->{server_list}
    );

    return $plugin;
}


has logger => (
    is      => 'ro',
    isa     => 'POE::Component::IRC::Plugin::Logger',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_logger',
);

sub _build_logger {
    my ($self) = @_;

    my $plugin = POE::Component::IRC::Plugin::Logger->new(
        Path         => $self->log_path(),
        Private      => 1,
        Public       => 1,
        Sort_by_date => 1,
    );

    return $plugin;
}


has db_backup_recurrence => (
    is      => 'ro',
    isa     => 'DateTime::Set',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_db_backup_recurrence',
);

# This sets the backup to weekly at midnight on Sunday.
sub _build_db_backup_recurrence {
    my ($self) = @_;

    # Takes the previous datetime, does something to it - returns the result.
    # This sets the recurrence to midnight, every Monday, UTC.
    my $db_recurr = sub {
        return $_[0]->truncate( to => 'week' )->add( weeks => 1 );
    };

    # Seed the set with the current time - defaults to UTC.
    my $db_set = DateTime::Set->from_recurrence(
        after      => DateTime->now(),
        recurrence => $db_recurr,
    );

    return $db_set;
}


has ban_expiry_recurrence => (
    is      => 'ro',
    isa     => 'DateTime::Set',
    traits  => ['NoGetopt'],
    lazy    => 1,
    builder => '_build_ban_expiry_recurrence',
);

sub _build_ban_expiry_recurrence {
    my ($self) = @_;

    my $ban_recurr = sub {
        return $_[0]->truncate( to => 'hour' )->add( hours => 1 );
    };

    my $ban_set = DateTime::Set->from_recurrence(
        after      => DateTime->now(),
        recurrence => $ban_recurr,
    );

    return $ban_set;
}


has session => (
    isa      => 'POE::Session',
    is       => 'ro',
    traits   => ['NoGetopt'],
    lazy     => 1,
    required => 1,
    default  => sub {
        my ($self) = @_;
        POE::Session->create(
            object_states => [
                $self => [
                    qw{
                        _default _start irc_001 irc_public irc_msg irc_notice
                        irc_ctcp irc_join irc_nick backup_db expire_bans
                    }
                ],
            ],

            # options => { trace => 1, debug => 1 },
            heap => { irc => $self->irc() },
        );
    },
);


sub run {
    my ($self) = @_;

    $self->devel() && ( $Carp::Verbose = 1 );

    if ( $self->config->{logging} ) {
        croak q{Log path, } . $self->log_path() . q{, not found}
            if !-d $self->log_path();
        $self->irc->plugin_add( 'Logger', $self->logger() );
    }

    $self->irc->plugin_add( 'NickServID', $self->nsplugin() );
    $self->irc->plugin_add( 'Connector',  $self->rcplugin() );

    say {*STDOUT} 'Connecting...' || carp;
    POE::Kernel->post( $self->session() => '_start' );
    POE::Kernel->run();

    return;
}


## no critic (RequireArgUnpacking)
sub _start {    ## no critic (ProhibitUnusedPrivateSubroutines)
    my ( $self, $kernel, $session, $heap ) =
        @_[ OBJECT, KERNEL, SESSION, HEAP ];

    my $irc_session = $heap->{irc}->session_id();

    $kernel->post( $irc_session => register => 'all' );
    $kernel->post( $irc_session => connect  => {} );

    # We could make this conditional on have_sendmail(). The only (weak?)
    # argument for this way is it allows for sendmail to go away and come back.
    $_[HEAP]{db_cron} = POE::Component::Schedule->add(
        $session => backup_db => $self->db_backup_recurrence()
    );

    $_[HEAP]{bans_cron} = POE::Component::Schedule->add(
        $session => expire_bans => $self->ban_expiry_recurrence()
    );

    return;
}


sub irc_001 {
    my ( $self, $kernel, $sender ) = @_[ OBJECT, KERNEL, SENDER ];

    my $poco_object = $sender->get_heap();
    say q{Connected to }, $poco_object->server_name() or croak $OS_ERROR;

    $kernel->post( $sender => join => $self->config->{channel} );

    # Mark the bot as a bot.
    $self->irc->yield( mode => $self->irc->nick_name() => q{+B} );

    $self->irc->yield(
        privmsg => $self->config->{channel} => $self->config->{join_message}
    );

    return;
}


sub irc_public {
    my ( $self, $kernel, $sender, $who, $where, $what ) =
        @_[ OBJECT, KERNEL, SENDER, ARG0 .. ARG2 ];

    my $nick = ( split m/!/msx, $who )[0];
    my $channel = $where->[0];

    if ( my ( $command, $args ) = $what =~ $self->command_rgx() ) {
        $self->process_command( $nick, $channel, $command, $args );
    }

    return;
}


sub irc_notice {
    my ( $self, $kernel, $sender, $from_who, $to_who, $what ) =
        @_[ OBJECT, KERNEL, SENDER, ARG0 .. ARG2 ];

    my $nick = ( split m/!/msx, $from_who )[0];

    if ( my ( $command, $args ) = $what =~ $self->command_rgx() ) {
        $self->process_command( $nick, 'notice', $command, $args );
    }

    return;
}


sub irc_msg {
    my ( $self, $kernel, $sender, $from_who, $to_who, $text ) =
        @_[ OBJECT, KERNEL, SENDER, ARG0 .. ARG3 ];

    my $nick = ( split m/!/msx, $from_who )[0];

    if ( my ( $command, $args ) = $text =~ $self->command_rgx() ) {
        $self->process_command( $nick, 'private', $command, $args );
    }

    return;
}


sub irc_ctcp {
    my ( $self, $command, $nickhost, $to_arrayref, $rest ) =
        @_[ OBJECT, ARG0, ARG1, ARG2, ARG3 ];

    $self->config->{ctcp_response}{time} = localtime;

    $command = lc $command;

    # This gets triggered by /me (ACTION)
    return if !defined $self->config->{ctcp_response}{$command};

    my ($nick) = $nickhost =~ m/ (\S+) [!] (?: \S+ ) [@] (?: \S+ ) /msx;

    $self->irc->yield(
        ctcpreply => $nick => $self->config->{ctcp_response}{$command}
    );

    return;
}


sub irc_join {
    my ( $self, $nickhost ) = @_[ OBJECT, ARG0 ];

    my ($nick) = $nickhost =~ m/ (\S+) [!] \S+ [@] \S+ /msx;

    # Only do stuff to other people! Igor *will* react to his own join.
    if ( lc $nick eq lc $self->irc->nick_name() ) {

        # These don't work - probably issued before Igor gets opped?
        $self->check_bans();
        $self->check_voices();

        return;
    }

    # If we're deputising and the regular guy shows up, then clear out.
    ( lc $nick eq lc $self->config->{real_bot} ) && $self->disconnect();

    # Are they allowed in?
    $self->check_bans();

    # After checking bans, see if the user is still there.
    return if !$self->irc->is_channel_member( $self->config->{channel}, $nick );

    # If it's Guest12345, etc, don't bother with an intro.
    return if $nick =~ $self->no_nick_rgx();

    # If there's a completed profile, +v 'em, otherwise greet them.
    $self->has_full_profile($nick)
        ? $self->voice_user( $nick, q{+} )
        : $self->irc->yield( notice => $nick => $self->config->{greeting} );

    # Announce them.
    $self->announce( $nick, 'join' );

    return;
}


# Someone changed nick - do they have a profile under the new one?
sub irc_nick {
    my ( $self, $nick ) = @_[ OBJECT, ARG1 ];

    # The server won't allow a user to change to a banned nick inside channel.
    # But there might be a mask with a wild card that matches.
    # There could be a ban mask set against the new nick, so check anyway.
    $self->check_bans();

    my $change = $self->has_full_profile($nick) ? q{+} : q{-};
    $self->voice_user( $nick, $change );

    # Announce them.
    $self->announce( $nick, 'change' );

    return;
}


# We registered for all events, this will produce some debug info.
sub _default {    ## no critic (ProhibitUnusedPrivateSubroutines)
    my ( $self, $event, $args ) = @_[ OBJECT, ARG0 .. $#_ ];

    #Important to return 0 (http://poe.perl.org/?POE_Cookbook/IRC_Bot_Debugging)
    return 0 if $self->devel() != 1;

    # This duplicates what the Raw option in POE::Component::IRC::State->spawn()
    # in the _build_irc() method gives us. It's just extra noise, really.

    # my @output = (qq{${event}: });

    # for my $arg ( @{$args} ) {
    #     if ( ref $arg eq 'ARRAY' ) {
    #         push @output, q{[} . join( q{, }, @{$arg} ) . q{]};
    #     }
    #     else {
    #         push @output, qq{'$arg'};
    #    }
    # }

    # my $log = join q{ }, @output;

    # return 0 if $log =~ m/P[IO]NG/imsx;

    # say $log or croak $OS_ERROR;

    return 0;
}


sub announce {
    my ( $self, $nick, $context ) = @_;

    croak 'Nick argument required' if ! $nick;
    croak qq{Unknown context argument: $context}
        if $context !~ m/ \A join | change \z /imsx;

    my $profile     = $self->schema->resultset('Profile')->find( lc $nick );
    my $has_intro   = $profile && $profile->intro();
    my $has_full_profile = $profile && $profile->is_complete();

    # Pick an intro to use.
    my $this_intro = $has_intro
                   ? $profile->intro()
                   : $self->get_random_intro();

    my $has_profile_intro = PURPLE . qq{ -- to see ${nick}'s profile, type }
        . BOLD . qq{!ogle $nick} . NORMAL;

    my $no_profile_intro =
        PURPLE . qq{ -- $nick needs to complete a profile! Make them type }
        . BOLD . q{!confess} . NORMAL;

    # Adjust the intro according to whether there's a profile.
    my $rest = $has_full_profile
             ? $has_profile_intro
             : $no_profile_intro;

    my $intro = qq{$this_intro $rest};

    return if $context eq 'change' && $nick =~ $self->afk_nick_rgx();

    # Announce them.
    $self->irc->yield( privmsg => $self->config->{channel} => $intro );

    return;
}


sub expire_bans {
    my $self = $_[OBJECT];

    my $bans = $self->schema->resultset('Ban')->search( { expired => 0 }, );

    my $now = DateTime->now();

    while ( my $ban = $bans->next() ) {
        my $lift_time = $self->normalise_time( $ban->lift_on() );
        if ( DateTime->compare( $lift_time, $now ) == $LESS_THAN ) {
            $ban->expired(1);
            $ban->update();
        }
    }

    # While we're here, delete expired bans which are very old.
    $bans = $self->schema->resultset('Ban')->search( { expired => 1 }, );
    my $old = $now->subtract( years => 1 );

    while ( my $ban = $bans->next() ) {
        my $lift_time = $self->normalise_time( $ban->lift_on() );
        if ( DateTime->compare( $lift_time, $old ) == $LESS_THAN ) {
            $ban->delete();
        }
    }

    return;
}


sub backup_db {
    my ( $self, $who, $args ) = @_[ OBJECT, ARG0, ARG1 ];

    if ( not have_sendmail() ) {
        return if !$who;    # Means that this is a crontab so silently bail.

        $self->irc->yield(
            'notice', $who, 'No access to sendmail on this host.'
        );

        return;
    }

    # If it's not a crontab say who triggered it in the email header.
    my $subject = $who ? qq{Triggered by $who} : undef;

    # Give some context to any error message we report.
    my $prefix  = $who ? q{Please report this error to my host: }
                       : q{Error encountered sending back-up: };

    # Find someone to report crontab failure to.
    $who ||= $self->find_staff();

    # How well will the error notice work with a blank $who?
    my $message = Igor::Email->new( subject => $subject );
    $message->dispatch()
        || $self->irc->yield( 'notice', $who, $prefix . $message->get_error() );

    return;
}


sub find_staff {
    my ($self) = @_;

    # If the channel list is sorted this will tend to report the same nick.
    my @members = $self->irc->channel_list();

    # Seed the search.
    my $staff = shift @members;
    my $rank  = $self->detail_user($staff)->{status};

    foreach my $guest (@members) {

        # If $staff is a bot-admin, we don't need to look any farther.
        last if $rank == $self->config->{status}->{bop};

        my $status = $self->detail_user($guest)->{status};
        next if $status <= $rank;

        # Found a higher-ranked guest. Keep them!
        $staff = $guest;
        $rank  = $status;

        # If they're a bot-admin, we don't need to look any farther.
        last if $rank == $self->config->{status}->{bop};
    }

    # If no staff are about, a voiced guest will NOT do instead.
    ( $rank < $self->config->{status}->{bop} ) && ( $staff = q{} );

    return $staff;
}

########                                          ########
##                                                      ##
## Subroutines that support the responses to IRC events ##
##                                                      ##
########                                          ########

## use critic
sub handled_by_guest_bot {
    my ( $self, $trigger ) = @_;

    # Do we even have a guest bot?
    return 0 if not $self->config->{guest_bot};

    # If this isn't one of its commands, we're done already.
    my $is_guest_bot_trigger =
        any { lc $trigger eq lc $_ } @{ $self->config->{guest_commands} };

    return 0 if not $is_guest_bot_trigger;

    # Is the guest bot here?
    my $guest_bot_present =
        $self->irc->is_channel_member(
            $self->config->{channel}, $self->config->{guest_bot}
        ) // 0;

    return $guest_bot_present;
}


sub process_command {
    my ( $self, $nick, $context, $trigger, $args ) = @_;
    $args //= q{};

    # Guest12345, etc, shouldn't make profiles. So don't let them do anything.
    return if $nick =~ $self->no_nick_rgx();

    return if $self->handled_by_guest_bot($trigger);

    # Don't allow white-space only args.
    ( $args =~ m/\S/msx ) || ( $args = q{} );

    my $command = Igor::Command->new(
        trigger => lc $trigger,
        args    => $args,
        nick    => $nick,
        status  => $self->detail_user($nick)->{status},
        context => $context,
    );

    my $response = $command->response();
    foreach my $r ( @{$response} ) {
        my ( $method, $target, $content ) = @{$r};

        if ( $method !~ m/\A notice | privmsg | ctcp \z/msx ) {
            $self->$method( $target, $content );
            next;
        }

        $self->irc->yield( $method => $target => $content );
    }

    return;
}


sub check_voices {
    my ($self) = @_;

    foreach my $guest ( $self->irc->channel_list( $self->config->{channel} ) ) {
        my $voice = $self->has_full_profile($guest) ? q{+} : q{-};
        $self->voice_user( $guest, $voice );
    }

    return;
}


sub voice_user {
    my ( $self, $user, $voice ) = @_;

    croak 'No user supplied' if !$user;
    croak 'No +/- argument supplied' if $voice !~ m/\A[+-]\z/msx;

    return
        if !$self->irc->is_channel_member( $self->config->{channel}, $user );

    my $current =
        $self->irc->has_channel_voice( $self->config->{channel}, $user );
    return if $current  && ( $voice eq q{+} );
    return if !$current && ( $voice eq q{-} );

    my $mode = $voice . q{v};
    $self->irc->yield( mode => $self->config->{channel} => $mode => $user );

    return;
}

# Protect this method from direct guest access. If they give it a character
# that's not allowed for nicks, Igor will crash.
sub get_profile {
    my ( $self, $user ) = @_;
    croak 'No user nick supplied' if !defined $user;

    my $profile =
        $self->schema->resultset('Profile')->find( { nick => lc $user } );

    return $profile;
}

sub has_profile {
    my ( $self, $user ) = @_;

    my $profile = $self->get_profile($user);

    return $profile ? 1 : 0;
}

sub has_full_profile {
    my ( $self, $user ) = @_;

    my $profile = $self->get_profile($user);

    return 0 if ! $profile;

    return $profile->is_complete() ? 1 : 0;
}

sub detail_user {
    my ( $self, $user ) = @_;

    my $chan = $self->config->{channel};

    my $detail = {
        botop => $self->config->{bot_admins}{ lc $user } // 0,
        owner => $self->irc->is_channel_owner(    $chan, $user ) // 0,
        sop   => $self->irc->is_channel_operator( $chan, $user ) // 0,
        aop   => $self->irc->is_channel_admin(    $chan, $user ) // 0,
        hop   => $self->irc->is_channel_halfop(   $chan, $user ) // 0,
        voice => $self->irc->has_channel_voice(   $chan, $user ) // 0,
        there => $self->irc->is_channel_member(   $chan, $user ) // 0,
    };

    my @attr = qw/ botop owner sop aop hop voice there /;

    my $rank = scalar @attr;
    foreach my $i (@attr) {
        last if $detail->{$i};
        $rank--;
    }

    $detail->{status} = $rank;

    return $detail;
}


sub get_random_intro {
    my ($self) = @_;

    my @rows = $self->schema->resultset('IntroPool')->all();
    my $pool_size = scalar @rows;

    return q{Hey! Someone write an intro for me!} if !$pool_size;

    my $pick = $rows[ int rand $pool_size ];

    return $pick->content();
}


sub apply_ban_to_channel {
    my ( $self, $mask, $switch ) = @_;

    croak 'No mask supplied' if !$mask;
    croak 'No +/- argument supplied' if $switch !~ m/\A[+-]\z/msx;

    my $mode = $switch . q{b};
    my $chan = $self->config->{channel};

    my $do_this = qq{/mode $chan $mode $mask};

    # If we're testing just announce the ban.
    # We don't bother checking if it's already set - no real need to.
    $self->devel()
        ? $self->irc->yield( privmsg => $chan => qq{I would $do_this} )
        : $self->irc->yield( mode => $chan => $mode => $mask );

    return;
}


sub check_bans {
    my ($self) = @_;

    my @bans = $self->schema->resultset('Ban')->all();

    # If there are no bans, we're done.
    return if not scalar @bans;

    my $chan = $self->config->{channel};

    my $set_bans  = $self->irc->channel_ban_list($chan);
    my @set_masks = keys %{$set_bans};

    foreach my $ban (@bans) {
        my $is_set = any { lc $_ eq lc $ban->mask() } @set_masks;
        $is_set += 0;

        my $expired = $ban->expired() + 0;    # In case of nulls...

        # If it's not set and isn't supposed to be then we're good.
        next if !$is_set && $expired;

        # If it's set and is supposed be, also good, but check for kicks.
        if ( $is_set && !$expired ) {
            $self->enforce_ban($ban);
            next;
        }

        # If it's set and shouldn't be change it.
        if ( $is_set && $expired ) {
            $self->apply_ban_to_channel( $ban->mask(), q{-} );
            next;
        }

        # That only leave bans that are not set but should be.
        $self->apply_ban_to_channel( $ban->mask(), q{+} );

        # Here we also need to look for kicks.
        $self->enforce_ban($ban);
    }

    return;
}


sub enforce_ban {
    my ( $self, $ban ) = @_;

    croak 'Incorrect argument to enforce_ban'
        if ref $ban ne 'Igor::Schema::Result::Ban';

    my $chan = $self->config->{channel};
    my @matched_users = $self->irc->ban_mask( $chan, $ban->mask() );

    my $now  = DateTime->now();
    my $span = DateTime::Format::Human::Duration->new();

    foreach my $user (@matched_users) {

        # Silently move on if the mask hits the bot itself.
        next if $user eq $self->irc->nick_name();

        # Would be good to do the same for channel owners - but we can't
        # protect them when they're -q and they don't need it when they're +q.

        my $diff = $self->normalise_time( $ban->lift_on() ) - $now;

        my $expiry = $span->format_duration(
            $diff,
            precision => 'hours',
            no_time   => 'less than an hour'
        );

        my $text = $ban->reason() . qq{ Expires in $expiry.};

        my $do_this = qq{/kick $user ($text)};

        #If we're testing just announce the kick.
        $self->devel()
            ? $self->irc->yield( privmsg => $chan => qq{I would $do_this} )
            : $self->irc->yield( kick => $chan => $user => $text );
    }

    return;
}


## no critic (ProhibitBacktickOperator)
sub have_sendmail { return qx{which sendmail} ? 1 : 0; }


## use critic
sub send_raw {
    my ( $self, $sender, $rawcommands ) = @_;
    croak 'No raw commands passed to method' if !$rawcommands;

    $self->irc->yield( quote => $rawcommands );

    return;
}


sub disconnect {
    my ($self) = @_;

    $self->irc->yield( unregister => 'all' );

    say 'Orderly shut-down' or carp $OS_ERROR;
    exit;
}


1;
__END__

=head1 NAME

Igor - An IRC profile bot.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor;
    my $igor = Igor->new_with_options();
    $igor->run();

=head1 DESCRIPTION

This class provides all the main functionality of the bot. The code was moved
here from a script to enable testing - though doing that properly requires some
kind of test IRC server and I haven't figured that part out yet.

=head1 ATTRIBUTES

=head2 config

Hash reference holding the various config parameters for the bot.

=head2 log_path

The path to the directory where log files should be written.

=head2 command_rgx

A regular expression used to recognise command triggers.

=head2 no_nick_rgx

A regular expression used to recognise the fallback names the server uses when
someone doesn't have a nickname, or who has failed to identify a registered
nickname. This can be used to handle such users differently - e.g. don't let
them make a user profile.

=head2 afk_nick_rgx

A regular expression used to try to identify afk nicks. At least the most
regularly used types - folk can use anything they want after all.

=head2 schema

A DBIx schema that connects to the profile and ban database.

=head2 irc

A PoCo object used to connect to the IRC network.

=head2 nsplugin

A PoCo object used to handle identifying with nickserv on the IRC network.

=head2 rcplugin

A PoCo object used to handle automatically re-connecting to the IRC network
after a ping time-out or something similar.

=head2 logger

A PoCo object used to handle logging.

=head2 db_backup_recurrence

A DateTime::Set object that defines the schedule for backing up the bot's
profile and ban database.

=head2 ban_expiry_recurrence

A DateTime::Set object that defines the schedule for checking the database for
expired bans.

=head2 session

The POE::Session object that allows the bot to multi-task.

=head1 METHODS/SUBROUTINES

=head2 BUILD

Moose post-construction stuff. In this case, make sure that devel and deputy
aren't both set.

=head2 run

Main body of module - this is the stuff that would have otherwise been in a
script.

=head2 _start

Start listening for IRC events to respond to.

=head2 irc_001

When connected, join a channel, check that voices are correct and that current
bans are enforced.

=head2 irc_public

Something was said in channel. Inspect it for bot commands and pass any found
onto the process_command method.

=head2 irc_notice

A notice was received. Inspect it for bot commands and pass any found onto the
process_command method.

=head2 irc_msg

A private message (pm) was received. Inspect it for bot commands and pass any
found onto the process_command method.

=head2 irc_ctcp

A client-to-client protocol (ctcp) query was received. Respond to it here.

=head2 irc_join

Someone joined the channel - make sure they're allowed in, then voice and
announce them if they have a profile, greet them otherwise.

=head2 irc_nick

Someone changed nick - voice or devoice as warranted.

=head2 _default

This is the fall-back method - it just pushes its input to STDOUT for debug.

=head2 announce

Called whenever someone joins channel, or changes nick within the channel. If
the (new) nick has an intro in its profile, use that to announce them, if they
don't pull a random one from the pool.

If they have a completed profile, tag on an invitation to !ogle them onto the
intro. If they don't tag on something to encourage them to make or finish one.

=head2 find_staff

Look down through the list of guest nicks and return one with the highest
status we can find. Return an empty string if no-one at half-op or above is
found.

This is used to report errors in the database back-up email.

=head2 handled_by_guest_bot

Sometimes another bot is present in channel, typically something that a radio
D.J. uses or a trivia bot. This subroutine identifies commands meant for such a
guest bot. It relies on the commands being listed in Igor's configuration file.

=head2 process_command

Process any commands received and respond appropriately.

=head2 check_voices

Go through every nick in channel and grant or remove voice according to whether
or not they have a profile. Used when the bot joins the channel.

=head2 voice_user

Handle the voicing/devoicing stuff.

=head2 has_profile

Return true if the supplied nick has a profile (even a partial one), false
otherwise.

=head2 detail_user

Returns a hash reference with some information about the user name supplied as
the sole argument. Currently 'status' is the only key. It's built the way it
is with expansion to include other information in mind.

=head2 get_random_intro

Select a random intro from the intro_pool table.

It would probably be useful to filter out short, placeholder intros.

=head2 apply_ban_to_channel

Takes two arguments - a ban mask and a switch (on or off).

Depending on the value of the switch the method either applies the ban to the
channel or removes it.

=head2 check_bans

Iterate over current database bans and kick anyone in channel who matches one.

=head2 enforce_ban

Takes an Igor::Schema::Result::Ban object and looks for users that match it.
If they're in channel - kick them with the reason they're banned and the expiry
time.

=head2 expire_bans

Look for current database bans that have expired and mark them as such.

Delete any expired bans that are very old. The meaning of "very old" is hard-
coded (currently 1 year).

=head2 backup_db

E-mail a copy of the database file to someone as a backup. This depends on the
host system being able to send email. It will issue a warning if the sending
fails. Silently does nothing if there is no sendmail program.

=head2 have_sendmail

Return true if the sendmail program is available. False otherwise.

=head2 send_raw

Send raw IRC commands to the server.

=head2 disconnect

Shuts the bot down.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
