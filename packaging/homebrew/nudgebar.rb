# Homebrew Cask for Nudgebar.
#
# This is a TEMPLATE. To publish:
#   1. Create a tap repo named "homebrew-tap" under your account
#      (e.g. github.com/mikec-git/homebrew-tap).
#   2. Cut a GitHub Release of Nudgebar with a zipped app bundle named
#      Nudgebar.zip attached to the tag (e.g. v0.1.0).
#   3. Compute the archive checksum:  shasum -a 256 Nudgebar.zip
#      and replace `:no_check` below with that value.
#   4. Copy this file to Casks/nudgebar.rb in the tap repo and push.
#
# Users then install with:
#   brew install --cask mikec-git/tap/nudgebar
#
# NOTE: the app is currently ad-hoc signed (not notarized), so until it is
# signed with a Developer ID and notarized, users will get a Gatekeeper prompt
# on first launch (right-click -> Open, or `xattr -dr com.apple.quarantine`).
cask "nudgebar" do
  version "0.1.0"
  sha256 :no_check # replace with `shasum -a 256 Nudgebar.zip` of the release asset

  url "https://github.com/mikec-git/nudgebar/releases/download/v#{version}/Nudgebar.zip"
  name "Nudgebar"
  desc "High-visibility menu-bar calendar reminders for macOS"
  homepage "https://github.com/mikec-git/nudgebar"

  depends_on macos: ">= :ventura"

  app "Nudgebar.app"

  zap trash: [
    "~/Library/Application Support/Nudgebar",
    "~/Library/Preferences/com.local.Nudgebar.plist",
  ]
end
