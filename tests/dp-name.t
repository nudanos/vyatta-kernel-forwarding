#!/usr/bin/perl
# dp-name maps a predictable PCI path name to the DANOS dataplane name.
use strict;
use warnings;
use Test::More;

my %cases = (
    'enp0s3'        => 'dp0s3',          # bus 0 drops the "p0"
    'enp0s31f6'     => 'dp0s31f6',       # onboard, function 6
    'enp2s0f1'      => 'dp0p2s0f1',      # multifunction on bus 2
    'enp175s0f1np1' => 'dp0p175s0f1np1', # 14 characters: fits IFNAMSIZ
    'enx001122334455' => '',             # MAC-based (USB): no PCI path
    'enP1p2s0'      => '',               # PCI domain prefix: not mapped
    'enp255s31f7np123' => '',            # would be 17 characters: not truncated
    'wlp3s0'        => '',               # not ethernet
    ''              => '',
);
for my $in ( sort keys %cases ) {
    my $out = `./dp-name '$in'`;
    is( $?, 0, "dp-name '$in' exits 0" );
    chomp $out;
    is( $out, $cases{$in}, "dp-name '$in'" );
}
done_testing();
