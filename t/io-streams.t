use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
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

#XXX
test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'while (<>) { print }']);
  $cmd->stdin (\"ab \x00\x81");
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x00\x81";
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'stdin ref';

run_tests;

=head1 LICENSE

Copyright 2015-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
