package Promised::Command;
use strict;
use warnings;
our $VERSION = '1.0';
use Promise;
use AnyEvent::Util qw(run_cmd);

sub new ($$) {
  my $self = bless {args => []}, $_[0];
  ($self->{command}, @{$self->{args}}) = @{$_[1]};
  return $self;
} # new

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
    (run_cmd [$self->{command}, @{$self->{args}}], '$$' => \($self->{pid}))->cb (sub {
      my $result = $_[0]->recv;
      delete $self->{running};
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
