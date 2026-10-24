# Security reports

Use [GitHub private vulnerability reporting](https://github.com/lukaszciechanowicz/newrelic-infrastructure-agent-pfsense/security/advisories/new) for suspected vulnerabilities. Do not disclose exploit details or credentials in public issues. Include the affected release, impact and a minimal reproduction with secrets removed.

This is a home-maintained project with no guaranteed response time or security support window. Use the latest corrected release and assess changes before deploying them on a router. The agent and packet exporter run with elevated privileges. Keep flow collection on loopback and restrict configuration access to root.

For issues solely in an unmodified upstream component, also follow that project's security reporting policy. Never include a real ingest key, API key, private capture or router backup in a report.
