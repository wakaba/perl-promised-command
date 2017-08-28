use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use ArrayBuffer;
use DataView;
use Promised::Command;
use Promised::Flow;

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['echo', "abcd aa\xFE\xA0a"]);
  my $rs = $cmd->get_stdout_stream;
  isa_ok $rs, 'ReadableStream';
  my $bytes = '';
  my $reader = $rs->get_reader ('byob');
  my $read; $read = sub {
    return $reader->read (DataView->new (ArrayBuffer->new (2)))->then (sub {
      return if $_[0]->{done};
      $bytes .= $_[0]->{value}->manakai_to_string;
      return $read->();
    });
  }; # $read
  my $p = promised_cleanup { undef $read } $read->();
  $cmd->run;
  $cmd->wait->then (sub {
    return $p;
  })->then (sub {
    test {
      is $bytes, "abcd aa\xFE\xA0a\x0A";
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'stdout stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', q{
    syswrite STDOUT, "abcd a";
    sleep 1;
    syswrite STDOUT, "a\xFE\xA0a";
  }]);
  my $rs = $cmd->get_stdout_stream;
  isa_ok $rs, 'ReadableStream';
  my $bytes = '';
  my $reader = $rs->get_reader ('byob');
  my $read; $read = sub {
    return $reader->read (DataView->new (ArrayBuffer->new (2)))->then (sub {
      return if $_[0]->{done};
      $bytes .= $_[0]->{value}->manakai_to_string;
      return $read->();
    });
  }; # $read
  my $p = promised_cleanup { undef $read } $read->();
  $cmd->run;
  $cmd->wait->then (sub {
    return $p;
  })->then (sub {
    test {
      is $bytes, "abcd aa\xFE\xA0a";
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'stdout stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['echo', "abcd aa\xFE\xA0a"]);
  my $rs = $cmd->get_stdout_stream;
  isa_ok $rs, 'ReadableStream';
  my $bytes = '';
  my $reader = $rs->get_reader ('byob');
  my $read; $read = sub {
    return $reader->read (DataView->new (ArrayBuffer->new (2)))->then (sub {
      return if $_[0]->{done};
      $bytes .= $_[0]->{value}->manakai_to_string;
      $reader->cancel;
      return $read->();
    });
  }; # $read
  my $p = promised_cleanup { undef $read } $read->();
  $cmd->run;
  $cmd->wait->then (sub {
    return $p;
  })->then (sub {
    test {
      is $bytes, "ab";
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'stdout stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'print "abcd aa\xFE\xA0a\x0A"; print STDERR "ab\xFE"']);
  my $rs = $cmd->get_stderr_stream;
  isa_ok $rs, 'ReadableStream';
  my $bytes = '';
  my $reader = $rs->get_reader ('byob');
  my $read; $read = sub {
    return $reader->read (DataView->new (ArrayBuffer->new (2)))->then (sub {
      return if $_[0]->{done};
      $bytes .= $_[0]->{value}->manakai_to_string;
      return $read->();
    });
  }; # $read
  my $p = promised_cleanup { undef $read } $read->();
  $cmd->run;
  $cmd->wait->then (sub {
    return $p;
  })->then (sub {
    test {
      is $bytes, "ab\xFE";
    } $c;
  }, sub {
    test {
      ok 0;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 2, name => 'stderr stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'print "abcd aa\xFE\xA0a\x0A"; print STDERR "db\xFE"']);
  my $rs = $cmd->get_stderr_stream;
  isa_ok $rs, 'ReadableStream';
  my $bytes = '';
  my $reader = $rs->get_reader ('byob');
  my $read; $read = sub {
    return $reader->read (DataView->new (ArrayBuffer->new (2)))->then (sub {
      return if $_[0]->{done};
      $bytes .= $_[0]->{value}->manakai_to_string;
      $reader->cancel;
      return $read->();
    });
  }; # $read
  my $p = promised_cleanup { undef $read } $read->();
  $cmd->run;
  $cmd->wait->then (sub {
    return $p;
  })->then (sub {
    test {
      is $bytes, "db";
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'stderr stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  my $ws = $cmd->get_stdin_stream;
  isa_ok $ws, 'WritableStream';
  my $writer = $ws->get_writer;
  $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"ab \x00\x81")));
  $writer->close;
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x00\x81";
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'stdin stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  my $ws = $cmd->get_stdin_stream;
  isa_ok $ws, 'WritableStream';
  my $writer = $ws->get_writer;
  $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"ab \x00\x81")));
  $cmd->stdout (\my $stdout);
  $cmd->run->then (sub {
    $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"")))->then (sub {
      $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"\x81")));
      $writer->close;
    });
  });
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x00\x81\x81";
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'stdin stream';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  my $ws = $cmd->get_stdin_stream;
  isa_ok $ws, 'WritableStream';
  my $writer = $ws->get_writer;
  $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"ab \x00\x81")));
  my $p = $writer->write ("abc");
  my $q = $writer->close;
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x00\x81";
    } $c;
    return $p;
  })->catch (sub {
    my $error = $_[0];
    test {
      is $error->name, 'TypeError', $error;
      is $error->message, 'The argument is not an ArrayBufferView';
      is $error->file_name, __FILE__;
      is $error->line_number, __LINE__-19;
    } $c;
    return $q->catch (sub {
      my $e = $_[0];
      test {
        is $e, $error;
      } $c;
    });
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 7, name => 'stdin bad write argument';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  my $ws = $cmd->get_stdin_stream;
  isa_ok $ws, 'WritableStream';
  my $writer = $ws->get_writer;
  $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"ab \x00\x81")));
  my $v = DataView->new (ArrayBuffer->new_from_scalarref (\"abc"));
  $v->buffer->_transfer; # detach
  my $p = $writer->write ($v);
  my $q = $writer->close;
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x00\x81";
    } $c;
    return $p;
  })->catch (sub {
    my $error = $_[0];
    test {
      is $error->name, 'TypeError', $error;
      is $error->message, 'ArrayBuffer is detached';
      is $error->file_name, __FILE__;
      is $error->line_number, __LINE__-21;
    } $c;
    return $q->catch (sub {
      my $e = $_[0];
      test {
        is $e, $error;
      } $c;
    });
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 7, name => 'stdin detached';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  my $ws = $cmd->get_stdin_stream;
  isa_ok $ws, 'WritableStream';
  my $writer = $ws->get_writer;
  $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\"ab \x00\x81")));
  my $v = DataView->new (ArrayBuffer->new_from_scalarref (\"abc"));
  $v->buffer->_transfer; # detach
  my $p = $writer->write ($v);
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x00\x81";
    } $c;
    return $p;
  })->catch (sub {
    my $error = $_[0];
    test {
      is $error->name, 'TypeError', $error;
      is $error->message, 'ArrayBuffer is detached';
      is $error->file_name, __FILE__;
      is $error->line_number, __LINE__-20;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 6, name => 'stdin detached (no close)';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  my $rs = $cmd->get_stdout_stream;
  my $ws = $cmd->get_stdin_stream;

  my $writer = $ws->get_writer;
  my $data = '';
  my $value = '';
  promised_wait_until {
    my $v = 't3aqgawg' x (1024*10);
    $data .= $v;
    return $writer->write (DataView->new (ArrayBuffer->new_from_scalarref (\$v)))->then (sub {
      if (length $data > 1024*1024) {
        $writer->close;
        return 1;
      } else {
        return 0;
      }
    });
  } interval => 0.001;
  my $p = $writer->closed->then (sub {
    my $reader = $rs->get_reader ('byob');
    my $read; $read = sub {
      return $reader->read (DataView->new (ArrayBuffer->new (1024)))->then (sub {
        return if $_[0]->{done};
        $value .= $_[0]->{value}->manakai_to_string;
        return $read->();
      });
    }; # $read
    return promised_cleanup { undef $read } $read->();
  })->then (sub {
    test {
      is $value, $data;
    } $c;
  });

  $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    return $p;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'stdin stdout large data';

run_tests;

=head1 LICENSE

Copyright 2015-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
