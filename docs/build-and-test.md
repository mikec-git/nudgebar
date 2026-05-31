# Build And Test

Nudgebar has two build surfaces:

- `Nudgebar.xcodeproj`: owns the macOS app bundle, Info.plist, entitlements, resources, signing, and launchable app target.
- `Package.swift`: owns non-UI modules and behavior tests.

## Commands

```sh
make xcode-build
make swift-test
make sanitize-specs
make verify
```

Equivalent raw commands:

```sh
xcodebuild -project Nudgebar.xcodeproj -scheme Nudgebar -configuration Debug -destination 'platform=macOS' build
swift test
Scripts/sanitize-specs.sh
```

Automated tests use fixtures and local stores. They must not call live Google, Microsoft, CalDAV, Calendly, Cal.com, or Acuity services.

## Local Toolchain Note

This worktree has been verified with Xcode 26.5 selected at `/Applications/Xcode.app/Contents/Developer`.

If the developer directory is reset to Command Line Tools, restore the full Xcode toolchain before running project builds:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
