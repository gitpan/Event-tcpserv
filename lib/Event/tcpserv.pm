use strict;
package Event::tcpserv;
use Carp;
use Symbol;
use Socket;
use Event 0.38;
use Event::Watcher qw(R W T);
use vars qw($VERSION);
$VERSION = '0.04';

'Event::Watcher'->register;

sub new {
    shift if @_ & 1;
    my %arg = @_;

    my $port = delete $arg{e_port} || die "e_port required";
    my $readcb = delete $arg{e_cb} || die "e_cb required";
    my $timeout = delete $arg{e_timeout} || 2*60*60;
    for (qw(e_fd e_poll)) { carp "$_ ignored" if delete $arg{$_}; }

    my $proto = getprotobyname('tcp');
    my $sock = gensym;
    socket($sock, PF_INET, SOCK_STREAM, $proto) or die "socket: $!";
    setsockopt($sock, SOL_SOCKET, SO_REUSEADDR, pack('l', 1))
	or die "setsockopt: $!";
    bind($sock, sockaddr_in($port, INADDR_ANY)) or die "bind: $!";
    listen($sock, SOMAXCONN)                    or die "listen: $!";
    Event->
	io(%arg, e_fd => $sock, e_poll => R, e_max_cb_tm => 5, e_cb => sub {
	       my ($e) = @_;
	       my $w=$e->w;
	       my $sock = gensym;
	       accept $sock, $w->{e_fd} or return;
	       my $c = Event->
		   io(e_desc => $w->{e_desc}.' '.fileno($sock), e_fd => $sock,
		      e_prio => $e->{e_prio}, e_poll => R, e_reentrant => 0,
		      e_timeout => $timeout, e_max_cb_tm => 30, e_cb => sub {
			  my ($e) = @_;
			  my $w = $e->w;
			  if ($e->{e_got} & T) {
			      close $w->{e_fd};
			      $w->cancel;
			      return;
			  }
			  if ($e->{e_got} & R) {
			      if (!sysread $w->{e_fd}, $w->{e_ibuf}, 8192,
				  length($w->{e_ibuf}))
			      {
				  close $w->{e_fd};
				  $w->cancel;
				  return;
			      }
			      $w->{e_obuf} .= $w->{e_readcb}->($e);
			  }
			  if ($e->{e_got} & W or length $w->{e_obuf}) {
			      my $sent = syswrite($w->{e_fd}, $w->{e_obuf},
						  length($w->{e_obuf}));
			      if (!defined $sent) {
				  close $w->{e_fd};
				  $w->cancel;
			      }
			      $w->{e_obuf} = substr($w->{e_obuf}, $sent) || '';
			  }
			  if (length $w->{e_obuf}) {
			      $w->{e_poll} |= W;
			  } else {
			      $w->{e_poll} &= ~W;
			  }
		      });
	       $c->use_keys('e_ibuf','e_obuf','e_readcb');
	       @$c{'e_ibuf','e_obuf'} = ('')x2;
	       $c->{e_readcb} = $readcb;
	   });
}

1;
