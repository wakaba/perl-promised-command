use strict;
use warnings;
use Promised::Command::Docker;

my $cmd = Promised::Command::Docker->new (
  image => 'debian:sid',
  command => ['sleep', 100],
  propagate_signal => 1,
);

$cmd->start->then (sub {
  warn "executed ($_[0])";
  return Promise->new (sub { });
})->to_cv->recv;
