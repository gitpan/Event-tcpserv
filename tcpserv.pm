use strict;
package Event::tcpserv;
use Carp;
use Symbol;
use Socket;
use Event 0.30;
use Event::Watcher qw(R W T);
use vars qw($VERSION);
$VERSION = '0.02';

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
	io(%arg, e_fd => $sock, e_poll => R, e_cb => sub {
	       my ($e) = @_;
	       my $sock = gensym;
	       accept $sock, $e->{e_fd} or return;
	       my $c = Event->
		   io(e_desc => $e->{e_desc}.' '.fileno($sock), e_fd => $sock,
		      e_prio => $e->{e_prio}, e_poll => R, e_reentrant => 0,
		      e_timeout => $timeout, e_cb => sub {
			  my ($e) = @_;
			  if ($e->{e_got} & T) {
			      close $e->{e_fd};
			      $e->cancel;
			      return;
			  }
			  if ($e->{e_got} & R) {
			      if (!sysread $e->{e_fd}, $e->{e_ibuf}, 8192,
				  length($e->{e_ibuf}))
			      {
				  close $e->{e_fd};
				  $e->cancel;
				  return;
			      }
			      $e->{e_obuf} .= $e->{e_readcb}->($e);
			  }
			  if ($e->{e_got} & W or length $e->{e_obuf}) {
			      my $sent = syswrite($e->{e_fd}, $e->{e_obuf},
						  length($e->{e_obuf}));
			      if (!defined $sent) {
				  close $e->{e_fd};
				  $e->cancel;
			      }
			      $e->{e_obuf} = substr($e->{e_obuf}, $sent) || '';
			  }
			  if (length $e->{e_obuf}) {
			      $e->{e_poll} |= W;
			  } else {
			      $e->{e_poll} &= ~W;
			  }
		      });
	       $c->use_keys('e_ibuf','e_obuf','e_readcb');
	       @$c{'e_ibuf','e_obuf'} = ('')x2;
	       $c->{e_readcb} = $readcb;
	   });
}

1;
