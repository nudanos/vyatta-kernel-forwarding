#!/usr/bin/perl
# The op scripts of vplane-config (DPDK-only, not installable here) are
# replaced by dpdk-required, which says why the command cannot run.
use strict;
use warnings;
use File::Temp qw(tempdir);
use Test::More;

# Runs @cmd and returns its exit status and output (stderr too).
sub capture {
    my @cmd = @_;
    my $pid = open my $out, '-|';
    defined $pid or BAIL_OUT("fork: $!");
    if ( !$pid ) { open STDERR, '>&', \*STDOUT or exit 126; exec @cmd or exit 127; }
    my $text = do { local $/ = undef; <$out> }
      // q{};
    close $out;
    return ( $? >> 8, $text );
}

sub read_lines {
    my ($file) = @_;
    open my $fh, '<', $file or BAIL_OUT("$file: $!");
    my @lines = <$fh>;
    close $fh;
    return @lines;
}

my @scripts = qw(nbr-res-flush.pl vplane-arp vplane-gre.pl vplane-ifconfig.pl
  vplane-monitor-cmd.pl vplane-monitor.pl vplane-nd.pl vplane-route.pl
  vplane-show-memory.pl vplane-statistics.pl);

my %links;
foreach my $line ( read_lines('debian/vyatta-kernel-forwarding.links') ) {
    my ( $src, $dst ) = split q{ }, $line;
    $links{$dst} = $src if $dst;
}
for my $s (@scripts) {
    is(
        $links{"opt/vyatta/bin/$s"},
        'usr/lib/vyatta-kernel-forwarding/dpdk-required',
        "$s is linked"
    );
}

my $dir = tempdir( CLEANUP => 1 );
symlink( "$ENV{PWD}/dpdk-required", "$dir/vplane-route.pl" )
  or BAIL_OUT("symlink: $!");
my ( $rc, $out ) = capture( "$dir/vplane-route.pl", '--all' );
isnt( $rc, 0, 'exits non-zero' );
ok( index( $out, 'requires the DPDK dataplane; this system forwards in the Linux kernel' ) >= 0,
    'names the reason' );
done_testing();
