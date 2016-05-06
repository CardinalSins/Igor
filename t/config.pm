package t::config 3.009;    ## no critic (NamingConventions::Capitalization)

use 5.014;
use warnings;
use Exporter qw{import};
use Igor::Config;

my $cfg_file = q{t/data/test.yaml};
our $CONFIG = Igor::Config->new->get_config_from_file($cfg_file);

our @EXPORT = qw{$CONFIG};    ## no critic (ProhibitAutomaticExportation)

1;
__END__

=head1 NAME

t::config - supply a config object for tests.

=head1 VERSION

3.009

=head1 SYNOPSIS

    use t::config;

=head1 DESCRIPTION

Export a config object for test files. The code is only a couple of lines but
if we decide to change the file, or anything else, it's easier to do it once,
here.

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
