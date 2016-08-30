use strict;
use warnings;

# OK gearmand v1.0.6
# OK Gearman::Server

use File::Which qw//;
use IO::Socket::INET;
use Test::More;
use Test::Timer;
use Test::TCP;

my $daemon = "gearmand";
my $bin    = File::Which::which($daemon);
my $host   = "127.0.0.1";
my $mn     = "Gearman::Worker";
use_ok($mn);

can_ok(
    $mn, qw/
      _get_js_sock
      _on_connect
      _register_all
      _set_ability
      job_servers
      register_function
      reset_abilities
      uncache_sock
      unregister_function
      work
      /
);

subtest "new", sub {
    my $w = new_ok($mn);
    isa_ok( $w, 'Gearman::Objects' );

    is( ref( $w->{sock_cache} ),        "HASH" );
    is( ref( $w->{last_connect_fail} ), "HASH" );
    is( ref( $w->{down_since} ),        "HASH" );
    is( ref( $w->{can} ),               "HASH" );
    is( ref( $w->{timeouts} ),          "HASH" );
    ok( $w->{client_id} =~ /^\p{Lowercase}+$/ );
};

subtest "register_function", sub {
    my $w = new_ok($mn);
    my ( $tn, $to ) = qw/foo 2/;
    my $cb = sub { 1 };

    ok( $w->register_function( $tn => $cb ), "register_function($tn)" );

    time_ok(
        sub {
            $w->register_function( $tn, $to, $cb );
        },
        $to,
        "register_function($to, cb)"
    );
};

subtest "reset_abilities", sub {
    my $w = new_ok($mn);
    $w->{can}->{x}      = 1;
    $w->{timeouts}->{x} = 1;

    ok( $w->reset_abilities() );

    is( keys %{ $w->{can} },      0 );
    is( keys %{ $w->{timeouts} }, 0 );
};

subtest "work", sub {
    my $w = new_ok($mn);

    time_ok(
        sub {
            $w->work( stop_if => sub { pass "work stop if"; } );
        },
        12,
        "stop if timeout"
    );
};

subtest "_get_js_sock", sub {
    my $w = new_ok($mn);

    is( $w->_get_js_sock(), undef );

    $w->{parent_pipe} = rand(10);
    my $hp = "127.0.0.1:9050";

    is( $w->_get_js_sock($hp), $w->{parent_pipe} );

    delete $w->{parent_pipe};
    is( $w->_get_js_sock($hp), undef );

  SKIP: {
        $bin || skip "no $daemon", 4;
        my $gs = Test::TCP->new(
            code => sub {
                my $port = shift;
                exec $bin, '-p' => $port;
                die "cannot execute $bin: $!";
            },
        );

        ok( $w->job_servers( join( ':', $host, $gs->port ) ) );

        $hp                          = $w->job_servers()->[0];
        $w->{last_connect_fail}{$hp} = 1;
        $w->{down_since}{$hp}        = 1;

        isa_ok( $w->_get_js_sock( $hp, on_connect => sub { 1 } ),
            "IO::Socket::INET" );
        is( $w->{last_connect_fail}{$hp}, undef );
        is( $w->{down_since}{$hp},        undef );
    } ## end SKIP:
};

subtest "_on_connect-_set_ability", sub {
    my $w = new_ok($mn);
    my $m = "foo";

    is( $w->_on_connect(), undef );

    is( $w->_set_ability(), 0 );
    is( $w->_set_ability( undef, $m ), 0 );
    is( $w->_set_ability( undef, $m, 2 ), 0 );
};

done_testing();

