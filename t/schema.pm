package t::schema 3.009;    ## no critic (NamingConventions::Capitalization)

use 5.014;
use Moose;
use MooseX::StrictConstructor;
use Carp;
use English qw{-no_match_vars};
use namespace::autoclean;
use autodie qw{:all};

use Igor::Config;
use Igor::DB;

has fixtures_dir => (
    is      => 'ro',
    isa     => 'Str',
    default => 't/data/fixtures',
);

has config_file => (
    is      => 'ro',
    isa     => 'Str',
    default => 't/data/test.yaml',
);

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my ($self) = @_;

    my $config =
        Igor::Config->new->get_config_from_file( $self->config_file() );

    return $config;
}


has schema => (
    is      => 'ro',
    isa     => 'Igor::Schema',
    lazy    => 1,
    builder => '_build_schema',
);

sub _build_schema {
    my ($self) = @_;

    my $db_file = $self->config->{db_file};
    ( -e $db_file ) && ( unlink $db_file );

    my $db = Igor::DB->new( { db_file => $db_file } );
    $db->build_db( $self->fixtures_dir() );

    return $db->schema();
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

t::schema - a DBIx schema for tests, complete with data.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use t::schema;

    my $test_schema = t::schema->new->schema();

=head1 DESCRIPTION

We need a disposable database to run tests on. This is it. Or at least a useful
handle on it.

=head1 ATTRIBUTES

=head2 config_file

The path to a config file that settings can be read from.

=head2 config

A hash ref holding all the configuration parameters.

=head2 schema

The schema object itself.

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
