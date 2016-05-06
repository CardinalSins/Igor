package t::server 3.009;    ## no critic (NamingConventions::Capitalization)

use 5.014;
use warnings;
use POE qw{Component::Server::IRC};
use strict;
use warnings FATAL => 'all';

my %config = (
    servername => 'tester.for.igor.irc',
    network    => 'SimpleNET'
);

my $pocosi = POE::Component::Server::IRC->spawn( config => \%config );

POE::Session->create(
    package_states => [
        't::server' => [qw/_start _default/],
    ],
    heap => { ircd => $pocosi },
);

# Uncomment this, when you work out how to use this test server.
#$poe_kernel->run();

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    $heap->{ircd}->yield('register', 'all');

    # Anyone connecting from the loopback gets spoofed hostname
    $heap->{ircd}->add_auth(
        mask     => '*@localhost',
        spoof    => 'm33p.com',
        no_tilde => 1,
    );

    # We have to add an auth as we have specified one above.
    $heap->{ircd}->add_auth(mask => '*@*');

    # Start a listener on the 'standard' IRC port.
    $heap->{ircd}->add_listener(port => 6667);

    # Add an operator who can connect from localhost
    $heap->{ircd}->add_operator(
        {
            username => 'moo',
            password => 'fishdont',
        }
    );
}

sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];

    print "$event: ";
    for my $arg (@$args) {
        if (ref($arg) eq 'ARRAY') {
            print "[", join ( ", ", @$arg ), "] ";
        }
        elsif (ref($arg) eq 'HASH') {
            print "{", join ( ", ", %$arg ), "} ";
        }
        else {
            print "'$arg' ";
        }
    }

    print "\n";
}

1;
__END__

=head1 NAME

t::server - supply a mock server for tests.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use t::server;

=head1 DESCRIPTION

This is an experimental thing - it should allow more complex tests than the
unit tests in the rest of the t directory.

But I don't know how to use it yet.

=head1 METHODS/SUBROUTINES

None.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Released under the same terms as Perl itself.

=cut
