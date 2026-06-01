# Homebrew Cask for Nudgebar.
#
# The published, canonical copy lives in the tap and is what `brew` installs:
#   https://github.com/mikec-git/homebrew-tap/blob/main/Casks/nudgebar.rb
#   brew install --cask mikec-git/tap/nudgebar
#
# This in-repo copy is a reference mirror. On a new release, rebuild the zip
# (`make package` then `ditto -c -k --keepParent dist/Nudgebar.app Nudgebar.zip`),
# attach it to the GitHub release, then update `version` and `sha256` here and in
# the tap (`shasum -a 256 Nudgebar.zip`).
#
# NOTE: the app is ad-hoc signed (not notarized), so first launch shows a Gatekeeper
# prompt (right-click -> Open, or `xattr -dr com.apple.quarantine`).
cask "nudgebar" do
  version "0.1.0"
  sha256 "a3f55d106d1089f5f8c042adf903bdc2b175e95040c6d6b137d5ec2df99d229c"

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
