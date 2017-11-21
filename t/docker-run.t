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
    my $r = $_[0];
    test {
      is $r->exit_code, 0;
      ok ! $r->is_error;
    } $c;
    return $cmd->stop;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 2, name => 'start stop';

test {
  my $c = shift;
  my $cmd = Promised::Command::Docker->new;
  $cmd->docker ($Docker);
  $cmd->image ('debian:sid');
  $cmd->command (['sleep', 3]);
  $cmd->start->then (sub {
    my $r = $_[0];
    test {
      is $r->exit_code, 0;
      ok ! $r->is_error;
    } $c;
    return $cmd->stop;
  })->catch (sub {
    warn $_[0];
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 2, name => 'start stop, method inputs';

test {
  my $c = shift;
  my $cmd = Promised::Command::Docker->new (
    docker => $Docker,
    command => ['sleep', 100],
  );
  $cmd->start->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $r = $_[0];
    test {
      ok $r->is_error;
      is $r->exit_code, -1;
      is $r->message, '|image| is not specified';
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'start failed - no image';

test {
  my $c = shift;
  my $cmd = Promised::Command::Docker->new (
    docker => $Docker,
    image => 'debian:sid',
    command => ['sleep', 1],
  );
  $cmd->start->then (sub {
    return $cmd->start;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $r = $_[0];
    test {
      is $r->exit_code, -1;
      ok $r->is_error;
      is $r->message, '|start| already invoked';
    } $c;
    return $cmd->stop;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'start - duplicate start';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
