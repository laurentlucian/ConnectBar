<h1 align="center">
  <img src=".github/icon.png" width="144" alt="ConnectBar icon" /><br />
  ConnectBar
</h1>

<p align="center">App Store Connect attention, in your menu bar.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT" />
</p>

ConnectBar is a free, native, read-only App Store Connect monitor. It shows what needs attention without opening the web dashboard.

## Features

- **Release status** — waiting, reviewing, approved, or rejected
- **TestFlight builds** — processing and failed uploads
- **New reviews** — recent ratings and feedback across selected apps
- **Useful notifications** — only new attention items, never every poll
- **Seen state** — clear one item or the whole inbox
- **Multiple apps** — choose exactly what appears
- **Local state** — cached snapshots and preferences stay on your Mac
- **Existing credentials** — delegates authentication to the open-source `asc` CLI
- **Mock mode** — explore and contribute without an Apple developer account

ConnectBar cannot edit metadata, submit releases, manage testers, or reply to reviews.

## Install

ConnectBar currently builds from source. Install [`asc`](https://github.com/rorkai/App-Store-Connect-CLI), connect it, then package the app:

```sh
brew install asc
asc auth login
git clone https://github.com/your-name/ConnectBar.git
cd ConnectBar
./Scripts/package.sh
open build/ConnectBar.app
```

Requires macOS 14 or later. ConnectBar looks for `asc` in standard Homebrew and local binary paths.

## How it works

ConnectBar runs read-only `asc` commands every ten minutes and converts their JSON into a small set of signals. It stores no App Store Connect private keys; `asc` owns authentication and keeps credentials in Keychain.

The app keeps the last successful snapshot when Apple or the network is unavailable. It compares stable signal IDs between refreshes and sends notifications only for newly observed items.

No account, analytics, hosted service, webhook relay, or AI provider.

## Development

```sh
swift run ConnectBar
swift test
```

Enable **Settings → Mock data** to work without credentials. Package an ad-hoc signed local app with:

```sh
./Scripts/package.sh
```

For a release, set `CONNECTBAR_SIGNING_IDENTITY` to a Developer ID Application identity, notarize the resulting app or DMG, and publish its checksum.

## Architecture

- `MenuBarController` owns the `NSStatusItem` and floating `NSPanel`.
- `AppModel` schedules refreshes, preserves snapshots, and detects transitions.
- `ASCClient` is the only process boundary.
- `ASCParser` normalizes `asc` JSON into testable `Signal` values.
- SwiftUI renders the popover and settings.

## Security

ConnectBar invokes only list/status commands. It does not accept or persist `.p8` keys. Review the commands in `ASCClient.swift`; the complete network path is ConnectBar → `asc` → Apple.

## License

MIT
