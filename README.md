# vyatta-kernel-forwarding

NuDanOS milestone 1 forwards packets in the Linux kernel rather than the DPDK
dataplane (`vyatta-dataplane`). This package provides the virtual package
`vyatta-forwarding`, which the system and interface configuration packages
depend on, so they install without the dataplane. `vyatta-dataplane` provides
the same virtual package; the two conflict.

Firewall, NAT and QoS need the dataplane and are not available with kernel
forwarding.

An imported boot configuration containing firewall rules, interface firewall
bindings or NAT is preserved and refused. This also applies when an older
release saved that policy to `/config/config.boot.dpdk-only`. The privileged
preflight for `system-configure.service` blocks routed and bridged transit
using dedicated nftables tables and prevents the configuration from loading.
The console remains available. Review and replace the legacy policy before
archiving its side file and rebooting with the corrected configuration.
Other unsupported settings, such as CPU affinity and QoS, are still set aside.
