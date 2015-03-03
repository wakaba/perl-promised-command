package Promised::Command::Signals;
use strict;
use warnings;
our $VERSION = '1.0';
use AnyEvent;
use Promise;

my $Sig = {};
my $Handlers = {};

our $Action = {
  HUP => 'die',
  INT => 'die',
  QUIT => 'die',
  TERM => 'die',
};

sub add_handler ($$$) {
  my (undef, $signal, $code) = @_;
  return if $Handlers->{$signal}->{$code};
  unless (keys %{$Handlers->{$signal} or {}}) {
    $Sig->{$signal} = AE::signal $signal => sub {
      my $canceled;
      my $cancel = sub { $canceled = 1 };
      Promise->all ([
        map { my $code; Promise->new (sub { $_[0]->($_->($cancel)) }) } values %{$Handlers->{$signal} or {}},
      ])->catch (sub {
        AE::log alert => "Died within signal handler: $_[0]";
      })->then (sub {
        return if $canceled;
        my $action = $Action->{$signal} || 'die';
        unless ($action eq 'ignore') {
          AE::log alert => "SIG$signal received";
          exit 1;
        }
      });
    };
  }
  $Handlers->{$signal}->{$code} = $code;
  return bless [$signal, $code], 'Promised::Command::Signals::Handler';
} # add_handler

sub _remove_handler ($$$) {
  my (undef, $signal, $code) = @_;
  delete $Handlers->{$signal}->{$code};
  delete $Sig->{$signal} unless keys %{$Handlers->{$signal}};
} # _remove_handler

package Promised::Command::Signals::Handler;

sub DESTROY ($) {
  Promised::Command::Signals->_remove_handler (@{$_[0]});
} # DESTROY

1;
