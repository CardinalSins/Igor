use utf8;
package Igor::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-05-30 00:36:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:m3iV4dcC5vtWD1OAZrPDPw

our $VERSION = 3.009;

1;

__END__

=head1 NAME

Igor::Schema - subclass of DBIx::Class::Schema

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Schema;
    my $dsn = q{dbi:SQLite:dbname=/some/file.db};
    my $schema = Igor::Schema->connect( $dsn, q{}, q{}, { Other => args } );

=head1 DESCRIPTION

See L<DBIx::Class|DBIx::Class>.

Generate the Igor::Schema and Igor::Schema::ResultSet classes with:

C<<dbicdump -o dump_directory=./lib -o use_moose=1 Igor::Schema \
    dbi:SQLite:IgorProfiles.db>>

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


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
