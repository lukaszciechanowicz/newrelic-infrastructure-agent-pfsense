# Build from published source

This repository distributes a patch, not a full upstream fork. `upstream.env` pins New Relic Infrastructure Agent commit `41ff132e9f6b9220081e098c3abb98d6727cfbd8`; `patches/freebsd-netflow.patch` contains the FreeBSD port, NetFlow collector, tests (including embedded wire fixtures), and packaging scripts. Upstream Apache-2.0 and third-party notices remain in the prepared tree. The separate softflowd exporter retains its BSD notices.

## Prepare the tree

From a public clone, with Git and a POSIX shell:

```sh
git clone https://github.com/lukaszciechanowicz/newrelic-infrastructure-agent-pfsense.git
cd newrelic-infrastructure-agent-pfsense
sh scripts/prepare-source.sh
```

The default destination is `work/source` inside this repository. An optional argument selects another path: `sh scripts/prepare-source.sh /path/to/new/source`. The script fetches the pinned public commit and applies the entire patch, including executable modes and the Linux HTTP-client replacement. It refuses any existing destination, even an empty directory or symlink. A failed preparation leaves its directory for inspection; use a new path when retrying. No private checkout or deployment files are needed.

## Native FreeBSD/amd64 package

Use a separate **FreeBSD 16 amd64 build host**, not an appliance whose base system or package repositories would need replacing. The exercised target is pfSense 2.9, package ABI `FreeBSD:16:amd64`; this home project has not been tested at large production scale.

Prerequisites: Git, Go **1.27.2**, a working native `cc`, base libpcap headers/libraries, `autoconf`, `automake`, `gmake`, `pkg`, and FreeBSD base utilities (`fetch`, `sha256`, `patch`, `tar`, `install`). Base FreeBSD normally supplies `cc`; install missing build tools from the build host's existing repositories:

```sh
pkg install -y git autoconf automake gmake
```

Install the official Go 1.27.2 FreeBSD/amd64 toolchain separately and verify its download against [Go's published checksums](https://go.dev/dl/). Keep dependency versions unchanged: the prepared tree uses modules, not a populated vendor tree. Builds use `-mod=readonly`, and initial module downloads require network access.

From the public repository root, after preparing source:

```sh
PUBLIC_SOURCE_COMMIT=$(git rev-parse HEAD)
export GIT_COMMIT="$PUBLIC_SOURCE_COMMIT"
export SOURCE_DATE_EPOCH=$(git show -s --format=%ct HEAD)
BUILD_ROOT="$PWD/work/build"
mkdir -p "$BUILD_ROOT"
export GO_BIN=/path/to/go1.27.2/bin/go
export GOTOOLCHAIN=local GOAMD64=v1
export GOCACHE="$BUILD_ROOT/go-cache"
export GOMODCACHE="$BUILD_ROOT/go-modules"
export GOPATH="$BUILD_ROOT/go-path"

fetch -o "$BUILD_ROOT/softflowd-1.1.1.tar.gz" \
  https://codeload.github.com/irino/softflowd/tar.gz/refs/tags/softflowd-v1.1.1

cd work/source
SOURCE_ARCHIVE="$BUILD_ROOT/softflowd-1.1.1.tar.gz" \
OUTPUT_DIR="$BUILD_ROOT/exporter" CC=cc CPU_FLAGS=-march=x86-64 \
  sh build/package/freebsd/build-exporter.sh

GO_BIN="$GO_BIN" EXPORTER_DIR="$BUILD_ROOT/exporter" \
OUTPUT_DIR="$BUILD_ROOT/release" \
VERSION=1.80.6-freebsd.2 PKG_VERSION=1.80.6_2 \
  sh build/package/freebsd/release.sh pkg
```

If you chose another preparation directory, adjust `cd work/source`. Each exporter/release output directory must be absent or empty. The exporter script verifies source SHA-256 `a6882e59931e5880901f8ee28d78b082cb3000ad8d28af35c13f2b528edbb2c9` before extraction, applies `build/package/freebsd/softflowd-freebsd.patch`, and records its provenance. That patch enables FreeBSD libpcap immediate mode and includes templates in every NetFlow v9 datagram. Do not substitute an unpatched exporter.

Native `cc` defaults to `CPU_FLAGS=-march=x86-64`; do not use `-march=native` or host-specific tuning. If using a separately installed Zig 0.17 compiler, pass `CC='/path/to/zig cc' CPU_FLAGS=-mcpu=x86_64` instead. These generic amd64 settings and `GOAMD64=v1` avoid requiring AVX. CPU compatibility is separate from ABI/shared-library compatibility: the exporter uses native libpcap/libc, and the finished payload still needs a smoke test on the intended hardware. Package revision `_1` failed with `SIGILL` on a Celeron N4000; use corrected `_2` artifacts.

The release directory contains:

- `newrelic-infra-freebsd-1.80.6_2.pkg`
- `newrelic-infra-freebsd-1.80.6-freebsd.2-amd64.tar.gz` (an install tree, not an installer)
- `bin/newrelic-infra`, `bin/newrelic-infra-ctl`, `bin/newrelic-infra-service`
- `SHA256SUMS`

The scripts bundle sample configuration, rc.d services, patched softflowd/softflowctl, upstream licenses/notices, exporter build metadata, and `AGENT.md`. They do not include a live license key or change firewall, NAT, or routing rules. For installation and traffic semantics, see [the README](../README.md) and [per-IP traffic guide](PER_IP.md).

## Cross-compiling only the Go binaries

A non-FreeBSD host with Go 1.27.2 can compile the three pure-Go binaries from the prepared source:

```sh
GOOS=freebsd GOARCH=amd64 GOAMD64=v1 CGO_ENABLED=0 GOTOOLCHAIN=local \
  go build -mod=readonly -trimpath -buildvcs=false \
  -ldflags '-X main.buildVersion=1.80.6-freebsd.2' \
  -o /path/to/new/output/ ./cmd/...
```

This does not build softflowd or create a native package, run FreeBSD binaries, or verify FreeBSD kernel behavior. `release.sh tar` can cross-compile Go and assemble an install tree only when supplied with an already built native FreeBSD exporter. `release.sh pkg` requires native FreeBSD/amd64 and `pkg`.

## Provenance and validation

The upstream commit plus the public patch define the source. In the native recipe, `GIT_COMMIT` identifies the public patch-distribution commit, not a claim that the patched tree is clean upstream. Preserve that public commit, `upstream.env`, and the patch with release records. The scripts keep dependency pins, trim build paths, and include hashes, but do **not** promise bit-for-bit reproducibility across hosts or toolchains. `SHA256SUMS` identifies delivered files; it is not a signature.

Before publishing a new build, run the prepared source's relevant tests on FreeBSD and smoke-test install/upgrade, configuration preservation, reboot autostart, exporter startup/control queries, and actual IPv4/IPv6 traffic through the collector on the intended baseline CPU. A successful cross-build alone establishes none of these runtime properties. This port remains an unofficial home project, not a production-scale qualification or lossless billing system.
