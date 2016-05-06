use utf8;
package Igor::Schema::Result::Profile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Igor::Schema::Result::Profile

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 TABLE: C<profile>

=cut

__PACKAGE__->table("profile");

=head1 ACCESSORS

=head2 nick

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 age

  data_type: 'varchar'
  is_nullable: 1
  size: 66

=head2 sex

  data_type: 'varchar'
  is_nullable: 1
  size: 66

=head2 loc

  data_type: 'varchar'
  is_nullable: 1
  size: 66

=head2 bdsm

  data_type: 'varchar'
  is_nullable: 1
  size: 66

=head2 limits

  data_type: 'varchar'
  is_nullable: 1
  size: 410

=head2 kinks

  data_type: 'varchar'
  is_nullable: 1
  size: 410

=head2 fantasy

  data_type: 'varchar'
  is_nullable: 1
  size: 410

=head2 desc

  data_type: 'varchar'
  is_nullable: 1
  size: 410

=head2 intro

  data_type: 'varchar'
  is_nullable: 1
  size: 410

=head2 quote

  data_type: 'varchar'
  is_nullable: 1
  size: 410

=head2 fanfare

  data_type: 'integer'
  is_nullable: 1

=head2 last_access

  data_type: 'date'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "nick",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "age",
  { data_type => "varchar", is_nullable => 1, size => 66 },
  "sex",
  { data_type => "varchar", is_nullable => 1, size => 66 },
  "loc",
  { data_type => "varchar", is_nullable => 1, size => 66 },
  "bdsm",
  { data_type => "varchar", is_nullable => 1, size => 66 },
  "limits",
  { data_type => "varchar", is_nullable => 1, size => 410 },
  "kinks",
  { data_type => "varchar", is_nullable => 1, size => 410 },
  "fantasy",
  { data_type => "varchar", is_nullable => 1, size => 410 },
  "desc",
  { data_type => "varchar", is_nullable => 1, size => 410 },
  "intro",
  { data_type => "varchar", is_nullable => 1, size => 410 },
  "quote",
  { data_type => "varchar", is_nullable => 1, size => 410 },
  "fanfare",
  { data_type => "integer", is_nullable => 1 },
  "last_access",
  { data_type => "date", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</nick>

=back

=cut

__PACKAGE__->set_primary_key("nick");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-05-30 21:29:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EPV5CfyBFDEH3RMqdta5YA

use 5.014;
use Carp;
use IRC::Utils qw{:ALL};
use List::MoreUtils qw{any};
use Igor::Config;

our $VERSION = 3.009;


has config => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my ($self) = @_;
    return Igor::Config->new->get_config_from_file();
}
with 'Igor::Role::DBTime';


sub teaser {
    my ( $self, $cased_nick ) = @_;
    croak 'Nick mismatch' if lc $cased_nick ne lc $self->nick();

    my $teaser = q{Make way for } . BOLD . PURPLE . $cased_nick . NORMAL
               . q{! Here's a taste of their juiciness.  };

    $teaser .= $self->teaser_core();
    $self->stamp();

    return $teaser;
}


sub teaser_core {
    my ( $self, $cased_nick ) = @_;

    my $content = q{};
    foreach my $i ( @{ $self->config->{teaser_fields} } ) {
        $content .= BOLD . PURPLE . $self->config->{tags}{$i} . q{:} . NORMAL
            . q{ } . $self->$i() . q{  };
    }
    $content =~ s/[ ][ ] \z//msx;

    return $content;
}


sub full_profile {
    my ( $self, $cased_nick ) = @_;
    croak 'Nick mismatch' if lc $cased_nick ne lc $self->nick();

    my @full_profile = (
        q{Profile for } . BOLD . PURPLE . $cased_nick . NORMAL . q{  }
        . $self->teaser_core()
    );

    foreach my $i ( @{ $self->config->{all_fields} } ) {
        next if any { $_ eq $i } @{$self->config->{teaser_fields} };
        next if any { $_ eq $i } @{$self->config->{optional_fields} };

        push @full_profile,
            BOLD . PURPLE . $self->config->{tags}->{$i} . q{:} . NORMAL . q{ }
            . $self->$i();
    }

    $self->stamp();

    return \@full_profile;
}


sub first_blank_field {
    my ( $self, $skip_optional ) = @_;

    $skip_optional //= 0;

    my $blank;
    foreach my $field ( @{ $self->config->{all_fields} } ) {
        next if defined $self->$field();
        next if    $skip_optional
                && any { $_ eq $field } @{ $self->config->{optional_fields} };

        $blank = $field;
        last;
    }

    return $blank;
}


sub has_blank_optional {
    my ($self) = @_;

    my $has_blank = 0;
    foreach my $field ( @{ $self->config->{optional_fields} } ) {
        next if defined $self->$field();
        $has_blank = 1;
    }

    return $has_blank;
}


sub is_complete {
    my ($self) = @_;

    my $complete = $self->first_blank_field(1) ? 0 : 1;

    return $complete;
}


sub stamp {
    my ($self) = @_;

    $self->last_access( $self->now_time() );
    $self->update();

    return;
}


=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Schema::Result::Profile;

=head1 DESCRIPTION

Deal with the profile table.

=head1 ATTRIBUTES

=head2 config

We need some of the settings in here. Make it 'rw' so that we can pass in a
test version, otherwise it just builds the default config.

=head1 METHODS/SUBROUTINES

=head2 teaser

Build and return the teaser text used to announce someone (with a profile) when
they enter channel. Update the last_access field.

=head2 teaser_core

The teaser above consists of some introductory text and then text built from
the user's profile. This method makes the profile part so that it can be
shared with the full_profile method.

=head2 full_profile

Build and return the text for the full profile. Returns it as a hash reference
of text lines that the calling class can wrap how it likes. Update the
last_access field.

=head2 first_blank_field

Go through the profile fields in order and return the first one that is blank.
Blank means undef or the empty string.

Takes a single boolean argument that specifies whether or not to skip the
optional fields in the search. The default behaviour is not to skip them.

=head2 has_blank_optional

Check to see if any of the optional profile fields are blank.

=head2 is_complete

Return true if a profile has an entry for every field.

=head2 stamp

Update the last_access field with the current time and date.

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
