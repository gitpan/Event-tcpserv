#!./perl -w

use Test qw($ntest ok plan); plan test => 7;
use Event qw(loop unloop sweep sleep);

# $Event::DebugLevel = 3;

my $Port = 7000 + int rand 1000;  #hope ok!  :-)

if (fork == 0) {
    require Math::BigInt;

    my $Reply;
    sub reply {
	$Reply .= shift;
    }

    Event->tcpserv(e_port => $Port, e_cb => sub {
		       my ($e) = @_;
		       my $w = $e->w;
		       $Reply='';
		       while ($w->{e_ibuf} =~ s/^(.*?)\r?\n//) {
			   my @l = split /$;/, $1, -1;
			   next if !@l;
			   my $c = "rpc_".shift(@l);
			   if (!defined &$c) {
			       $c =~ s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;
			       warn "RPC '$c' is not defined (ignored)\n";
			       next;
			   }
			   no strict 'refs';
			   &$c($w, @l);
		       }		       
		       $Reply;
		   });
    
    sub rpc_txn {
	my ($e, $txn) = @_;
	$e->{run} = undef;
	$e->{txn} = $txn;
    }
    sub rpc_commit {
	my ($e) = @_;
	my $txn = $e->{txn};
	my $run = delete $e->{run};
	return warn "nothing to commit"
	    if !$run;
	$run->($e, sub { reply("txn $txn\n".shift()."ok\n") });
    }

    sub rpc_require {
	my ($e, $v) = @_;
	$e->{run} = sub {
	    my ($e,$r) = @_;
	    $r->(($v >= 1.0? '1':'0')."\n")
	};
    }

    sub rpc_product {
	my $e = shift;
	my @n = @_;
	$e->{run} = sub {
	    my ($e, $ret) = @_;
	    my $p = Math::BigInt->new('+1');
	    for (@n) { $p *= $_ }
	    $ret->("$p\n")
	};
    }
    
    sub rpc_hit {
	my ($e, $n) = @_;
	$e->{hit} ||= 0;
	$e->{hit} += $n;
    }

    sub rpc_get_hits {
	my $e = shift;
	$e->{run} = sub {
	    my ($e,$r) = @_;
	    $r->("$e->{hit}\n");
	};
    }

    use vars qw(&rpc_unloop);
    *rpc_unloop = \&unloop;

    loop; exit
}

require Event::TcpSession;

sleep .5;
my $SRV = Event::TcpSession->new(port => $Port);
$SRV->add(join($;,'require','1.0')."\n", sub {
	      unloop(shift);
	  });
ok loop();

for my $z (16,32,48,64) {
    $SRV->add(join($;,'product', 1..$z)."\n", sub{
		  ok shift;
		  unloop;
	      });
    loop();
}

for (1..4096) {
    $SRV->add(join($;,'hit',rand)."\n");
}
$SRV->add("get_hits\n", sub {
	      my $got= shift;
	      ok $got > 1000 && $got < 3000;
	      unloop
	  });
loop;

$SRV->add("unloop\n");
sweep; wait;

ok 1;
