# Per-IP traffic

The optional exporter captures packets on one interface and sends unsampled NetFlow v9 over loopback UDP to the agent. The collector emits `PfIpTrafficSample` byte/packet deltas per IP and `PfFlowCollectorSample` health counters per reporting window. It does not send packet payloads to New Relic, but endpoint addresses are telemetry: consider privacy and retention before enabling it.

In the prepared source, `internal/netflow/` decodes v9, `pkg/metrics/netflow/` aggregates endpoints, `pkg/config/netflow.go` defines configuration, and `build/package/freebsd/` contains rc scripts and the softflowd patch. The bundled softflowd 1.1.1 patch preserves FreeBSD pcap immediate mode and includes templates in every v9 datagram. NetFlow v5, IPFIX and extrapolation of sampled traffic are not supported.

## Configure

Add or update this section in `/usr/local/etc/newrelic-infra.yml`; keep your existing license and agent settings:

```yaml
netflow:
  enabled: true
  listen: "127.0.0.1:2055"
  sample_interval: 15
  max_ips: 8192
  observation_point: "router-lan"
  tracked_cidrs:
    - "192.0.2.0/24"
    - "2001:db8::/32"
```

**Replace both documentation CIDRs with your actual client subnet(s)**, removing an unused address family. Leaving these examples unchanged normally produces no client samples. `sample_interval` is in seconds; `max_ips` limits endpoint state per reporting window. CIDRs filter endpoint reporting, not packet capture interfaces.

Choose one LAN interface before NAT so that client addresses remain visible. Replace `YOUR_LAN_INTERFACE` below with its actual OS interface name, not the pfSense display label. Do not use WAN, loopback, or overlapping captures; NAT can hide clients and multiple observation points can double-count traffic. Only traffic visible on that interface can be measured; traffic switched entirely elsewhere will not appear.

In a root `sh` shell:

```sh
sysrc -f /etc/rc.conf.local newrelic_infra_enable=YES
sysrc -f /etc/rc.conf.local newrelic_netflow_enable=YES
sysrc -f /etc/rc.conf.local newrelic_netflow_interface=YOUR_LAN_INTERFACE
/usr/local/etc/rc.d/newrelic-infra.sh restart
/usr/local/etc/rc.d/newrelic-netflow-exporter.sh start
```

Use exporter `restart` if it is already running. The exporter waits for the agent's loopback UDP listener. Keep the listener on loopback: UDP NetFlow is unauthenticated and should not be exposed to untrusted senders. Allow for flow export delay (active flows are periodically exported), the 15-second reporting window and ingest delay.

Check capture and export counters with:

```sh
/usr/local/libexec/newrelic-infra/softflowctl \
  -c /var/run/newrelic-infra/softflowd.ctl statistics
```

## Query

Replace `YOUR_ROUTER_HOSTNAME` with the `hostname` actually reported by the agent. The download leaderboard is:

```sql
FROM PfIpTrafficSample
SELECT sum(bytesReceived) / 1000000 AS 'Download MB'
WHERE hostname = 'YOUR_ROUTER_HOSTNAME'
  AND observationPoint = 'router-lan'
FACET ip
SINCE 1 hour ago
LIMIT 20
```

`bytesReceived` means destination-side bytes for that endpoint; `bytesSent` means source-side bytes. On a pre-NAT LAN observation these usually correspond to client download and upload. They are not interface RX/TX counters. Inter-client traffic also counts: a transfer between two tracked endpoints contributes sent bytes to one and received bytes to the other. Summing both directions across all endpoints double-counts such transfers. Values are interval deltas, so use `sum`, not differences of successive samples. MB here is decimal.

Collector health:

```sql
FROM PfFlowCollectorSample
SELECT sum(datagramsReceived), sum(recordsDecoded), sum(unknownTemplates),
       sum(malformedDatagrams), sum(sequenceGaps), sum(duplicateDatagrams),
       sum(droppedIPs)
WHERE hostname = 'YOUR_ROUTER_HOSTNAME'
  AND observationPoint = 'router-lan'
SINCE 30 minutes ago
TIMESERIES
```

These are also window deltas. `unknownTemplates` counts data FlowSets without a known template; `droppedIPs` counts rejected endpoint updates at the IP capacity limit, not unique dropped clients. `sequenceGaps` reports missing exporter sequence units, not a recovered byte count. UDP/export/capture loss can undercount traffic even when records decode successfully. Watch exporter capture statistics, router CPU and ingest volume as well as these counters.

## No data or unexpected totals

1. If the host itself is absent, check the ingest license key, region/connectivity and `/var/log/newrelic-infra/newrelic-infra.log` before debugging flows. A running supervisor does not prove the agent child is healthy; an invalid key can fail before file logging starts, so also inspect `/var/log/system.log` on pfSense. Do not publish raw configuration or unredacted logs.
2. Check `/usr/local/etc/rc.d/newrelic-infra.sh status`, `/usr/local/etc/rc.d/newrelic-netflow-exporter.sh status` and `sockstat -4 -l -P udp -p 2055`. Confirm the agent owns the loopback listener and both configurations use the same port.
3. If `datagramsReceived` stays zero, check the chosen interface with `ifconfig`, generate client traffic across it, and inspect exporter/capture state. Traffic that never crosses the capture interface cannot appear.
4. Datagrams with no `recordsDecoded` suggest exporter/template/format problems or no exported traffic yet. Check unknown-template and malformed counters; use the bundled patched exporter, not an arbitrary v5/IPFIX sender.
5. Decoded records with no IP samples usually mean the CIDRs do not match the observed addresses. Check for WAN-side NAT, unchanged example ranges, the hostname filter and the observation-point filter. Rising `droppedIPs` means the configured endpoint limit is rejecting updates; assess memory and ingest cost before increasing it.
6. For inflated totals, check direction semantics, inter-client traffic and duplicate observation points. Do not sum across routers/interfaces as if they were disjoint traffic.

To disable capture, set `newrelic_netflow_enable=NO` in `/etc/rc.conf.local` and stop `/usr/local/etc/rc.d/newrelic-netflow-exporter.sh`. Set `netflow.enabled: false` and restart the agent to disable the collector too. This does not alter firewall or routing configuration.
