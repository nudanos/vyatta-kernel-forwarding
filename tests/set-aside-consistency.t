#!/usr/bin/perl
# SPDX-License-Identifier: GPL-2.0-only
# dpdk-only-paths must cover what NuDanOS refuses or does not ship: every
# deviation in the kernel-forwarding YANG, and every DPDK-only package with
# a configuration YANG module listed in distro/docs/kernel-forwarding.md.
use strict;
use warnings;
use Test::More;

sub read_lines {
    my ($file) = @_;
    open my $fh, '<', $file or BAIL_OUT("$file: $!");
    my @lines = <$fh>;
    close $fh;
    return @lines;
}

my ( @patterns, %annotated );
{
    my @pkgs;
    for ( read_lines('dpdk-only-paths') ) {
        chomp;
        next unless /\S/x;
        if (/^\#\s*(vyatta-\S+?)(:.*)?$/x) { push @pkgs, $1; $annotated{$1} = $2 // ''; next }
        next if /^\#/x;
        my @p = split;
        pop @p if $p[-1] =~ /^!/x;    # value condition
        push @patterns, \@p;
        $annotated{$_} ||= 'covered' for @pkgs;
        @pkgs = ();
    }
}

sub covered {
    my @path = @_;
  PATTERN: for my $p (@patterns) {
        next if @$p > @path;
        for my $i ( 0 .. $#$p ) {
            next PATTERN unless $p->[$i] eq '*' || $p->[$i] eq $path[$i];
        }
        return 1;
    }
    return 0;
}

# deviations: /if:interfaces/interfaces-dataplane:dataplane/... -> interfaces dataplane * ...
my %lists = map { $_ => 1 } qw(dataplane vif);
my $n     = 0;
for ( read_lines('yang/vyatta-kernel-forwarding-deviations-v1.yang') ) {
    next unless /^\s*deviation\s+(\S+)\s*\{/x;
    my @path;
    for my $e ( grep { length } split m{/}x, $1 ) {
        $e =~ s/^[\w-]+://x;
        push @path, $e;
        push @path, 'x' if $lists{$e};    # the list key
    }
    ok( covered(@path), "deviation @path is set aside" );
    $n++;
}
ok( $n > 0, 'deviations found' );

SKIP: {
    my $doc = $ENV{NUDANOS_KF_DOC};
    skip 'NUDANOS_KF_DOC is not set (path to distro/docs/kernel-forwarding.md)', 1
      unless $doc;
    my $in = 0;
    my @pkgs;
    for ( read_lines($doc) ) {
        if (/^\#\#[ ]/x) { $in = /DPDK-only/x; next }
        next unless $in && /^\|\s*(vyatta-[\w-]+-yang)\s*\|/x;
        my $p = $1;
        next if $p =~ /^vyatta-op-|-rpc-|-deviation-/x;    # no configuration of their own
        push @pkgs, $p;
    }
    ok( @pkgs > 0,             'DPDK-only configuration packages found in the doc' );
    ok( exists $annotated{$_}, "$_ is covered by dpdk-only-paths" ) for @pkgs;
}

done_testing();
