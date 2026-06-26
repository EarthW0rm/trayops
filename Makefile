.PHONY: build test run-gui run-cli clean

build:
	swift build

# See scripts/test.sh for why bare `swift test` cannot run the suites here.
test:
	./scripts/test.sh

run-gui:
	swift run TrayOpsApp

run-cli:
	swift run trayops --help

clean:
	rm -rf .build
