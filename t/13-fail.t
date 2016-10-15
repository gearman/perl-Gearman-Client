use strict;
use warnings;

# OK gearmand v1.0.6

use File::Which qw/ which /;
use Test::More;
use t::Server qw/ new_server /;
use t::Worker qw/ new_worker /;

my $daemon = "gearmand";
my $bin    = $ENV{GEARMAND_PATH} || which($daemon);
my $host   = "127.0.0.1";

$bin      || plan skip_all => "Can't find $daemon to test with";
(-X $bin) || plan skip_all => "$bin is not executable";

my %job_servers;

my $gs = new_server($bin, $host);
$gs || BAIL_OUT "couldn't start $bin";

my $job_server = join(':', $host, $gs->port);

use_ok("Gearman::Client");

my $client = new_ok(
    "Gearman::Client",
    [
        exceptions  => 1,
        job_servers => [$job_server]
    ]
);

## Test some failure conditions:
## Normal failure (worker returns undef or dies within eval).
subtest "wokrker process fails", sub {
    my $func    = "fail";
    my @workers = map(new_worker(
            job_servers => [$job_server],
            func        => {
                $func => sub {undef}
            }
        ),
        (0 .. int(rand(1) + 1)));
    is($client->do_task($func),
        undef, "Job that failed naturally returned undef");

    ## Test retry_count.
    my $retried = 0;
    is(
        $client->do_task(
            $func => '',
            {
                on_retry    => sub { $retried++ },
                retry_count => 3,
            }
        ),
        undef,
        "Failure response is still failure, even after retrying"
    );
    is($retried, 3, "Retried 3 times");

    my $ts = $client->new_task_set;
    my ($completed, $failed) = (0, 0);
    $ts->add_task(
        $func => '',
        {
            on_complete => sub { $completed = 1 },
            on_fail     => sub { $failed    = 1 },
        }
    );
    $ts->wait;
    is($completed, 0, "on_complete not called on failed result");
    is($failed,    1, "on_fail called on failed result");
};

subtest "worker process dies", sub {
    plan skip_all => "subtest fails with gearman v1.1.12";

    my $func   = "fail_die";
    my $worker = new_worker(
        job_servers => [$job_server],
        func        => {
            $func => sub { die "test reason" }
        }
    );

    # the die message is available in the on_fail sub
    my $msg   = undef;
    my $tasks = $client->new_task_set;
    $tasks->add_task($func, undef, { on_exception => sub { $msg = shift }, });
    $tasks->wait;
    like(
        $msg,
        qr/test reason/,
        "the die message is available in the on_fail sub"
    );

};

## Worker process exits.
subtest "worker process exits", sub {
    plan skip_all => "TODO supported only by Gearman::Server";

    my $func    = "fail_exit";
    my @workers = map(new_worker(
            job_servers => [$job_server],
            func        => {
                $func => sub { exit 255 }
            }
        ),
        (0 .. int(rand(1) + 1)));
    is(
        $client->do_task(
            $func, undef,
            {
                on_fail     => sub { warn "on fail" },
                on_complete => sub { warn "on success" },
                on_status   => sub { warn "on status" }
            }
        ),
        undef,
        "Job that failed via exit returned undef"
    );
};

done_testing();

