.PHONY: build test run package clean

build:
	swift build

test:
	swift test

run:
	swift run Nudgebar

package:
	Scripts/package-app.sh

clean:
	swift package clean
