.PHONY: build test lint format run-gui run-cli icon app install uninstall clean

build:
	swift build

# Lint with swift-format — the same check the CI runs on pull requests.
lint:
	swift format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift

# Auto-format the code in place.
format:
	swift format format --in-place --configuration .swift-format --recursive Sources Tests Package.swift

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

# Install the app to /Applications and the trayops CLI onto the PATH.
install:
	./scripts/install.sh

# Remove the app, the CLI and the login item (add --purge for data via the script).
uninstall:
	./scripts/uninstall.sh

clean:
	rm -rf .build dist
