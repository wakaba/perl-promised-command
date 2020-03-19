use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Promised::Command;
use Promise;
use Promised::Flow;
use AbortController;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['sleep', 3]);
  my $ac = new AbortController;
  $cmd->abort_signal ($ac->signal);
  promised_sleep (0.5)->then (sub { $ac->abort });
  $cmd->run->then (sub {
    $cmd->wait;
  })->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $result = $_[0];
    test {
      ok $result->is_error;
      is $result->exit_code, -1;
      is $result->signal, 15, 'SIGTERM';
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'default signal';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['sleep', 3]);
  $cmd->timeout_signal ('INT');
  my $ac = new AbortController;
  $cmd->abort_signal ($ac->signal);
  promised_sleep (0.5)->then (sub { $ac->abort });
  $cmd->run->then (sub {
    $cmd->wait;
  })->then (sub {
    test { ok 0 } $c;
  }, sub {
    my $result = $_[0];
    test {
      ok $result->is_error;
      is $result->exit_code, -1;
      is $result->signal, 2, 'SIGINT';
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'non-default signal';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['true']);
  my $ac = new AbortController;
  $cmd->abort_signal ($ac->signal);
  my $p = promised_sleep (1)->then (sub { $ac->abort });
  $cmd->run->then (sub {
    $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    return $p->then (sub {
      test {
        ok $result->is_success;
        is $result->exit_code, 0;
        is $result->signal, undef;
      } $c;
    });
  }, sub { test { ok 0 } $c })->then (sub {
    done $c;
    undef $c;
    undef $ac;
  });
} n => 3, name => 'exit before timeout';

run_tests;

=head1 LICENSE

Copyright 2015-2020 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
