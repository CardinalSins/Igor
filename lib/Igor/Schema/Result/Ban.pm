use utf8;
package Igor::Schema::Result::Ban;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Igor::Schema::Result::Ban

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<ban>

=cut

__PACKAGE__->table("ban");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 mask

  data_type: 'text'
  is_nullable: 0

=head2 set_on

  data_type: 'date'
  is_nullable: 1

=head2 lift_on

  data_type: 'date'
  is_nullable: 0

=head2 duration

  data_type: 'integer'
  is_nullable: 1

=head2 units

  data_type: 'text'
  is_nullable: 1

=head2 set_by

  data_type: 'text'
  is_nullable: 0

=head2 reason

  data_type: 'text'
  is_nullable: 0

=head2 expired

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "mask",
  { data_type => "text", is_nullable => 0 },
  "set_on",
  { data_type => "date", is_nullable => 1 },
  "lift_on",
  { data_type => "date", is_nullable => 0 },
  "duration",
  { data_type => "integer", is_nullable => 1 },
  "units",
  { data_type => "text", is_nullable => 1 },
  "set_by",
  { data_type => "text", is_nullable => 0 },
  "reason",
  { data_type => "text", is_nullable => 0 },
  "expired",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-05-30 03:28:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zx/rHVSxevb/cx5k9PA3zQ

our $VERSION = 3.009;

use Igor::Config;

has config => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    return Igor::Config->new->get_config_from_file();
}

with 'Igor::Role::Schema';


=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Schema::Result::Ban;

=head1 DESCRIPTION

Deal with the ban table.

=head1 ATTRIBUTES

=head2 config

We need some of the settings in here (or we will if we ever develop this class
further). Make it 'rw' so that we can pass in a test version, otherwise it just
builds the default config.

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
__PACKAGE__->meta->make_immutable();
1;
