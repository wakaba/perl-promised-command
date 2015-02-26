use strict;
use warnings;
use Promised::Command;
use AnyEvent;

my $cv = AE::cv;
my $cmd = Promised::Command->new (['sleep', 10]);

$cmd->run->then (sub {
  warn "executed ($_[0])";
  warn $cmd->pid;
  warn $cmd->running;
  $cmd->wait->then (sub {
    warn "waited ($_[0])";
    warn $cmd->running;
    $cv->send;
  });
});

$cv->recv;
