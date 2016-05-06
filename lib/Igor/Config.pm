package Igor::Config 3.009;

use 5.014;
use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;


has file => (
    is      => 'ro',
    isa     => 'Str',
    default => 'IgorConfig.json',
);

has devel  => ( is => 'ro', isa => 'Bool', default => $ENV{IGOR_DEVEL}, );
has deputy => ( is => 'ro', isa => 'Bool', default => $ENV{IGOR_DEPUTY}, );
with 'Igor::Role::Config';

no Moose;
__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Igor::Config - configuration details for Igor.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Config;

    my $conf_obj = Igor::Config->new(
        file   => '/some/config/somewhere.type',
        devel  => 0,
        deputy => 0,
    );

    my $config = $conf->get_config_from_file();

    my $username = $config->{username};
    my @servers  = @{ $config->{servers} };
    etc...

=head1 DESCRIPTION

This class handles reading configuration values for Igor from a file. It is
built around L<Config::Any|Config::Any> and so the configuration file can be
any of a number of formats.

We need it (rather than have classes consume Igor::Role::Config themselves)
for Igor::Types and if we have to do that then this class might as well take
care of the devel and deputy attributes too.

If no 'file' argument is supplied it uses a default value of 'IgorConfig.json'
which it expects to find in the same directory as Igor's script.

The two other optional arguments, 'devel' and 'deputy', modify Igor's
behaviour, mostly by choosing configuration values from sections of the file
named after them. See <Igor::Role::Config|Igor::Role::Config> for details of
how conflicting values are merged.

Although Igor is currently coded to accept only one of the two arguments, this
class will accept both, giving precedence to 'devel' in cases of conflict.

=head1 ACCESSORS

=head2 file

The name of the configuration file.

=head2 devel

A flag that puts Igor in test mode - altering particular behaviour and
configuration. Used during development of new features, or refactoring, etc.

=head2 deputy

A flag that puts Igor in deputy mode - i.e. another copy is used as the usual
channel bot and this instance is only temporarily filling in.

=head1 METHODS/SUBROUTINES

See L<Igor::Role::Config|Igor::Role::Config>.

=head1 CONFIGURATION AND ENVIRONMENT

Expects a file, 'IgorConfig.yml', to be present in the same directory as
Igor.pl unless an alternative is specified in the constructor.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
