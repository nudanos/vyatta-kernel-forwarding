#!/usr/bin/perl
# SPDX-License-Identifier: GPL-2.0-only
# 50-dpdk-set-aside runs before a 2105 boot configuration is loaded and
# removes what only the DPDK dataplane implements (dpdk-only-paths), so the
# rest of the configuration loads; the removed nodes go to
# config.boot.dpdk-only and the original is kept once.
use strict;
use warnings;
use File::Copy qw(copy);
use File::Temp qw(tempdir);
use Test::More;

my $hook  = 'boot-config.d/50-dpdk-set-aside';
my $motd  = 'update-motd.d/60-dpdk-set-aside';
my $paths = 'dpdk-only-paths';

sub slurp { my ($f) = @_; open my $fh, '<', $f or return; local $/; return <$fh> }

# run the hook on a copy of fixture $name; returns (dir, file, logged paths)
sub run_hook {
    my ( $name, $dir ) = @_;
    $dir //= tempdir( CLEANUP => 1 );
    my $boot = "$dir/config.boot";
    copy( "tests/set-aside/$name.boot", $boot ) or die "copy $name: $!" unless -e $boot;
    my $logger = "$dir/logger";
    open my $lf, '>', $logger or die;
    print $lf "#!/bin/sh\nshift 2\necho \"\$*\" >> $dir/logged\n";    # drops "-t dpdk-set-aside"
    close $lf;
    chmod 0755, $logger;
    local $ENV{SET_ASIDE_LOGGER} = $logger;
    local $ENV{SET_ASIDE_PATHS}  = $paths;
    system( $^X, $hook, $boot ) == 0 or die "$hook exited $?";
    return ( $dir, $boot, slurp("$dir/logged") // '' );
}

# removes DPDK-only nodes, keeps everything else
{
    my ( $dir, $boot, $logged ) = run_hook('full');
    is( slurp($boot), slurp('tests/set-aside/full.expected'),
        'security firewall, cpu-affinity and speed 100m removed; address, speed auto, quoted braces and comments kept' );
    is( slurp("$dir/config.boot.dpdk-only"), slurp('tests/set-aside/full.dpdk-only'),
        'config.boot.dpdk-only holds exactly the removed nodes' );
    is( slurp("$dir/config.boot.2105-original"), slurp('tests/set-aside/full.boot'),
        'the original is saved' );
    like( $logged, qr/^interfaces dataplane dp0s3 cpu-affinity$/m, 'removed path logged' );
    like( $logged, qr/^security firewall$/m, 'removed block logged' );

    # second run on its own output: no change, original not overwritten
    my $mtime = ( stat $boot )[9];
    sleep 1;
    open my $fh, '>>', "$dir/config.boot.2105-original" or die;
    print $fh "/* marker */\n";
    close $fh;
    run_hook( 'full', $dir );
    is( slurp($boot), slurp('tests/set-aside/full.expected'), 'second run: no change' );
    is( ( stat $boot )[9], $mtime, 'second run: file not rewritten' );
    like( slurp("$dir/config.boot.2105-original"), qr{/\* marker \*/}, 'second run: original not overwritten' );
}

# nothing to remove: byte-identical, same mtime, no side files
{
    my $dir  = tempdir( CLEANUP => 1 );
    my $boot = "$dir/config.boot";
    copy( 'tests/set-aside/clean.boot', $boot ) or die;
    utime 1_000_000, 1_000_000, $boot;
    run_hook( 'clean', $dir );
    is( slurp($boot), slurp('tests/set-aside/clean.boot'), 'nothing to remove: same bytes' );
    is( ( stat $boot )[9], 1_000_000, 'nothing to remove: same mtime' );
    ok( !-e "$dir/config.boot.dpdk-only" && !-e "$dir/config.boot.2105-original", 'nothing to remove: no side files' );
}

# a file without the version footer
{
    my ( $dir, $boot ) = run_hook('nofooter');
    is( slurp($boot), "security {\n}\nsystem {\n\thost-name r1\n}\n", 'no footer: firewall removed, rest kept' );
}

# motd notice
{
    my $dir = tempdir( CLEANUP => 1 );
    local $ENV{SET_ASIDE_FILE} = "$dir/config.boot.dpdk-only";
    is( `sh $motd`, '', 'motd: nothing without a set-aside file' );
    open my $fh, '>', "$dir/config.boot.dpdk-only" or die;
    close $fh;
    my $notice = `sh $motd`;
    like( $notice, qr/\Q$dir\/config.boot.dpdk-only\E/, 'motd: names the set-aside file' );
    like( $notice, qr/DPDK dataplane/, 'motd: says the settings need the DPDK dataplane' );
}

done_testing();
