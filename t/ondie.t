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
  my $timer; $timer = AE::timer 1, 0, sub {
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
  $cmd->run->then (sub {
    my $child_pid;
    my $timer; $timer = AE::timer 2, 0, sub {
      test {
        $child_pid = $cmd->pid;
        kill -2, getpgrp $child_pid;
        undef $timer;
      } $c;
    };
    return $cmd->wait->catch (sub { })->then (sub {
      return Promise->new (sub {
        my $ok = $_[0];
        my $timer; $timer = AE::timer 0.5, 0, sub {
          $ok->();
          undef $timer;
        };
      })->then (sub {
        test {
          my $grandchild_pid = $stdout;
          ok not kill 0, $child_pid;
          ok not kill 0, $grandchild_pid;
        } $c;
      });
    });
  })->catch (sub {
    my $error = $_[0];
    test {
      ok 0, $error;
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
        ->then (sub { syswrite STDOUT, "pid=" . $cmd->pid . "\n" })
        ->then (sub { $cmd->wait })
        ->catch (sub { })
        ->then (sub { $cv->send });
    $cv->recv;
  }]);
  $cmd->stdout (\my $stdout);
  $cmd->create_process_group (1);
  $cmd->run;

  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $time = 0;
    my $timer; $timer = AE::timer 0, 0.5, sub {
      if (defined $stdout and $stdout =~ /^pid=(\w+)$/m) {
        $ok->($1);
        undef $timer;
      } else {
        $time += 0.5;
        if ($time > 30) {
          $ng->("timeout");
          undef $timer;
        }
      }
    };
  })->then (sub {
    my $grandchild_pid = $_[0];
    my $child_pid;
    my $timer; $timer = AE::timer 1, 0, sub {
      test {
        $child_pid = $cmd->pid;
        kill -2, getpgrp $child_pid;
        undef $timer;
      } $c;
    };
    my $timer2; $timer2 = AE::timer 2, 0, sub {
      test {
        ok not kill 0, $child_pid;
        ok kill 0, $grandchild_pid;
        kill 2, $grandchild_pid;
        undef $timer2;
      } $c;
    };
    return $cmd->wait->catch (sub { })->then (sub {
      test {
        ok not kill 0, $child_pid;
        ok not kill 0, $grandchild_pid;
      } $c;
    }, sub {
      my $error = $_[0];
      test {
        ok 0;
      } $c;
    });
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    my $cv = AE::cv;
    use Promised::Command;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      sleep 100;
    }]);
    $cmd->run
        ->then (sub { syswrite STDOUT, "pid=" . $cmd->pid . "\n" })
        ->then (sub { $cmd->wait })
        ->catch (sub { })
        ->then (sub { $cv->send });
    $cv->recv;
  }]);
  $cmd->stdout (\my $stdout);
  $cmd->run;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $time = 0;
    my $timer; $timer = AE::timer 0, 0.5, sub {
      if (defined $stdout and $stdout =~ /^pid=(\w+)$/m) {
        $ok->($1);
        undef $timer;
      } else {
        $time += 0.5;
        if ($time > 30) {
          $ng->("timeout");
          undef $timer;
        }
      }
    };
  })->then (sub {
    my $grandchild_pid = $_[0];
    my $child_pid;
    my $timer; $timer = AE::timer 1, 0, sub {
      test {
        $child_pid = $cmd->pid;
        kill 2, $child_pid;
        undef $timer;
      } $c;
    };
    my $timer2; $timer2 = AE::timer 2, 0, sub {
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
    });
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4;

for my $sig (2, 3, 15) {
  test {
    my $c = shift;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      use AnyEvent;
      my $cv = AE::cv;
      use Promised::Command;
      my $cmd = Promised::Command->new (['perl', '-e', q{
        sleep 100;
      }]);
      $cmd->propagate_signal (1);
      $cmd->run
          ->then (sub { syswrite STDOUT, $cmd->pid })
          ->then (sub { $cmd->wait })
          ->catch (sub { })
          ->then (sub { $cv->send });
      $cv->recv;
    }]);
    $cmd->stdout (\my $grandchild_pid);
    $cmd->run;
    my $child_pid;
    my $timer; $timer = AE::timer 1, 0, sub {
      test {
        $child_pid = $cmd->pid;
        kill $sig, $child_pid;
        undef $timer;
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
  } n => 2;
}

for my $sig ('HUP') {
  test {
    my $c = shift;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      use AnyEvent;
      my $cv = AE::cv;
      use Promised::Command;
      my $cmd = Promised::Command->new (['perl', '-e', q{
        sleep 100;
      }]);
      $cmd->propagate_signal (['HUP']);
      $cmd->run
          ->then (sub { syswrite STDOUT, $cmd->pid })
          ->then (sub { $cmd->wait })
          ->catch (sub { })
          ->then (sub { $cv->send });
      $cv->recv;
    }]);
    $cmd->stdout (\my $grandchild_pid);
    $cmd->run;
    my $child_pid;
    my $timer; $timer = AE::timer 1.5, 0, sub {
      test {
        $child_pid = $cmd->pid;
        kill $sig, $child_pid;
        undef $timer;
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
  } n => 2;
}

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command;
    my $cv = AE::cv;
    my $cmd = Promised::Command->new (['sleep', 100]);
    $cmd->run->then (sub { syswrite STDOUT, $cmd->pid; $cv->send });
    $cv->recv;
  }]);
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      my $timer; $timer = AE::timer 1, 0, sub {
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    test {
      ok kill 'INT', $stdout;
      like $stderr, qr{Promised::Command.+to be destroyed};
    } $c;
  })->catch (sub { test { ok 0 } $c; warn $_[0] })->then (sub {
    return $cmd->wait;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 2;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      $SIG{INT} = sub { syswrite STDOUT, "SIGINT\n" };
      sleep 10;
    }]);
    $cmd->signal_before_destruction ('INT');
    my $cv = AE::cv;
    $cmd->run->then (sub {
      my $timer; $timer = AE::timer 1, 0, sub {
        $cv->send;
        undef $timer;
      };
    });
    $cv->recv;
  }]);
  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    $cmd->wait->then (sub {
      test {
        is $stdout, "SIGINT\n";
        like $stderr, qr{ is to be destroyed while the command \(perl\) is still running };
      } $c;
      done $c;
      undef $c;
    });
  });
} n => 2, name => 'signal_before_destruction';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
