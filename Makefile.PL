# -*- mode: Perl -*-

use ExtUtils::MakeMaker qw(WriteMakefile);

WriteMakefile(NAME         => "Data::Compare",
              VERSION_FROM => "lib/Data/Compare.pm",
              dist         => { COMPRESS => "gzip", SUFFIX => "gz" },
	      clean        => { FILES => '*.bak *.old mibs/*.dump lib/*/*~' },
              );
