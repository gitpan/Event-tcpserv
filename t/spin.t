#!./perl -w

use Test qw($ntest ok plan); plan test => 5;
use Event qw(loop unloop);
use IO::Socket;

# if bind() fails, then what? XXX
my $port = 32123;
Event->tcpserv(e_desc => 'spin', e_port => $port, e_cb => sub {
		   my ($e) = @_;
		   my $w = $e->w;
		   my $ret='';
		   while ($w->{e_ibuf} =~ s/^(.*?)\r?\n//) {
		       my $cmd = $1;
		       if ($cmd eq 'exit') {
			   unloop();
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
    ok <$mom>, "yes!\n";
    ok <$mom>, "maybe\n";
    print $mom "zog\n";
    ok <$mom>, "?\n";
    print $mom "exit\n";
    exit;
}

loop();
wait; $ntest += 3;
ok 1;
