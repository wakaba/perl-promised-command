use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use AnyEvent;
use Promised::Command;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    my $cv = AE::cv;
    use Promised::Command;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      sleep 100;
    }]);
    $cmd->create_process_group (1);
    my $sig; $sig = AE::signal INT => sub {
      $cmd->send_signal ('INT');
      undef $sig;
    };
    $cmd->run
        ->then (sub { syswrite STDOUT, $cmd->pid })
        ->then (sub { $cmd->wait })
        ->catch (sub { })
        ->then (sub { $cv->send });
    $cv->recv;
  }]);
  $cmd->create_process_group (1);
  $cmd->stdout (\my $stdout);
  $cmd->run;
  my $timer; $timer = AE::timer 0.5, 0, sub {
    $cmd->send_signal ('INT');
    undef $timer;
  };
  $cmd->wait->then (sub {
    test {
      my $pid = $stdout;
      ok not kill 0, $pid;
    } $c;
  }, sub {
    my $error = $_[0];
    test {
      ok $error->is_success;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    my $cv = AE::cv;
    use Promised::Command;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      sleep 100;
    }]);
    #$cmd->create_process_group (1);
    $cmd->run
        ->then (sub { syswrite STDOUT, $cmd->pid })
        ->then (sub { $cmd->wait })
        ->catch (sub { })
        ->then (sub { $cv->send });
    $cv->recv;
  }]);
  $cmd->stdout (\my $stdout);
  $cmd->create_process_group (1);
  $cmd->run;
  my $child_pid;
  my $timer; $timer = AE::timer 0.5, 0, sub {
    test {
      $child_pid = $cmd->pid;
      kill -2, getpgrp $child_pid;
      undef $timer;
    } $c;
  };
  $cmd->wait->catch (sub { })->then (sub {
    test {
      my $grandchild_pid = $stdout;
      ok not kill 0, $child_pid;
      ok not kill 0, $grandchild_pid;
    } $c;
  }, sub {
    my $error = $_[0];
    test {
      ok 0;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 2;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    my $cv = AE::cv;
    use Promised::Command;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      sleep 100;
    }]);
    $cmd->create_process_group (1);
    $cmd->run
        ->then (sub { syswrite STDOUT, $cmd->pid })
        ->then (sub { $cmd->wait })
        ->catch (sub { })
        ->then (sub { $cv->send });
    $cv->recv;
  }]);
  $cmd->stdout (\my $grandchild_pid);
  $cmd->create_process_group (1);
  $cmd->run;
  my $child_pid;
  my $timer; $timer = AE::timer 0.3, 0, sub {
    test {
      $child_pid = $cmd->pid;
      kill -2, getpgrp $child_pid;
      undef $timer;
    } $c;
  };
  my $timer2; $timer2 = AE::timer 0.6, 0, sub {
    test {
      ok not kill 0, $child_pid;
      ok kill 0, $grandchild_pid;
      kill 2, $grandchild_pid;
      undef $timer2;
    } $c;
  };
  $cmd->wait->catch (sub { })->then (sub {
    test {
      ok not kill 0, $child_pid;
      ok not kill 0, $grandchild_pid;
    } $c;
  }, sub {
    my $error = $_[0];
    test {
      ok 0;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4;

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
