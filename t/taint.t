#!perl -w

if($^O !~ /vms/i && $] >= 5.008) {
    # we don't just use -t in shebang above cos that's not 5.6-friendly
    exec("$^X -Tw -Iblib/lib t/realtainttest");
} else {
    print "1..0 # skip - can't reliably taint-test on VMS or versions < 5.8\n";
}
