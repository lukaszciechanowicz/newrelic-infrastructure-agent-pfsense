# Contributing

For a bug, include the package version, OS/ABI, CPU, expected result and a small reproducible example. State which interface role is observed and whether per-IP collection is enabled, without revealing your network details. Use documentation address ranges in examples.

For code changes, follow [the rebuild instructions](docs/BUILD.md), keep the patch applicable to the pinned upstream commit and preserve license notices. Describe the affected platforms and the checks you actually ran; say explicitly what remains untested. Relevant upstream unit tests and a FreeBSD/pfSense smoke check are useful, but never experiment on a production router without a recovery plan.

Keep changes focused. Do not submit ingest keys, API keys, account identifiers, private hostnames, packet captures or configuration backups. Redact logs before sharing them. Report security issues through [SECURITY.md](SECURITY.md), not a public issue.

Contributions are under the project's Apache-2.0 license; third-party license terms must remain intact.
