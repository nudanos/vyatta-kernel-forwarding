# vyatta-kernel-forwarding

NuDanOS milestone 1 forwards packets in the Linux kernel rather than the DPDK
dataplane (`vyatta-dataplane`). This package provides the virtual package
`vyatta-forwarding`, which the system and interface configuration packages
depend on, so they install without the dataplane. `vyatta-dataplane` provides
the same virtual package; the two conflict.

Firewall, NAT and QoS need the dataplane and are not available with kernel
forwarding.
