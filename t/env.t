use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Promised::Command;
use Cwd qw(getcwd);

test {
  my $c = shift;
  my $cwd = getcwd;
  my $cmd = Promised::Command->new (['pwd']);
  $cmd->wd ('/tmp');
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      like $stdout, qr{\A(?:/private|)/tmp\x0A\z}; # /private/tmp in Mac OS X
      is getcwd, $cwd;
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'wd';

test {
  my $c = shift;
  my $cwd = getcwd;
  my $cmd = Promised::Command->new (['pwd']);
  $cmd->wd ('/tmp/' . rand);
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    my $result = $_[0];
    test {
      ok $result->exit_code;
      is $stdout, "";
      is getcwd, $cwd;
      done $c;
      undef $c;
    } $c;
  });
} n => 3, name => 'wd bad directory';

test {
  my $c = shift;
  my $cwd = getcwd;
  my $cmd = Promised::Command->new (['perl', '-e', 'print $ENV{HOGE}']);
  $cmd->envs->{HOGE} = "ab \x01 \xFE\xA0";
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "ab \x01 \xFE\xA0";
      is $ENV{HOGE}, undef;
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'envs';

test {
  my $c = shift;
  my $cwd = getcwd;
  my $cmd = Promised::Command->new (['perl', '-e', 'print defined $ENV{LANG} ? $ENV{LANG} : "[[undef]]"']);
  $cmd->envs->{LANG} = undef;
  $cmd->stdout (\my $stdout);
  $cmd->run;
  $cmd->wait->then (sub {
    test {
      is $stdout, "[[undef]]";
      ok $ENV{LANG};
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'envs = undef';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
