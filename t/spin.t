#!./perl -w

use Test qw($ntest ok plan); plan test => 5;
use Event 0.30;
use IO::Socket;

my $port = 32123;

my $demo_bug=0; # demonstrates mysterious typemap bug
if ($demo_bug) {
    $Event::DebugLevel = 4;
    $Event::Eval = 1;
    $Event::DIED = sub { 
	Event::unloop_all();
	goto &Event::default_exception_handler
    };
}

# if bind() fails, then what? XXX

Event->tcpserv(e_desc => 'spin', e_port => $port, e_cb => sub {
		   my ($e) = @_;
		   return '' if $demo_bug;
		   my $ret='';
		   while ($e->{e_ibuf} =~ s/^(.*?)\r?\n//) {
		       my $cmd = $1;
		       if ($cmd eq 'exit') {
			   Event::unloop();
			   return '';
		       } elsif ($cmd eq 'yes') {
			   $ret .= "yes!"
		       } elsif ($cmd eq 'no') {
			   $ret .= "maybe"
		       } else {
			   $ret .= "?";
		       }
		       $ret .= "\n";
		   }
		   $ret
	       });
ok 1;

if (fork == 0) {
    my $mom = IO::Socket::INET->new("localhost:$port")
	|| die "can't connect to port $port on localhost: $!";
    $mom->autoflush(1);
    print $mom "yes\nno\n";
    ok <$mom>, "yes!\n" if !$demo_bug;
    ok <$mom>, "maybe\n" if !$demo_bug;
    print $mom "zog\n";
    ok <$mom>, "?\n" if !$demo_bug;
    print $mom "exit\n";
    exit;
}

Event::loop();

wait;
$ntest += 3;
ok 1;
