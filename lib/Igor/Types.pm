package Igor::Types 3.009;

use 5.014;
use warnings;
use Igor::Config;

use MooseX::Types -declare => [
    qw{
        NotJustWildcards
        BanMask
        Period
        PositiveNum
        ReasonableNum
        NonEmptyStr
        NoLeadingDigit
        ReasonableLength
        ValidNick
    }
];

use MooseX::Types::Moose qw{ Num Str };


# If we're part of a test use the test config file.
my $file = $ENV{IGOR_TEST} ? q{t/data/test.yaml} : undef;
my $config = Igor::Config->new->get_config_from_file($file);


subtype NotJustWildcards,
    as Str,
    where { m/[^.*@!]/msx },
    message { 'Mask is too general' };

subtype BanMask,
    as NotJustWildcards,
    where { length $_ > $config->{shortest_mask} },
    message { 'Mask is too short' };

# Use plurals since DateTime methods use them. Remember to convert to singular
# where appropriate for output. Nothing will break if you don't but you'll get
# things like "1 weeks".
subtype Period,
    as Str,
    where {
        $_ =~ m/\A (?: hour | day | week | fortnight | month | year ) s \z/msx
    },
    message { 'Unrecognized ban period units' };

subtype PositiveNum,
    as Num,
    where { $_ > 0 },
    message { 'Ban period is not greater than zero' };

subtype ReasonableNum,
    as PositiveNum,
    where { $_ <= $config->{longest_ban} },
    message { 'Ban period is too long' };

subtype NonEmptyStr,
    as Str,
    where { length $_ > 0 },
    message { 'String is empty' };

subtype NoLeadingDigit,
    as NonEmptyStr,
    where { $_ !~ m/ \A [[:digit:]] /msx },
    message { 'String starts with a digit' };

# This should subtype NonEmptyStr and we should have ValidNick subtype both.
subtype ReasonableLength,
    as NoLeadingDigit,
    where { length $_ <= $config->{longest_nick} },
    message { 'String is too long' };

subtype ValidNick,
    as ReasonableLength,
    where { $_ !~ m/[^[:alnum:]{}[\]`|_^-]/msx },
    message { 'Nick contains invalid characters' };

1;
__END__

=head1 NAME

Igor::Types - Custom Moose types for Igor.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Moose;
    use Igor::Types qw{ BanMask Period ReasonableNum };

=head1 DESCRIPTION

Imports custom Moose types into Igor's modules.

=head1 METHODS/SUBROUTINES

None.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
