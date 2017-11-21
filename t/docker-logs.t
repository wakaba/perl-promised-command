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
  my $logs = '';
  my $cmd = Promised::Command::Docker->new (
    docker => $Docker,
    image => 'debian:sid',
    command => ['perl', '-e', q{
      print STDOUT "abc\x0A";
      print STDERR "xyz\x0A";
      sleep 100;
    }],
    logs => sub {
      $logs .= defined $_[0] ? $_[0] : '(eof)';
    },
  );
  $cmd->start->then (sub {
    my $r = $_[0];
    test {
      is $r->exit_code, 0;
      ok ! $r->is_error;
    } $c;
    return $cmd->stop;
  })->then (sub {
    my $r = $_[0];
    test {
      is $r->exit_code, 0;
      ok ! $r->is_error;
      is $logs, "abc\x0D\x0Axyz\x0D\x0A(eof)"; # \x0D inserted by Docker
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 5, name => 'logs subroutine';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
