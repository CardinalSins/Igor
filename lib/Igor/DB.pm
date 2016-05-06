package Igor::DB 3.009;

use 5.014;
use Moose;
use MooseX::StrictConstructor;
use Carp;
use DBIx::RunSQL;
use English qw{-no_match_vars};
use YAML::XS qw{LoadFile};
use namespace::autoclean;
use Igor::Schema;

has db_file => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has schema => (
    is      => 'ro',
    isa     => 'Igor::Schema',
    lazy    => 1,
    builder => '_build_schema',
);

sub _build_schema {
    my ($self) = @_;

    return Igor::Schema->connect( $self->dsn(), q{}, q{} );
}

has dsn => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_dsn',
);

sub _build_dsn {
    my ($self) = @_;
    return q{dbi:SQLite:dbname=} . $self->db_file();
}

sub build_db {
    my ( $self, $fixtures_dir ) = @_;

    # We could use $self->schema->deploy() but it doesn't load the triggers.
    # This also means we can't use :memory: as we lose it after this method.
    my $test_dbh = DBIx::RunSQL->create(
        dsn     => $self->dsn(),
        sql     => 'CreateDB.sql',
        force   => 1,
        verbose => 0,
    );

    $self->_load_fixtures($fixtures_dir);

    return;
}

sub _load_fixtures {
    my ( $self, $path ) = @_;

    opendir my ($dh), $path;

    my @fixtures = grep { m/ [.]y a? ml \Z /imsx } readdir $dh;

    croak qq{No fixtures found at $path} if scalar @fixtures == 0;

    foreach my $fx (@fixtures) {
        my $yml = LoadFile(qq{$path/$fx});

        my $table = $fx =~ s/ [.]y a? ml \Z //rimsx;

        foreach my $row ( @{$yml} ) {
            $self->schema->resultset($table)->create($row);
        }
    }

    return;
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Igor::DB - Handle Igor's database

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::DB;

    my $db = Igor::DB->new( db_file => '/path/to/sqlite3.db' );

    # Mostly this is all your scripts/classes will want:
    my $schema = $db->schema();

    # To start off a new copy, usually for running tests
    $db->build_db();

    # Or, you can do this and populate the tables at the same time with:
    $db->build_db( '/directory/of/yaml/fixtures' );

=head1 DESCRIPTION

Igor uses and SQLite database for profile and ban storage and used
L<DBIx::Class|DBIx::Class> to handle the database. This class is mostly
intended for use in testing, but can be used to return a schema connection
object.

=head1 ATTRIBUTES

=head2 db_file

A required attribute - the path to the sqlite database file used for Igor.
For testing this could be ':memory' rather than a file.

=head2 dsn

The data source name string for connecting to the database.

=head2 schema

A connected DBIx::Class::Schema object based on the 'db_file' attribute.

=head1 METHODS/SUBROUTINES

=head2 build_db

Create the database tables and, if the path to a directory of YAML fixtures is
provided as an argument, populate the tables from those fixtures. The fixtures
should be one file per table and have the same name as the ResultSet class for
the table they are to populate.

If the db_file already contains an SQLite database this method will croak.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut



