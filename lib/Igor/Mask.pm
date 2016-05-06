package Igor::Mask 3.009;
use 5.014;
use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

use Igor::Config;
use Igor::DB;

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config { return Igor::Config->new->get_config_from_file(); }

has input     => ( is => 'ro', isa => 'Str', required => 1, );
has good_mask => ( is => 'ro', isa => 'Str', writer => '_set_good_mask', );
has error     => ( is => 'ro', isa => 'Str', writer => '_write_error', );

sub validate {
    my ($self) = @_;

    my $mask = $self->input();

    # We could try to handle quiet, nickchange, real name and channel bans down
    # the line. But for now, let's not. If/when we do, it could go like this...
    #my $extended = q{};
    #( $mask =~ s/ \A (~[qncr]:) //msx ) && ( $extended = $1 );
    # Igor.pm would have to know not to kick in those cases.

    # Just remove and ignore

    # Clean up repetitive wild-cards
    $mask =~ s/[*]+/*/gmsx;
    $mask =~ s/(?:[.][*])+/.*/gmsx;
    $mask =~ s/(?:[*][.])+/*./gmsx;

    my @err;

    ( $mask !~ m/[^*.@!?]/msx ) && ( push @err, q{Mask is all wildcards} );

    ( $mask =~ m/(cuff-link)/imsx )
        && ( push @err, qq{You can't have '$1' in the mask} );

    my $no_metas = $mask =~ s/[*.@!?]//gmrsx;
    my $len = length $no_metas;

    $len && ( $len < $self->config->{shortest_mask} )
        && ( push @err, q{Mask isn't specific enough} );

    # If we have any errors, join them into one string and save them.
    if ( scalar @err ) {
        my $error_string = join q{. }, @err;
        $self->_write_error(qq{$error_string.});
        return 0;
    }

    # I suspect that many IRC servers/clients do the next two things anyway.
    # If the mask looks like a nick - expand it accordingly.
    ( $mask =~ m/ \A [[:alnum:]{}[\]`|_^-]+ \z /msx )
        && ( $mask .= q{!*@*} );  ## no critic (RequireInterpolationOfMetachars)

    # If it looks like just an IP address - expand it too.
    ( $mask !~ m/[@]/msx )
        && ( $mask =~ m/[.]/msx )
        && ( $mask = q{*!*@} . $mask );

    $self->_set_good_mask($mask);

    $self->_write_error(0);
    return 1;
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Igor::Mask - Validate and look up ban masks

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Mask;

    my $mask = Igor::Mask->new( input => $text );

    # You must run validate.
    $mask->validate() || die $mask->error();

    # We sometimes change what we're given if it validates.
    my $usable_mask = $mask->good_mask();

=head1 DESCRIPTION

Some general methods for masks and for working with the database ban table.

=head1 ATTRIBUTES

=head2 config

A hashref containing the bot's configuration parameters.

=head2 input

The proposed mask to use for the ban. This is the only required attribute.

=head2 good_mask

A validated, and potentially modified, version of $self->input(). This is undef
if validation fails - or isn't run.

=head1 METHODS/SUBROUTINES

=head2 validate

Check the text provided in $self->input() against various criteria to make
sure that it will be a good ban mask.

Any problems found are listed in $self->error().

Also silently clean up various potential problem features in malicious masks.
Save the cleaned version in $self->good_mask().


=head1 CONFIGURATION AND ENVIRONMENT

Igor::Config

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
