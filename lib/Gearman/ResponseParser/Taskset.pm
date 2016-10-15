package Gearman::ResponseParser::Taskset;
use version;
$Gearman::ResponseParser::Taskset::VERSION = qv("1.130.003");

use strict;
use warnings;

use base 'Gearman::ResponseParser';

=head1 NAME

Gearman::ResponseParser::Taskset - gearmand response parser implementation

=head1 DESCRIPTION


derived from L<Gearman::ResponseParser>

=head1 METHODS

=cut

sub new {
    my ($class, %opts) = @_;
    my $ts = delete $opts{taskset};
    ref($ts) eq "Gearman::Taskset"
        || die "provided argument is not a Gearman::Taskset reference";

    my $self = $class->SUPER::new(%opts);
    $self->{_taskset} = $ts;
    return $self;
} ## end sub new

=head2 on_packet($packet, $parser)

provide C<$packet> to L<Gearman::Taskset> process_packet

=cut

sub on_packet {
    my ($self, $packet, $parser) = @_;
    $self->{_taskset}->process_packet($packet, $parser->source);
}

=head2 on_error($msg)

die C<$msg>

=cut

sub on_error {
    my ($self, $errmsg) = @_;
    die "ERROR: $errmsg\n";
}

1;
