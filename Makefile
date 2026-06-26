.PHONY: build test run-gui run-cli icon app clean

build:
	swift build

# See scripts/test.sh for why bare `swift test` cannot run the suites here.
test:
	./scripts/test.sh

run-gui:
	swift run TrayOpsApp

run-cli:
	swift run trayops --help

# Regenerate Resources/AppIcon.icns (only needed when changing the icon design).
icon:
	./scripts/generate-icon.sh

# Build the standalone dist/TrayOpsApp.app bundle.
app:
	./scripts/build-app.sh

clean:
	rm -rf .build dist
