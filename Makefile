.PHONY: build test swift-test xcode-build verify sanitize-specs run package clean

build:
	swift build

test: swift-test

swift-test:
	swift test

xcode-build:
	xcodebuild -project Nudgebar.xcodeproj -scheme Nudgebar -configuration Debug -destination 'platform=macOS' build

verify: swift-test sanitize-specs

sanitize-specs:
	Scripts/sanitize-specs.sh

run:
	swift run Nudgebar

package:
	Scripts/package-app.sh

clean:
	swift package clean
