use strict;
package TcpSession;
use Socket;
use Symbol;
use Event::Watcher qw(R W T);

# e_timeout is only set when:
# - trying to reconnect
# - waiting for a reply for a sync message

sub new {
    my ($class,%arg) = @_;
    my $o = bless {}, $class;
    my $host = delete $arg{host} || 'localhost';
    $o->{host} = $host;
    $o->{iaddr} = inet_aton($host) || die "no host: $host";
    $o->{port} = delete $arg{port} || die "e_port is required";
    $o->{timeout} = delete $arg{timeout} || 20;
    $o->{io} = Event->io(e_desc => "$host\@$o->{port}",
			 e_cb => [$o, 'io'], e_poll => R);
    $o->{connected}=0;
    $o->{q} = [];
    $o->{txn} = $$;
    $o->reconnect;
    $o;
}

sub reconnect {
    my ($o) = @_;
    my $e = $o->{io};
    $o->{ibuf} = '';
    my $fd = gensym;
    socket($fd, PF_INET, SOCK_STREAM, getprotobyname('tcp'))
	or die "socket: $!";
    if (!connect($fd, sockaddr_in($o->{port}, $o->{iaddr}))) {
	warn "Failed to connect to $o->{host} @ $o->{port}\n"
	    if $o->{connected};
	$o->{connected}=0;
	$e->{e_timeout} = 5;
	$e->{e_fd} = undef;
	return;
    }
    $o->{connected}=1;
    $e->{e_timeout} = undef;
    $e->{e_fd} = $fd;
    if ($o->{cur}) {
	$o->{cur}{sent} = 0;
	$e->{e_poll} |= W;
    } else {
	$e->{e_poll} &= ~W;
    }
    1
}

sub io {
    my ($o, $e) = @_;
    if ($e->{e_got} & T or !$e->{e_fd}) {
	$e->{e_fd} = undef;
	return if !$o->reconnect
    }
    my $cur = $o->{cur};
    if ($e->{e_got} & R) {
	return $o->reconnect
	    if !sysread $e->{e_fd}, $o->{ibuf}, 8192, length($o->{ibuf});
	#warn "raw read[$o->{ibuf}]";
	while ($o->{ibuf} =~ s/^txn (\w+)\n(.*?)\bok\n//s) {
	    my ($txn, $msg) = ($1,$2);
	    if ($txn ne $cur->{txn}) {
		warn "Ignoring reply for txn '$txn'";
		next;
	    }
	    $cur->{cb}->($msg);
	    $cur = $o->{cur} = undef;
	    $e->{e_timeout} = undef;
	}
    }
    if ($e->{e_got} & W) {
	my $sent = syswrite($e->{e_fd}, $cur->{op},
			    length($cur->{op})-$cur->{sent}, $cur->{sent});
	return $o->reconnect
	    if !defined $sent;
	$cur->{sent} += $sent;
    }
    if ($cur and $cur->{sent} < length $cur->{op}) {
	$e->{e_poll} |= W;
    } else {
	$e->{e_poll} &= ~W;
	if ($cur->{cb}) {
	    $e->{e_timeout} = $o->{timeout};
	} else {
	    $o->{cur} = undef;
	    $o->process_queue
	}
    }
}

sub add {
    my ($o, $op, $cb) = @_;
    push @{$o->{q}}, { op=>$op, cb=>$cb };
    $o->process_queue
	if !$o->{cur};
}

sub process_queue {
    my ($o) = @_;
    return if !@{$o->{q}};
    if ($o->{cur}) {
	# try to clump
	if (!$o->{cur}{cb}) {
	    while (@{$o->{q}} and !$o->{q}[0]{cb}) {
		my $z = shift @{$o->{q}};
		$o->{cur}{op} .= $z->{op}
	    }
	}
	return;
    }
    my $e = $o->{io};
    $o->{cur} = shift @{$o->{q}};
    my $cur = $o->{cur};
    if ($cur->{cb}) {
	$o->{txn} = 1 if $o->{txn} > 99999;
	$cur->{txn} = ++$o->{txn};
	$cur->{op} = "txn$;$o->{txn}\n".$cur->{op}."commit\n";
    }
    $o->{cur}{sent} = 0;
    $e->{e_poll} |= W;
}

1;

__END__

This is a module I whipped up to do some basic remote procedure calls
between processes.  It really needs to be packaged better before being
added to a library.

-j
