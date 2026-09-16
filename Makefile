# Setec UI — build, run and inspect from the command line.
#
# Every target here is what the agent skills call. Nothing needs the Xcode UI.
# Tools: xcodegen, xcodebuild, swiftformat, swiftlint (homelab dev-tools role),
# xcbeautify (optional, filters build output), ~/bin/axdump and ~/bin/winid
# (built from mac-app-template/tools).

APP_NAME    := Setec UI
APP_MODULE  := SetecUI
BUNDLE_ID   := org.meltforce.setec-ui
SCHEME      := $(APP_MODULE)
CONFIG      ?= Debug
DERIVED     := .build
PROJECT     := $(APP_MODULE).xcodeproj
APP         := $(DERIVED)/Build/Products/$(CONFIG)/$(APP_NAME).app
BINARY      := $(APP)/Contents/MacOS/$(APP_NAME)
AGENT_DIR   := .agent
PORT_FILE   := $(TMPDIR)$(BUNDLE_ID).debug-port
XCB         := $(shell command -v xcbeautify 2>/dev/null)
PIPE        := $(if $(XCB),| $(XCB) --quiet,)
XCODEBUILD  := xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIG)" -derivedDataPath "$(DERIVED)" -destination 'platform=macOS,arch=arm64'

.PHONY: project build run stop verify test format lint screenshot screenshot-native screenshot-self inspect click type key at eval logs install notarize clean help

help:
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/' | column -t -s $$'\t'

# ---------------------------------------------------------------------------
# Project and build
# ---------------------------------------------------------------------------

# Always regenerated: xcodegen takes well under a second, and a Swift file added
# without regenerating fails the build with "cannot find X in scope".
project: ## Regenerate the Xcode project from project.yml
	xcodegen generate --quiet

build: project ## Build $(CONFIG) into .build
	set -o pipefail; $(XCODEBUILD) build $(PIPE)

format: ## Format Swift sources in place
	swiftformat App Services Tests UITests

lint: ## swiftformat --lint and swiftlint, no changes
	swiftformat App Services Tests UITests --lint
	swiftlint lint --quiet

test: project ## Unit and UI tests
	set -o pipefail; $(XCODEBUILD) test $(PIPE)

verify: lint build test ## lint, build, test — the completion gate
	@echo "verify: green for $(APP_NAME) ($(CONFIG))"

# ---------------------------------------------------------------------------
# Run and observe
# ---------------------------------------------------------------------------

# A graceful quit lets AppKit write its window state; a SIGTERM does not, and
# the stale restoration state can leave the next test-launched instance with
# no window (INCIDENTS.md, 2026-09-15). pkill stays as the fallback.
stop: ## Quit the running instance, if any
	@if pgrep -xq "$(APP_NAME)"; then \
	  osascript -e 'tell application id "$(BUNDLE_ID)" to quit' >/dev/null 2>&1; \
	  for i in 1 2 3 4 5 6; do pgrep -xq "$(APP_NAME)" || break; sleep 0.5; done; \
	  pkill -x "$(APP_NAME)" 2>/dev/null; \
	fi; sleep 0.3

run: stop build ## Build, launch, wait for the window, show the last log lines
	@mkdir -p $(AGENT_DIR)
	open -n "$(APP)"
	@for i in $$(seq 1 30); do \
	  if ~/bin/winid "$(BUNDLE_ID)" >/dev/null 2>&1; then echo "run: window up after $$i tries"; break; fi; \
	  sleep 0.5; \
	  if [ $$i -eq 30 ]; then echo "run: no window after 15 s — see 'make logs'" >&2; exit 1; fi; \
	done
	@log show --last 20s --info --debug --predicate 'subsystem == "$(BUNDLE_ID)"' --style compact 2>/dev/null | tail -n 40

logs: ## Stream this app's unified log
	log stream --predicate 'subsystem == "$(BUNDLE_ID)"' --style compact --level debug

# Two capture paths. screencapture shows the whole window (sidebar glass,
# title bar, PDFView) but needs the Screen Recording grant for the terminal;
# the DEBUG build's DebugServer renders its own content view without any grant
# but leaves layer-hosted views (sidebar, PDFView) blank. `screenshot` takes the
# first and falls back to the second when the grant is missing.
screenshot: ## PNG of the app window into .agent/screenshot.png (native capture, fallback: self-render)
	@mkdir -p $(AGENT_DIR)
	@if screencapture -l "$$(~/bin/winid "$(BUNDLE_ID)")" -o -x $(AGENT_DIR)/screenshot.png 2>/dev/null && [ -s $(AGENT_DIR)/screenshot.png ]; then \
	  echo "screenshot: $(AGENT_DIR)/screenshot.png (native)"; \
	else \
	  $(MAKE) --no-print-directory eval CMD="screenshot $(CURDIR)/$(AGENT_DIR)/screenshot.png" >/dev/null && \
	  echo "screenshot: $(AGENT_DIR)/screenshot.png (self-rendered: no Screen Recording grant; sidebar and PDFView blank)"; \
	fi

