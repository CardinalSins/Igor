package Igor::Role::Schema 3.009;

use 5.014;
use Moose::Role;
use Carp;
use Igor::DB;

requires 'config';


has db => (
    is      => 'ro',
    isa     => 'Igor::DB',
    lazy    => 1,
    builder => '_build_db',
);

sub _build_db {
    my ($self) = @_;
    return Igor::DB->new( db_file => $self->config->{db_file} );
}


has schema => (
    is      => 'ro',
    isa     => 'Igor::Schema',
    lazy    => 1,
    builder => '_build_schema',
);

sub _build_schema {
    my ($self) = @_;

    return $self->db->schema();
}


sub base_table {
    my ( $self, $table ) = @_;

    croak 'Table name required' if !$table;

    return $self->schema->resultset($table);
}

1;

__END__

=head1 NAME

Igor::Role::Schema - general database access methods.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Moose;
    with 'Igor::Role::Schema';

    my $schema = $self->schema();
    my $ban_rs = $self->resultset('Ban')->search(
        {
            expired => 0,
            set_by  => 'katy'
        }
    );

=head1 DESCRIPTION

This role makes it easy to pass in different databases to the other classes -
especially for testing. It requires a config method so that it can retrieve
the name of the database file it should use to construct the schema object.

=head2 ATTRIBUTES

=head2 db

Returns the Igor::DB object that takes care of connecting to the right
database and, for tests, loading the fixture data.

=head2 schema

The Igor::Schema object (which is a DBIx::Class::Schema object).

=head1 METHODS/SUBROUTINES

=head2 base_table

Returns a DBIx::Class::ResultSet object for the table corresponding to the sole
supplied argument.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
