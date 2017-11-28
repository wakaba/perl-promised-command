use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Promised::Command::Docker;
use Promised::Flow;

my $Docker = undef;

if ($ENV{TRAVIS} and $ENV{TRAVIS_OS_NAME} eq 'osx' and not -x ($Docker || 'docker')) {
  print "1..1\nok 1 # skip Travis on Mac OS X does not support docker\n";
  exit 0;
}

test {
  my $c = shift;
  my $cmd = Promised::Command::Docker->new (
    docker => $Docker,
    image => 'debian:sid',
    command => ['sleep', 100],
  );
  $cmd->start->then (sub {
    return $cmd->get_container_ipaddr;
  })->then (sub {
    my $r = $_[0];
    test {
      like $r, qr{\A[0-9]+(?:\.[0-9]+){3}\z};
    } $c;
    return $cmd->get_container_ipaddr->then (sub {
      my $r2 = $_[0];
      test {
        is $r2, $r;
      } $c;
      return $cmd->stop;
    });
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 2, name => 'get_container_ipaddr (object method)';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
