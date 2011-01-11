#!/usr/bin/perl

package Net::Server::Test;
use strict;
use FindBin qw($Bin);
use lib $Bin;
use NetServerTest qw(prepare_test ok use_ok diag);
my $env = prepare_test({n_tests => 5, start_port => 20400, n_ports => 1}); # runs three of its own tests

use_ok('Net::Server::MultiType');
@Net::Server::Test::ISA = qw(Net::Server::MultiType);


sub accept {
    $env->{'signal_ready_to_test'}->();
    diag("Net::Server::MultiType::ISA: (@Net::Server::MultiType::ISA)");
    return shift->SUPER::accept(@_);
}

my $ok = eval {
    local $SIG{'ALRM'} = sub { die "Timeout\n" };
    alarm $env->{'timeout'};
    my $pid = fork;
    die "Trouble forking: $!" if ! defined $pid;

    ### parent does the client
    if ($pid) {
        $env->{'block_until_ready_to_test'}->();

        my $remote = IO::Socket::INET->new(PeerAddr => $env->{'hostname'}, PeerPort => $env->{'ports'}->[0]) || die "Couldn't open child to sock: $!";
        my $line = <$remote>;
        diag($line);
        die "Didn't get the type of line we were expecting: ($line)" if $line !~ /Net::Server/;
        print $remote "exit\n";
        return 1;

    ### child does the server
    } else {
        eval {
            close STDERR;
            Net::Server::Test->run(port => $env->{'ports'}->[0], host => $env->{'hostname'}, background => 0, setsid => 0,
                                   server_type => 'Single');
        } || diag("Trouble running server: $@");
        exit;
    }
    alarm(0);
};
alarm(0);
ok($ok, "Got the correct output from the server") || diag("Error: $@");
