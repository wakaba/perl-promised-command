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
  my $cmd = Promised::Command->new (['true']);
  my $p1 = $cmd->run;
  isa_ok $p1, 'Promise';
  $p1->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      ok $cmd->pid;
      done $c;
      undef $c;
    } $c;
  });
} n => 4;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['true']);
  $cmd->run;
  my $p2 = $cmd->wait;
  isa_ok $p2, 'Promise';
  $p2->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      ok $cmd->pid;
      ok not $cmd->running;
      done $c;
      undef $c;
    } $c;
  });
} n => 5;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['true']);
  my $p1 = $cmd->run->then (sub { $cmd->wait });
  isa_ok $p1, 'Promise';
  $p1->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      ok $cmd->pid;
      ok not $cmd->running;
      done $c;
      undef $c;
    } $c;
  });
} n => 5;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['false']);
  my $p1 = $cmd->run->then (sub { $cmd->wait });
  isa_ok $p1, 'Promise';
  $p1->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      ok $cmd->pid;
      ok not $cmd->running;
      done $c;
      undef $c;
    } $c;
  });
} n => 5;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['sleep', 1]);
  Promise->all ([
    $cmd->run->then (sub {
      my $result = $_[0];
      test {
        isa_ok $result, 'Promised::Command::Result';
        ok $result->is_success;
        ok $cmd->pid;
        ok $cmd->running;
      } $c;
    }),
    $cmd->wait->then (sub {
      my $result = $_[0];
      test {
        isa_ok $result, 'Promised::Command::Result';
        ok $result->is_success;
        ok $cmd->pid;
        ok not $cmd->running;
      } $c;
    }),
  ])->then (sub {
    done $c;
    undef $c;
  });
} n => 8;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['hogefuga' . rand]);
  $cmd->run->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      ok $cmd->pid;
      #ok not $cmd->running;
    } $c;
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      ok $result->exit_code;
      ok $cmd->pid;
      ok not $cmd->running;
      done $c;
      undef $c;
    } $c;
  });
} n => 8, name => 'bad command';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['ls']);
  my $p = $cmd->wait;
  isa_ok $p, 'Promise';
  $p->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_error;
      is $result->message, 'Not yet |run|';
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4, name => 'wait before run';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['ls']);
  $cmd->run;
  my $p = $cmd->run;
  isa_ok $p, 'Promise';
  $p->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_error;
      is $result->message, '|run| already invoked';
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 4, name => 'multiple runs';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['ls']);
  $cmd->run;
  my $result0;
  $cmd->wait->then (sub {
    $result0 = $_[0];
  });
  $cmd->wait->then (sub {
    my $result = $_[0];
    test {
      ok $result;
      is $result, $result0;
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'multiple waits';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['ls']);
  eval {
    $cmd->pid;
  };
  my $e = $@;
  isa_ok $e, 'Promised::Command::Result';
  ok $e->is_error;
  is $e->message, 'Not yet |run|';
  done $c;
} n => 3, name => 'pid before run';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{sleep 2}]);
  $cmd->run->then (sub {
    return $cmd->send_signal ('INT');
  })->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      is $result->killed, 1;
    } $c;
    return $cmd->wait;
  })->catch (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_error;
      is $result->signal, 2;
      ok not $result->core_dump;
      is $result->exit_code, -1;
      ok ''.$result;
      done $c;
      undef $c;
    } $c;
  });
} n => 9, name => 'killed';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{sleep 2}]);
  $cmd->run->then (sub {
    return $cmd->send_signal (2);
  })->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      is $result->killed, 1;
    } $c;
    return $cmd->wait;
  })->catch (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_error;
      is $result->signal, 2;
      ok not $result->core_dump;
      is $result->exit_code, -1;
      ok ''.$result;
      done $c;
      undef $c;
    } $c;
  });
} n => 9, name => 'killed';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['true']);
  $cmd->run->then (sub {
    return $cmd->send_signal (0);
  })->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      is $result->killed, 1;
    } $c;
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      is $result->signal, undef;
      is $result->exit_code, 0;
      done $c;
      undef $c;
    } $c;
  });
} n => 7, name => 'not killed';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['true']);
  $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    return $cmd->send_signal ('INT');
  })->then (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_success;
      is $result->killed, 0;
      done $c;
      undef $c;
    } $c;
  });
} n => 3, name => 'killed count = 0 (not running)';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['ls']);
  $cmd->send_signal (9)->catch (sub {
    my $result = $_[0];
    test {
      isa_ok $result, 'Promised::Command::Result';
      ok $result->is_error;
      is $result->message, 'Not yet |run|';
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'send_signal before run';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command;
    my $cv = AE::cv;
    my $cmd = Promised::Command->new (['perl', '-e', q{
      $SIG{TERM} = sub { warn "SIGTERM\n"; exit };
      $SIG{INT} = sub { warn "SIGINT\n"; exit };
      warn "started\n";
      sleep 30;
    }]);
    $cmd->propagate_signal ([[INT => 'TERM']]);
    $cmd->run->then (sub { $cmd->wait })->then (sub { warn "child done"; $cv->send });
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my ($ok, $ng) = @_;
      my $timer; $timer = AE::timer 0, 0.1, sub {
        if (defined $stderr and $stderr =~ /^started$/m) {
          $ok->();
          undef $timer;
        }
      };
    });
  })->then (sub {
    return $cmd->send_signal ('INT');
  })->then (sub { return $cmd->wait })->catch (sub { warn $_[0] })->then (sub {
    test {
      like $stderr, qr{started\n.*SIGINT received\nSIGTERM\n.*terminated by SIGINT}s;
    } $c;
    done $c;
    undef $c;
  });
} n => 1, name => 'propagate_signal replacing';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
