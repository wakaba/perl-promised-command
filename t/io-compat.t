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
  my $cmd = Promised::Command->new (['echo', "abcd aa\xFE\xA0a"]);
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "abcd aa\xFE\xA0a\x0A";
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'stdout ref';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['echo', "abcd aa\xFE\xA0a"]);
  my @stdout;
  $cmd->stdout (sub { push @stdout, defined $_[0] ? $_[0] : '[undef]' });
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is join ('', @stdout), "abcd aa\xFE\xA0a\x0A[undef]";
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'stdout code';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'print "abcd aa\xFE\xA0a"; print STDERR "ab\xFE"']);
  $cmd->stderr (\my $stderr);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stderr, "ab\xFE";
    } $c;
  }, sub {
    test {
      ok 0;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => 'stderr ref';

test {
  my $c = shift;
  my $cmd = Promised::Command->new (['perl', '-e', 'print STDERR "abcd aa\xFE\xA0a"']);
  my @stderr;
  $cmd->stderr (sub { push @stderr, defined $_[0] ? $_[0] : '[undef]' });
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is join ('', @stderr), "abcd aa\xFE\xA0a[undef]";
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'stderr code';

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

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
