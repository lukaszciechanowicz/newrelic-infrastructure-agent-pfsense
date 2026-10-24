# New Relic Infrastructure Agent for pfSense / FreeBSD

**This is a home project, exercised in a home environment, not validated at large production scale.** It is an independent patch distribution, not an official New Relic or Netgate product or support channel. Use it at your own risk, especially on a router.

This repository packages FreeBSD changes to New Relic Infrastructure Agent 1.80.6 and an optional per-IP NetFlow collector. It contains the source patch and rebuild instructions rather than a full upstream fork. The optional bundled softflowd exporter observes one LAN interface before NAT; the project does not change firewall rules, NAT or routing.

## Supported scope

- Exercised on pfSense 2.9 / FreeBSD 16 amd64; the package ABI is `FreeBSD:16:amd64`. Other releases and architectures are not validated.
- Release `v1.80.6-freebsd.2` uses a generic amd64 CPU baseline without an AVX requirement. Use the corrected package version `1.80.6_2`; the earlier `_1` build could fail with an illegal instruction on a Celeron N4000.
- FreeBSD support does not include Linux container monitoring or Fluent Bit log forwarding. Do not assume all upstream Linux features work here.
- Per-IP collection is opt-in. Monitor capture CPU, packet loss, collector health and New Relic ingest cost. Exported flow counters are not a billing-grade traffic meter.

## Screenshots

Account identifiers and host labels are anonymized.

![Per-IP download volume in New Relic](docs/images/per-ip-traffic.png)

![FreeBSD network interface metrics in New Relic](docs/images/network-metrics.png)

## Install

Download the recommended [`.pkg` for v1.80.6-freebsd.2](https://github.com/lukaszciechanowicz/newrelic-infrastructure-agent-pfsense/releases/download/v1.80.6-freebsd.2/newrelic-infra-freebsd-1.80.6_2.pkg). The [release page](https://github.com/lukaszciechanowicz/newrelic-infrastructure-agent-pfsense/releases/tag/v1.80.6-freebsd.2) also has checksums, an install-tree archive and standalone agent binaries. The archive/binaries are for manual use; the package manages configuration and rc services.

Check the OS/ABI before installing. Keep a router configuration backup and local recovery access. In a **root `sh` shell**, with the downloaded package in the current directory:

```sh
freebsd-version
pkg config ABI
sha256 newrelic-infra-freebsd-1.80.6_2.pkg
pkg add ./newrelic-infra-freebsd-1.80.6_2.pkg
```

Compare the hash with the release's `SHA256SUMS` entry before `pkg add`. The package SHA-256 is `d90bd8e4459eed0d8d8023dcda4a7a01723e0429acc83eaa955507e9890e67b1`.

The package creates `/usr/local/etc/newrelic-infra.yml` only if it is absent; existing configuration is preserved. Back up an existing configuration privately before upgrading. Edit that file locally and set `license_key` to your New Relic **ingest license key**, not an `NRAK` user/API key. Never paste the key into an issue or shell command. The collector region is derived from the license key, including EU keys.

```sh
vi /usr/local/etc/newrelic-infra.yml
chown root:wheel /usr/local/etc/newrelic-infra.yml
chmod 600 /usr/local/etc/newrelic-infra.yml
sysrc -f /etc/rc.conf.local newrelic_infra_enable=YES
/usr/local/etc/rc.d/newrelic-infra.sh start
```

For an already running installation, use `restart` after editing configuration. Look for the host in New Relic Infrastructure and inspect `/var/log/newrelic-infra/newrelic-infra.log` if it does not appear. Both services are disabled by default; enabling the agent does not enable packet capture.

## Optional per-IP traffic

See [per-IP setup, queries and troubleshooting](docs/PER_IP.md) to enable the collector and bundled exporter. Capture a single internal pre-NAT interface to retain client addresses. `tracked_cidrs` filters reported endpoints; it does not capture additional interfaces.

## Source and contributions

[Build instructions](docs/BUILD.md) explain how to recreate the source from the pinned upstream commit and `patches/freebsd-netflow.patch`, then build the packages. See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [CHANGELOG.md](CHANGELOG.md).

Project-maintained changes and documentation are Apache-2.0 licensed; commercial use is allowed subject to the license terms. Upstream and third-party licenses remain in effect. See [LICENSE](LICENSE), [NOTICE](NOTICE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
