#!perl -Tw

use strict;

use Data::Compare;

print "1..1\n";

my $test = 0;

# in taint mode there should be no plugins

print "not " unless(Compare({}, Data::Compare::plugins()));
print 'ok '.(++$test)." plugins disabled in taint mode\n";
