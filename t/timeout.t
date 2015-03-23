use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Promised::Command;
use Promise;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['sleep', 3]);
  $cmd->timeout (0.5);
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
  $cmd->timeout (0.5);
  $cmd->timeout_signal ('INT');
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
  $cmd->timeout (1);
  $cmd->run->then (sub {
    $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      ok $result->is_success;
      is $result->exit_code, 0;
      is $result->signal, undef;
    } $c;
  }, sub { test { ok 0 } $c })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'exit before timeout';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
