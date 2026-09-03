# Security

Report vulnerabilities privately through GitHub Security Advisories.

ConnectBar is read-only. Its process boundary is intentionally small and visible in `ASCClient.swift`. Arguments are passed directly to `Process`; no command is evaluated by a shell. Credentials remain managed by `asc` and macOS Keychain.
