package Igor::BanMaker 3.009;
use 5.014;
use Moose;
use MooseX::StrictConstructor;
use Carp;
use Scalar::Util qw{looks_like_number};
use namespace::autoclean;

use Igor::DB;
use Igor::Mask;

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    return Igor::Config->new->get_config_from_file();
}

with 'Igor::Role::DBTime';
with 'Igor::Role::Schema';

has mask =>
    ( is => 'ro', isa => 'Str', required => 1, writer => '_write_mask' );
has units =>
    ( is => 'ro', isa => 'Str', default => 'days', writer => '_write_units' );
has set_by   => ( is => 'ro', isa => 'Str', default => 'The bot', );
has reason   => ( is => 'ro', isa => 'Str', default => 'No reason set', );
has duration => ( is => 'ro', isa => 'Str', default => 1, );
has error    => ( is => 'ro', isa => 'Str', writer  => '_write_error', );
has _set_on  => ( is => 'ro', isa => 'Str', writer  => '_write_set_on', );
has _lift_on => ( is => 'ro', isa => 'Str', writer  => '_write_lift_on', );

has _is_set => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
    writer  => '_write_is_set',
);

has '_db_row' => (
    is      => 'ro',
    isa     => 'Igor::Schema::Result::Ban',
    lazy    => 1,
    builder => '_build_db_row',
);


sub _build_db_row {
    my ($self) = @_;

    my $db_row = $self->schema->resultset('Ban')->create(
        {
            mask     => lc $self->mask(),
            set_by   => $self->set_by(),
            reason   => $self->reason(),
            duration => $self->duration(),
            units    => $self->units(),
            set_on   => $self->_set_on(),
            lift_on  => $self->_lift_on(),
        },
    );

    return $db_row;
}


has 'mask_obj' => (
    is      => 'ro',
    isa     => 'Igor::Mask',
    lazy    => 1,
    builder => '_build_mask_obj',
);

sub _build_mask_obj {
    my ($self) = @_;

    # Pass this object's schema so that tests work.
    my $obj = Igor::Mask->new( input => $self->mask() );

    $obj->validate();

    return $obj;
}


sub validate {
    my ($self) = @_;

    if ( $self->mask_obj->error() ) {
        $self->_write_error( $self->mask_obj->error() );
        return 0;
    }

    $self->_write_mask( $self->mask_obj->good_mask() );


    my @err;

    # We use a 'Str' attribute type for 'duration' so that we don't croak on
    # construction. The point of this class is to validate the input without
    # the user needing to trap for errors.
    if ( not looks_like_number $self->duration() ) {
        push @err, q{Period must be a number};
    }
    else {
        if ( $self->duration() <= 0 ) {
            push @err, q{Ban period is not greater than zero};
        }

        if ( $self->duration() > $self->config->{longest_ban} ) {
            push @err, q{Ban period is too long};
        }
    }

    if ( $self->units() !~
        m/\A (?: hour | day | week | fortnight | month | year ) s? \z/msx )
    {
        push @err, q{Unrecognized ban period units};
    }

    # If we have any errors, join them into one string and save them
    if ( scalar @err ) {
        my $error_string = join q{. }, @err;
        $self->_write_error(qq{$error_string.});
        return 0;
    }

    # Make sure that units are plural for DateTime->add_time() later on.
    my $units = $self->units();
    $units =~ s/ s* \z/s/msx;
    $self->_write_units($units);

    $self->_write_error(0);
    return 1;
}


sub current_bans {
    my ($self) = @_;

    my $rs = $self->schema->resultset('Ban')->search(
        { mask => lc $self->mask_obj->good_mask() },
        { order_by => 'id' }
    );


    return scalar $rs->all();
}


sub apply {
    my ($self) = @_;
    return if $self->_is_set();

    for ( $self->error() ) {
        no warnings 'experimental';    ## no critic (ProhibitNoWarnings)
        when ( not defined $_ ) { carp 'Ban not validated yet';      return; }
        when ( length $_ > 1 )  { carp 'Ban has invalid parameters'; return; }
    }

    my $set_on = $self->now_time();
    my $lift_on = $self->add_time( $self->duration(), $self->units() );

    $self->_write_set_on($set_on);
    $self->_write_lift_on($lift_on);
    my $ban = $self->_db_row();

    $ban->expired(0);
    $ban->update();
    $self->_write_is_set(1);

    return 'Ban on ' . $self->mask() . ' has been set.';
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Igor::BanMaker - Validate candidate bans and write to the database.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::BanMaker;

    # There are defaults for everything except the mask.
    my $ban = Igor::BanMaker->new( mask => $text );

    # Make sure that all the parameters are legal values.
    warn $ban->error() if not $ban->validate();

    # Write it to the database.
    $ban->apply();

=head1 DESCRIPTION

This class really only exists because nested type checking in Moose is broken
(L<76387|https://rt.cpan.org/Public/Bug/Display.html?id=76387>).

It validates the various parameters used to set a ban and, if it passes, writes
it to the database, or replaces other bans set against the same mask.

If it fails, this class gives you the reason, unlike Moose itself which, when
testing nested types, doesn't always report the particular reason for failure.

=head1 ACCESSORS

=head2 config

A hashref containing the bot's configuration parameters.

=head2 mask

The mask to use, as is, for the ban. Other than insisting on a minimum length
we don't really proof-read these.

=head2 set_by

Who set the ban. Defaults to a string identifying the bot as the author. Try
not to use that though.

=head2 reason

The reason for the ban. Defaults to a string saying no reason was given. This,
like the other ban attributes, is just there to keep the class from croaking
for a minor reason. Really a reason should always be passed to the constructor.

=head2 duration

How long the ban should last. Just the number without any units. Defaults to 1.

=head2 units

The units to go with the duration above. Defaults to 'days', i.e. the default
ban is one day.

=head2 _db_row

An Igor::Schema::Result::Profile object used to write the ban to the database.
The builder method will croak if the ban has not been validated beforehand.

=head2 mask_obj

Returns an Igor::Mask object construction on the mask attribute of this class.
Useful for accessing the methods of Igor::Mask.

=head2 error

A string where the text of any errors encountered in validation are written. A
value of undef means that the ban has not yet been validated. A value of 0
means it has, and that no errors were encountered.

=head2 _is_set

A boolean that is true after the apply method has been successfully called
once. This then prevents it from running a second time.

=head2 _set_on

Private attribute that builds the date string for when the ban was set.

=head2 _lift_on

Private attribute that builds the date string for when the ban should be
lifted.

=head2 mask_obj

A mask object, used for interaction with the database.

=head1 METHODS/SUBROUTINES

=head2 BUILD

Do some silent sanitizing of the mask attribute. Don't allow long strings of
wildcards.

=head2 validate

Make sure that the values for the attributes, reason, mask, units, duration and
set_by are all valid. This is so that, if they're not, we can pass the reason
why not back to the user. Moose's type system doesn't always let us do that
when the types are nested.

The method returns true if all the attributes validate ok, false if not. Any
errors found are listed in a single string that is written to the error
attribute. If there are no errors, i.e. validation passed, a zero is written
to the error attribute to show that validation has been run.

=head2 current_bans

Returns the number of active bans already set against the mask, not counting
this one.

=head2 apply

Writes the ban to the database. Before doing that it will construct valid
strings for the set_on and lift_on fields and add them with the object.

It will refuse to write the ban if there are validation errors or if the
validation has not been run.

=head1 CONFIGURATION AND ENVIRONMENT

Igor::Config

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
