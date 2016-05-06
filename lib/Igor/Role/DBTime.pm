package Igor::Role::DBTime 3.009;

use 5.014;
use Moose::Role;
use Carp;
use DateTime;
use DateTime::Format::Strptime;

requires 'config';


sub now_time {
    my ($self) = @_;
    my $now = DateTime->now( time_zone => 'UTC' );
    return $now->strftime( $self->config->{timestamp_db} );
}


sub normalise_time {
    my ( $self, $timestamp ) = @_;
    croak 'Timestamp string required as argument' if !$timestamp;

    my $strp = DateTime::Format::Strptime->new(
        time_zone => 'UTC',
        pattern   => $self->config->{timestamp_db},
        on_error  => 'croak',
    );
    return $strp->parse_datetime($timestamp);
}


sub convert_time {
    my ( $self, $timestamp ) = @_;
    croak 'Timestamp string required as argument' if !$timestamp;

    my $dt = $self->normalise_time($timestamp);

    my $strp = DateTime::Format::Strptime->new(
        time_zone => 'UTC',
        pattern   => $self->config->{timestamp_output},
        on_error  => 'croak',
    );

    return $strp->format_datetime($dt);
}


sub add_time {
    my ( $self, $amount, $units ) = @_;

    $units = lc $units;
    $units =~ s/\s*\z//msx;

    # Fortnights aren't handled by DateTime methods, so convert.
    if ( $units =~ m/\A fortnight(?:s?) \z/imsx ) {
        $amount *= 2;
        $units = 'weeks';
    }

    my $dt = DateTime->now( time_zone => 'UTC' );
    $dt->add( $units => $amount );

    return $dt->strftime( $self->config->{timestamp_db} );
}


1;
__END__

=head1 NAME

Igor::Role::DBTime - takes care of date/time formatting for the database.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Moose;
    with 'Igor::Role::DBTime';

=head1 DESCRIPTION

This role provides methods to convert dates to the format used by the database
and the format used in IRC output. The UTC timezone is used for everything so
that channel guests, who can be anywhere in the world, can most easily convert.

It's arguable that many will not know what UTC is, nonetheless GMT is not a
better candidate.

=head1 METHODS/SUBROUTINES

=head2 now_time

Converts the current time to the format used in the database (storage format).

=head2 normalise_time

Converts a timestamp string in the database storage format to a DateTime
object.

=head2 convert_time

Converts a timestamp string in storage format to output format.

=head2 add_time

Takes the current time, adds to it, and converts it to storage format.

The amount to add is specified by two arguments to the method. The first should
be a number and the second a unit of time that is recognised by the
L<DateTime add|DateTime.pm#Adding_a_Duration_to_a_Datetime> method, which is what's used under the hood.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