screenshot-native: ## screencapture only, fails without the Screen Recording grant
	@mkdir -p $(AGENT_DIR)
	screencapture -l "$$(~/bin/winid "$(BUNDLE_ID)")" -o -x $(AGENT_DIR)/screenshot.png
	@echo "screenshot: $(AGENT_DIR)/screenshot.png"

screenshot-self: ## DebugServer render of the content view, no grant needed
	@mkdir -p $(AGENT_DIR)
	@$(MAKE) --no-print-directory eval CMD="screenshot $(CURDIR)/$(AGENT_DIR)/screenshot.png"
	@echo "screenshot: $(AGENT_DIR)/screenshot.png"

inspect: ## Accessibility tree of the running app (needs Accessibility for the terminal)
	~/bin/axdump "$(BUNDLE_ID)" $(ARGS)

click: ## Press the control with accessibility identifier ID
	~/bin/axdump "$(BUNDLE_ID)" --click "$(ID)"

type: ## Type TEXT into the focused control
	~/bin/axdump "$(BUNDLE_ID)" --type "$(TEXT)"

key: ## Press a named key or shortcut: KEY=return | escape | up | down | cmd+s | cmd+shift+z
	~/bin/axdump "$(BUNDLE_ID)" --key "$(KEY)"

at: ## Element under screen point X,Y
	~/bin/axdump "$(BUNDLE_ID)" --at "$(X),$(Y)"

# CMD may carry JSON with double quotes: make eval CMD='action add {"title":"x"}'.
# The value is single-quoted for the shell, with embedded single quotes escaped.
quote = '$(subst ','\'',$(1))'

eval: ## Send CMD to the DEBUG build's DebugServer: state | action <name> <json> | screenshot <path>
	@test -f "$(PORT_FILE)" || { echo "eval: no port file at $(PORT_FILE) — is a DEBUG build running?" >&2; exit 1; }
	@printf '%s\n' $(call quote,$(CMD)) | nc -w 5 127.0.0.1 "$$(cat "$(PORT_FILE)")"

# ---------------------------------------------------------------------------
# Install and distribute
# ---------------------------------------------------------------------------

install: ## Release build into /Applications
	$(MAKE) build CONFIG=Release
	$(MAKE) stop
	ditto "$(DERIVED)/Build/Products/Release/$(APP_NAME).app" "/Applications/$(APP_NAME).app"
	@echo "installed /Applications/$(APP_NAME).app"

# Notarization signs with the Developer ID Application certificate of the same
# team the app is built with (project.yml: DEVELOPMENT_TEAM) and needs a
# notarytool keychain profile named `notary` (xcrun notarytool store-credentials).
notarize: ## Sign with Developer ID, notarize, staple, build a DMG
	@security find-identity -v -p codesigning | grep -q "Developer ID Application: .*(R43S29F4G5)" || { \
	  echo "notarize: no 'Developer ID Application' certificate for team R43S29F4G5 in the keychain" >&2; exit 1; }
	$(MAKE) build CONFIG=Release
	codesign --force --deep --options runtime --timestamp \
	  --sign "Developer ID Application" "$(DERIVED)/Build/Products/Release/$(APP_NAME).app"
	rm -f "$(DERIVED)/$(APP_NAME).dmg"
	create-dmg --volname "$(APP_NAME)" --window-size 480 300 --icon-size 96 \
	  --app-drop-link 360 140 "$(DERIVED)/$(APP_NAME).dmg" "$(DERIVED)/Build/Products/Release/$(APP_NAME).app"
	xcrun notarytool submit "$(DERIVED)/$(APP_NAME).dmg" --keychain-profile notary --wait
	xcrun stapler staple "$(DERIVED)/$(APP_NAME).dmg"
	@echo "notarized: $(DERIVED)/$(APP_NAME).dmg"

clean: stop ## Remove build products and the generated project
	rm -rf "$(DERIVED)" "$(PROJECT)" $(AGENT_DIR)
