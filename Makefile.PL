use ExtUtils::MakeMaker;
my @opt=(
	 PREREQ_PM => { Test => 1, Event => '0.38' },
	 VERSION_FROM => './lib/Event/tcpserv.pm',
	 NAME => 'Event::tcpserv'
	);

WriteMakefile(@opt);
