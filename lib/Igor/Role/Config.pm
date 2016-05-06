package Igor::Role::Config 3.009;

use 5.014;
use Moose::Role;
use Carp;
use Config::Any;
use Data::Transformer;
use Hash::Merge qw{_merge_hashes};
use IRC::Utils qw{:ALL};

with 'MooseX::ConfigFromFile';
requires 'file';


# This is used to merge the main part of the config with a devel or deputy
# section.
has _merger => (
    is      => 'ro',
    isa     => 'Hash::Merge',
    lazy    => 1,
    builder => '_build_merger',
);

sub _build_merger {

    my $err_str = 'Type conflict in merged config sections';

    my $behaviour = {
        SCALAR => {
            SCALAR => sub { $_[1] },
            ARRAY  => sub { croak $err_str },
            HASH   => sub { croak $err_str },
        },
        ARRAY => {
            SCALAR => sub { croak $err_str },
            ARRAY  => sub { $_[1] },
            HASH   => sub { croak $err_str },
        },
        HASH => {
            SCALAR => sub { croak $err_str },
            ARRAY  => sub { croak $err_str },
            HASH   => sub { _merge_hashes( $_[0], $_[1] ) },
        },
    };

    my $merger = Hash::Merge->new();
    $merger->specify_behavior( $behaviour, 'config_merge' );

    return $merger;
}

sub get_config_from_file {
    my ( $self, $file ) = @_;

    $file //= $self->file();

    my $cfg = Config::Any->load_files(
        {
            files   => [$file],
            use_ext => 1,
        }
    );

    my ( $name, $config ) = %{ $cfg->[0] };
    $config = $self->_deputy_devel($config);


    my $replace_tags = sub {
        local ($_) = @_;
        ${$_} =~ s/<b>/BOLD/egmsx;

        while ( ${$_} =~ m/<<(\w+)>>/msx ) {
            my $match = $1;

            # The ':' clause prevents infinite loops.
            ( defined $config->{$match} )
                ? ( ${$_} =~ s/<<$match>>/$config->{$match}/egmsx )
                : ( ${$_} =~ s/<<$match>>/qq{< <$match> >}/egmsx );
        }

        # Put non-config tags back the way they were.
        ${$_} =~ s/<[ ]<(\w+)>[ ]>/<<$1>>/gmsx;
    };

    my $t = Data::Transformer->new( normal => $replace_tags );
    $t->traverse($config);

    return $config;
}


sub _deputy_devel {
    my ( $self, $c ) = @_;

    my $deputy_ref = $c->{deputy};
    my $devel_ref  = $c->{devel};

    delete $c->{deputy};
    delete $c->{devel};

    if ( $self->deputy() ) {
        $c = $self->_merge_configs( $c, $deputy_ref );
    }

    if ( $self->devel() ) {
        $c = $self->_merge_configs( $c, $devel_ref );
    }

    return $c;
}


sub _merge_configs {
    my ( $self, $into, $from ) = @_;

    my $merged = $self->_merger->merge( $into, $from );

    return $merged;
}


1;
__END__

=head1 NAME

Igor::Role::Config - supplies config file handling roles.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Moose;
    with 'Igor::Role::Config';

=head1 DESCRIPTION

This is a Moose Role that provides the get_config_from_file() method from
L<MooseX::ConfigFromFile|MooseX::ConfigFromFile>.

Consuming classes must supply a 'file' attribute or method to provide a default
configuration file.

Any text-based config parameter that contains the name of another parameter in
angle brackets will have that marker replaced by the value of the other
parameter.

The 'rules' parameter in particular makes heavy use of that with the texts
'<<channel>>' and '<<bot>>' intended to be replaced by the IRC channel name
and the bot's own name (it doesn't have to be Igor). This class takes care of
that substitution.

=head1 METHODS/SUBROUTINES

=head2 get_config_from_file

Reads a config file that must be supplied by the consuming class.

The config file can have two optional sections labelled 'devel' or 'deputy'. If
the corresponding object attribute is set the section is read and its values
merged with the main (parent) section. If both are set 'deputy' gets merged
first then 'devel', i.e. in cases of conflict 'devel' will take priority.

The merge is carried out using a custom L<Hash::Merge|Hash::Merge> merge
behaviour that, in the case of conflicts, overwrites the main value with the
section value, except where they are hashes in which case it retains key-value
pairs in the main hash that are not in the section hash.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

There is nothing to trap circular references - two parameters referring to
each other's value.

Please contact the author with any others found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
