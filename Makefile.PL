use ExtUtils::MakeMaker;
my @opt=(
	 PREREQ_PM => { Test => 1, Event => '0.30' },
	 VERSION_FROM => './tcpserv.pm',
	 NAME => 'Event::tcpserv'
	);

WriteMakefile(@opt);
