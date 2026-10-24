# Changelog

## v1.80.6-freebsd.2

First public release of this patch distribution, based on Infrastructure Agent 1.80.6.

- FreeBSD host monitoring and pfSense rc service/package support.
- Optional per-IP IPv4/IPv6 traffic deltas from a local NetFlow v9 collector, with health events and a patched softflowd 1.1.1 exporter.
- Rebuildable source patch against a pinned upstream commit.
- Corrected package version `1.80.6_2` uses a generic amd64 CPU baseline without AVX. It replaces the earlier `_1` build that could trigger an illegal instruction on a Celeron N4000.

Exercised on pfSense 2.9 / FreeBSD 16 amd64 in a home environment, not validated at large production scale.
