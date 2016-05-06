package Igor::Email 3.009;

use 5.014;
use Moose;
use MooseX::StrictConstructor;
use Carp;
use Email::MIME;
use Email::Sender::Simple qw{sendmail};
use Email::Sender::Transport::SMTP;
use IO::All;
use Try::Tiny;
use Igor::Config;
use namespace::autoclean;

has config => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_config',
);

sub _build_config {
    my ($self) = @_;
    return Igor::Config->new->get_config_from_file();
}

has 'file_name' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_file_name',
);

sub _build_file_name {
    my ($self) = @_;
    return $self->config->{db_file};
}

has 'path' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_path',
);

sub _build_path {
    my ($self) = @_;
    return q{./} . $self->file_name();
}

has 'subject' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'Weekly backup ' . scalar localtime(),
);

has 'addresses' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_addresses',
);

sub _build_addresses {
    my ($self) = @_;
    my $add_list = join q{, }, @{ $self->config->{backup_email_address} };
    return $add_list;
}

has 'from' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_from',
);

sub _build_from {
    my ($self) = @_;
    return $self->config->{bot_nick};
}

has 'content_type' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'application/x-sqlite3',
);

has 'encoding' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'base64',
);

has '_error' => (
    is     => 'rw',
    isa    => 'Maybe[Str]',
    writer => '_set_error',
    reader => 'get_error',
);

has 'message' => (
    is      => 'ro',
    isa     => 'Email::MIME',
    lazy    => 1,
    builder => '_build_message',
);

sub _build_message {
    my ($self) = @_;
    my $message = Email::MIME->create(
        header => [ Subject => $self->subject(), ],
        attributes => {
            filename     => $self->path(),
            content_type => $self->content_type(),
            encoding     => $self->encoding(),
            name         => $self->file_name(),
        },
        body => io( $self->path() )->all(),
    );

    return $message;
}

sub dispatch {
    my ($self) = @_;

    my $success;

    try {
        sendmail(
            $self->message(),
            {
                from    => $self->from(),
                subject => $self->subject(),
                to      => $self->addresses(),
            }
        );
        $self->_set_error(undef);
        $success = 1;
    }
    catch {
        $self->_set_error( $_->message() );
        $success = 0;
    };

    return $success;
}

__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Igor::Email - send database backups via email

=head1 VERSION

3.009

=head1 SYNOPSIS

    use Igor::Email;

    my $email = Igor::Email->new();

    $email->send() || warn $email->error();

=head1 DESCRIPTION

All this module does is send a copy of Igor's database to someone by e-mail. It
could easily be expanded to do lots more though.

=head1 ATTRIBUTES

=head2 config

A hashref holding Igor's configuration parameters.

=head2 file_name

Read-only. The name of the database file. Defaults to config value.

=head2 path

Read-only. The path to the database file. Defaults to current working
directory and $self->file_name().

=head2 from

Read-only. The e-mail sender. Defaults to config value for Igor's
name.

=head2 subject

Read-only. The subject to use for the e-mail. Defaults to text based on the
current date.

=head2 addresses

Read-only. The addresses to send the e-mail to. Defaults to config value.

=head2 content_type

Read-only. The MIME type for the e-mail attachment. Defaults to
application/x-sqlite3.

=head2 encoding

Read-only. The encoding used for the e-mail attachment. Defaults to base64.

=head2 message

Read-only. The e-mail message. Will lazy build.

=head1 METHODS/SUBROUTINES

=head2 dispatch

Sends the message. If it fails it will catch an Email::Sender::Failure object
and will write the message attribute of that object to its own error attribute
- which can then be accessed via get_error().

=head2 get_error

Returns the text of any error encountered when trying to send the message.

=head1 CONFIGURATION AND ENVIRONMENT

None.

=head1 BUGS AND LIMITATIONS

Please contact the author with any found.

=head1 AUTHOR

John O'Brien

=head1 LICENCE AND COPYRIGHT

Copyright remains with the author. Please use only after agreement with author.

=cut
