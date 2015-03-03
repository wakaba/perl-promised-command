use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Promised::Command;
use AnyEvent;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigterm received!\n";
    };
    my $sig = Promised::Command::Signals->add_handler (TERM => $code);
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'TERM', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{sigterm received!\n.*SIGTERM received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'has handler';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigterm received!\n";
    };
    my $sig = Promised::Command::Signals->add_handler (TERM => $code);
    Promised::Command::Signals->_remove_handler (TERM => $code);
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'TERM', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $result = $_[0];
    test {
      is $result->signal, 15;
      unlike $stderr, qr{sigterm};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'handler removed';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigterm received!\n";
    };
    my $sig = Promised::Command::Signals->add_handler (TERM => $code);
    undef $sig;
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'TERM', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    test {
      ok 0;
    } $c;
  }, sub {
    my $result = $_[0];
    test {
      is $result->signal, 15;
      unlike $stderr, qr{sigterm};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'handler destroyed';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigint received 1\n";
    };
    my $code2 = sub {
      warn "sigint received 2\n";
    };
    my $sig1 = Promised::Command::Signals->add_handler (INT => $code);
    my $sig2 = Promised::Command::Signals->add_handler (INT => $code2);
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'INT', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{(?:sigint received 1\nsigint received 2\n|sigint received 2\nsigint received 1\n).*SIGINT received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'has multiple handlers';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigint received 1\n";
    };
    my $code2 = sub {
      warn "sigint received 2\n";
    };
    my $sig1 = Promised::Command::Signals->add_handler (INT => $code);
    my $sig2 = Promised::Command::Signals->add_handler (INT => $code2);
    undef $sig1;
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'INT', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{sigint received 2\n.*SIGINT received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'has some handler';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promise;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigquit received!\n";
      return Promise->new (sub {
        my $ok = $_[0];
        my $timer; $timer = AE::timer 0.1, 0, sub {
          $ok->();
          undef $timer;
        };
      })->then (sub {
        warn "sigquit promise resolved\n";
      });
    };
    my $sig = Promised::Command::Signals->add_handler (QUIT => $code);
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'QUIT', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{sigquit received!\nsigquit promise resolved\n.*SIGQUIT received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'has promised handler';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      die "sigterm received!";
    };
    my $sig = Promised::Command::Signals->add_handler (TERM => $code);
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'TERM', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{Died within signal handler: sigterm received! at .+\n.*SIGTERM received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'died in handler';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promise;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      return Promise->reject ("sigterm received!");
    };
    my $sig = Promised::Command::Signals->add_handler (TERM => $code);
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'TERM', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{Died within signal handler: sigterm received!\n.*SIGTERM received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'rejected in handler';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    use AnyEvent;
    use Promised::Command::Signals;
    my $cv = AE::cv;
    my $code = sub {
      warn "sigterm received!\n";
      $_[0]->();
    };
    my $sig = Promised::Command::Signals->add_handler (TERM => $code);
    my $sig2 = Promised::Command::Signals->add_handler (INT => sub {
      warn "sigint received\n";
    });
    $cv->recv;
  }]);
  $cmd->stderr (\my $stderr);
  $cmd->run->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'TERM', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return Promise->new (sub {
      my $ok = $_[0];
      my $timer; $timer = AE::timer 0.5, 0, sub {
        kill 'INT', $cmd->pid;
        $ok->();
        undef $timer;
      };
    });
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    test {
      is $result->exit_code, 1;
      like $stderr, qr{sigterm received!\nsigint received\n.*SIGINT received};
    } $c;
    done $c;
    undef $c;
  });
} n => 2, name => 'has handler, canceled';

run_tests;
