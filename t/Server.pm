package t::Server;
use strict;
use warnings;

use base qw/Exporter/;
use fields qw/
    _bin
    _ip
    _servers
    /;

use File::Which ();
use Test::TCP;

use vars qw/
    $ERROR
    /;

our @EXPORT = qw/
    $ERROR
    /;

sub new {
    my ($self) = @_;
    unless (ref $self) {
        $self = fields::new($self);
    }

    if ($ENV{GEARMAND_ADDR}) {
        $self->{_servers} = [split ',', $ENV{GEARMAND_ADDR}];
    }
    else {
        my $daemon = "gearmand";
        my $bin = $ENV{GEARMAND_PATH} || File::Which::which($daemon);

        unless ($bin) {
            $ERROR = "Can't find $daemon to test with";
        }
        elsif (!-X $bin) {
            $ERROR = "$bin is not executable";
        }

        $ERROR && return;

        $self->{_ip}      = $ENV{GEARMAND_IP} || "127.0.0.1";
        $self->{_bin}     = $bin;
        $self->{_servers} = [];
    } ## end else [ if ($ENV{GEARMAND_ADDR...})]

    return $self;
} ## end sub new

sub _start_server {
    my ($self) = @_;
    my $s = Test::TCP->new(
        host => $self->host,
        code => sub {
            my $port = shift;
            my %args = (
                "--port"   => $port,
                "--listen" => $self->host,
                $ENV{GEARMAND_DEBUG} ? ("--verbose" => "DEBUG") : ()
            );

            exec($self->bin(), %args) or do {
                $ERROR = sprintf "cannot execute %s: $!", $self->bin;
            };
        },
    );

    ($ERROR) && return;

    return $s;
} ## end sub _start_server

sub job_servers {
    my ($self, $count) = @_;
    $self->bin || return @{ $self->{_servers} };

    $count ||= 1;
    my @r;
    while ($count--) {
        my $s = $self->_start_server;
        $s || die $ERROR;
        push @{ $self->{_servers} }, $s;
        push @r, join(':', $self->host, $s->port);
    } ## end while ($count--)

    return @r;
} ## end sub job_servers

sub bin {
    return shift->{_bin};
}

sub host {
    return shift->{_ip};
}

1;
