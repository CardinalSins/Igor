package IgorBot 3.009;

use 5.014;
use warnings qw{all FATAL utf8};
use lib qw{lib};
use Igor;
use Proc::Fork;

run_fork {
    child {
        binmode STDOUT, ':encoding(UTF-8)';
        binmode STDERR, ':encoding(UTF-8)';

        my $igor = Igor->new_with_options();

        my $handler = sub { $igor->disconnect(@_) };
        require sigtrap;
        sigtrap->import( 'handler' => $handler, 'normal-signals' );

        $igor->run();
    parent {
        my $child_pid = shift;
        # waitpid $child_pid, 0;
        open(my $pidfile,">.bot.pid");
        print $pidfile $child_pid . "\n";
        close $pidfile;
    }
    retry {
        my $attempts = shift;
        # what to do if fork() fails:
        # return true to try again, false to abort
        return if $attempts > 5;
        sleep 1, return 1;
    }
    error {
        die "Couldn't fork: $!\n";
    }
};

exit;
__END__

=encoding utf8
=head1 NAME

IgorBot - an IRC room bot

=head1 VERSION

3.009

=head1 USAGE

perl ./IgorBot.pl

=head1 DESCRIPTION

A configurable IRC channel bot that maintains user profiles and has a small
rag-bag of other functions.

It is written to sit in one channel only, but it shouldn't need a huge re-write
to get it working in several channels.

The bot assumes that it has at least HOP status in the channel but doesn't do
any checking to make sure. This cuts down on a fair bit of wasteful chatter and
means its voicing and kicking functions can be de-activated simply by de-opping
it. It will carry on as before but any voicing or kicking it tries to do from
that point will be now be the wasteful chatter.

=head1 REQUIRED ARGUMENTS

None.

=head1 OPTIONS

There are two, mutually exclusive, options. Both force the bot to choose
particular values of configuration parameters.

    --devel     Used for development of the code.
    --deputy    A back-up copy of the bot is filling in for the main one.

=head1 CONFIGURATION

There are a fair number of configurable settings for the bot. These are set
in the configuration file, IgorConfig.json. Most are self-explanatory but see
the README file for some details.

=head1 SUBROUTINES

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
