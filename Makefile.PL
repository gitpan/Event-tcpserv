use ExtUtils::MakeMaker;
my @opt=(
	 PREREQ_PM => { Test => 1, Event => '0.32' },
	 VERSION_FROM => './lib/Event/tcpserv.pm',
	 NAME => 'Event::tcpserv'
	);

WriteMakefile(@opt);
