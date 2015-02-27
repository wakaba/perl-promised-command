package Promised::Command;
use strict;
use warnings;
our $VERSION = '1.0';
use Promise;
use AnyEvent;
use AnyEvent::Util qw(run_cmd);

sub new ($$) {
  my $self = bless {args => []}, $_[0];
  ($self->{command}, @{$self->{args}}) = @{$_[1]};
  return $self;
} # new

sub wd ($;$) {
  if (@_ > 1) {
    $_[0]->{wd} = $_[1];
  }
  return $_[0]->{wd};
} # wd

sub envs ($) {
  return $_[0]->{envs} ||= {};
} # envs

sub create_process_group ($;$) {
  if (@_ > 1) {
    $_[0]->{create_process_group} = $_[1];
  }
  return $_[0]->{create_process_group};
} # create_process_group

sub stdin ($;$) {
  if (@_ > 1) {
    $_[0]->{stdin} = $_[1];
  }
  die "Not implemented" if defined wantarray;
} # stdin

sub stdout ($;$) {
  if (@_ > 1) {
    $_[0]->{stdout} = $_[1];
  }
  die "Not implemented" if defined wantarray;
} # stdout

sub stderr ($;$) {
  if (@_ > 1) {
    $_[0]->{stderr} = $_[1];
  }
  die "Not implemented" if defined wantarray;
} # stderr

sub propagate_signal ($;$) {
  if (@_ > 1) {
    $_[0]->{propagate_signal} = $_[1];
  }
  return $_[0]->{propagate_signal};
} # propagate_signal

sub _r (@) {
  return bless {@_}, __PACKAGE__.'::Result';
} # _r

sub run ($) {
  my $self = $_[0];
  return Promise->reject (_r is_error => 1, message => "|run| already invoked")
      if defined $self->{wait_promise};
  $self->{running} = 1;
  $self->{wait_promise} = Promise->new (sub {
    my ($ok, $ng) = @_;
    my %args = ('$$' => \($self->{pid}), on_prepare => sub {
      setpgrp if $self->{create_process_group};
      chdir $self->{wd} or die "Can't change working directory to |$self->{wd}|"
          if defined $self->{wd};
      my $envs = $self->{envs} || {};
      for (keys %$envs) {
        if (defined $envs->{$_}) {
          $ENV{$_} = $envs->{$_};
        } else {
          delete $ENV{$_};
        }
      }
    });
    $args{'<'} = $self->{stdin} if defined $self->{stdin};
    $args{'>'} = $self->{stdout} if defined $self->{stdout};
    $args{'2>'} = $self->{stderr} if defined $self->{stderr};
    if ($self->{propagate_signal}) {
      for my $sig (ref $self->{propagate_signal}
                       ? @{$self->{propagate_signal}}
                       : qw(INT TERM QUIT)) {
        $self->{signal_handlers}->{$sig} = AE::signal $sig => sub {
          kill $sig, $self->{pid} if $self->{running};
        };
      }
    }
    (run_cmd [$self->{command}, @{$self->{args}}], %args)->cb (sub {
      my $result = $_[0]->recv;
      delete $self->{running};
      delete $self->{signal_handlers};
      if ($result & 0x7F) {
        $ng->(_r core_dump => !!($result & 0x80), signal => $result & 0x7F);
      } else {
        $ok->(_r exit_code => $result >> 8);
      }
    });
  });
  return Promise->resolve (_r);
} # run

sub pid ($) {
  return $_[0]->{pid} || die _r is_error => 1, message => "Not yet |run|";
} # pid

sub running ($) {
  return !!$_[0]->{running};
} # running

sub wait ($) {
  return $_[0]->{wait_promise} || Promise->reject (_r is_error => 1, message => "Not yet |run|");
} # wait

sub send_signal ($$) {
  my ($self, $signal) = @_;
  return Promise->new (sub {
    my $pid = $self->pid;
    if ($self->running) {
      $_[0]->(_r killed => kill $signal, $pid);
    } else {
      $_[0]->(_r killed => 0);
    }
  });
} # send_signal

package Promised::Command::Result;
use overload '""' => 'stringify', fallback => 1;

sub is_success ($) {
  return not $_[0]->{is_error};
} # is_success

sub is_error ($) {
  return $_[0]->{is_error};
} # is_error

sub signal ($) { $_[0]->{signal} }
sub core_dump ($) { $_[0]->{core_dump} }
sub exit_code ($) { defined $_[0]->{exit_code} ? $_[0]->{exit_code} : -1 }
sub message ($) { $_[0]->{message} }
sub killed ($) { $_[0]->{killed} }

sub stringify ($) {
  if ($_[0]->{is_error}) {
    return "Error: $_[0]->{message}";
  } elsif (defined $_[0]->{signal}) {
    return sprintf "Exit with signal %d%s",
        $_[0]->{signal}, $_[0]->{core_dump} ? ' with core dump' : '';
  } elsif (defined $_[0]->{exit_code}) {
    return sprintf "Exit code %d", $_[0]->{exit_code};
  } else {
    return 'Success';
  }
} # stringify

1;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
