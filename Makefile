FLUTTER ?= flutter
DART ?= dart

.PHONY: help deps generate generated-check analyze analyze-orbi test test-orbi verify check-secrets \
	run-macos run-web build-ios build-appbundle build-macos build-windows build-web \
	run-orbi-macos run-orbi-web dev-orbi-macos dev-orbi-web stop-orbi-web \
	build-orbi-web build-orbi-appbundle build-orbi-ios build-orbi-macos \
	build-orbi-windows build-orbi-linux

help:
	@echo "Theos App monorepo commands"
	@echo "  make deps             Resolve all package dependencies"
	@echo "  make generate         Regenerate Drift/Freezed/Riverpod code"
	@echo "  make generated-check  Regenerate and fail when tracked output changes"
	@echo "  make analyze          Analyze all existing packages"
	@echo "  make analyze-orbi     Analyze Orbi scaffold packages when present"
	@echo "  make test             Test all existing packages"
	@echo "  make test-orbi        Test Orbi scaffold packages when present"
	@echo "  make verify           Secret scan, generated check, analysis, and tests"
	@echo "  make run-macos        Run theos_pos (Fluent) on macOS with the local ERP2 test credential"
	@echo "  make run-web          Run theos_pos (Fluent) in Chrome without any injected credential"
	@echo "  make run-orbi-macos   Build theos_panel (Orbi) and open it on macOS; no terminal needed"
	@echo "  make run-orbi-web     Build theos_panel (Orbi) and open it in the browser; no terminal needed"
	@echo "  make stop-orbi-web    Stop the local server started by run-orbi-web"
	@echo "  make dev-orbi-macos   Hot-reload session for Orbi on macOS; NEEDS a real terminal"
	@echo "  make dev-orbi-web     Hot-reload session for Orbi in Chrome; NEEDS a real terminal"
	@echo "  make build-web        Build the web release"
	@echo "  make build-appbundle  Build the Android App Bundle release"
	@echo "  make build-ios        Build the unsigned iOS release"
	@echo "  make build-macos      Build the macOS release"
	@echo "  make build-windows    Build the Windows release"

deps:
	cd odoo_sdk && $(DART) pub get
	cd flutter_qweb && $(FLUTTER) pub get
	cd odoo_widgets && $(FLUTTER) pub get
	cd theos_pos_core && $(DART) pub get
	cd theos_pos && $(FLUTTER) pub get
	@if [ -f orbi_runtime/pubspec.yaml ]; then cd orbi_runtime && $(FLUTTER) pub get; else echo "SKIP: orbi_runtime scaffold is not present"; fi
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) pub get; else echo "SKIP: theos_panel scaffold is not present"; fi

generate:
	cd theos_pos_core && $(DART) run build_runner build
	cd theos_pos && $(DART) run build_runner build

generated-check: generate
	git diff --exit-code -- '*.g.dart' '*.freezed.dart'

analyze:
	cd odoo_sdk && $(DART) analyze
	cd theos_pos_core && $(DART) analyze
	cd odoo_widgets && $(FLUTTER) analyze
	cd flutter_qweb && $(FLUTTER) analyze
	cd theos_pos && $(FLUTTER) analyze

analyze-orbi:
	@if [ -f orbi_runtime/pubspec.yaml ]; then cd orbi_runtime && $(FLUTTER) analyze; else echo "SKIP: orbi_runtime scaffold is not present"; fi
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) analyze; else echo "SKIP: theos_panel scaffold is not present"; fi

test:
	cd odoo_sdk && $(DART) test
	cd theos_pos_core && $(DART) test
	cd odoo_widgets && $(FLUTTER) test
	cd flutter_qweb && $(FLUTTER) test
	cd theos_pos && $(FLUTTER) test

test-orbi:
	@if [ -f orbi_runtime/pubspec.yaml ]; then cd orbi_runtime && $(FLUTTER) test; else echo "SKIP: orbi_runtime scaffold is not present"; fi
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) test; else echo "SKIP: theos_panel scaffold is not present"; fi

build-orbi-web:
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) build web --release; else echo "SKIP: theos_panel scaffold is not present"; fi

build-orbi-appbundle:
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) build apk --release --config-only && $(FLUTTER) build appbundle --release --no-pub; else echo "SKIP: theos_panel scaffold is not present"; fi

build-orbi-ios:
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) build ios --release --no-codesign; else echo "SKIP: theos_panel scaffold is not present"; fi

build-orbi-macos:
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO FLUTTER_XCODE_CODE_SIGN_IDENTITY=- $(FLUTTER) build macos --release; else echo "SKIP: theos_panel scaffold is not present"; fi

build-orbi-windows:
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) build windows --release; else echo "SKIP: theos_panel scaffold is not present"; fi

build-orbi-linux:
	@if [ -f theos_panel/pubspec.yaml ]; then cd theos_panel && $(FLUTTER) build linux --release; else echo "SKIP: theos_panel scaffold is not present"; fi

check-secrets:
	./scripts/check_secrets.sh

verify: check-secrets generated-check analyze test

run-macos:
	./scripts/run_flutter_with_erp2.sh macos

run-web:
	@echo "Web builds never receive THEOS_ERP2_API_KEY; sign in from the app."
	cd theos_pos && $(FLUTTER) run -d chrome

# Orbi is launched without any injected credential on every target, desktop
# included. theos_panel has no String.fromEnvironment for a key: the only
# fromEnvironment in the package is the E2E harness, which reads
# Platform.environment at test time. Injecting one here would be dead weight
# that also hides the login screen we want to exercise.
#
# WHY run-* BUILDS AND OPENS INSTEAD OF CALLING `flutter run`:
# `flutter run` is an interactive session. Without a real TTY it waits forever
# and prints nothing, so from a non-interactive caller it looks like a hung,
# broken command (measured 2026-09-12). The plainly named target must be the
# one that cannot hang; hot reload lives under dev-* and says it needs a
# terminal.
ORBI_WEB_PORT ?= 8099

run-orbi-macos:
	@if [ ! -f theos_panel/pubspec.yaml ]; then echo "SKIP: theos_panel scaffold is not present"; exit 0; fi; \
	echo "==> Building Orbi for macOS (debug). First build takes several MINUTES; later ones are much faster."; \
	echo "    Orbi never receives an injected credential; sign in from the login screen."; \
	cd theos_panel && FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO FLUTTER_XCODE_CODE_SIGN_IDENTITY=- $(FLUTTER) build macos --debug || exit 1; \
	app=$$(ls -d build/macos/Build/Products/Debug/*.app 2>/dev/null | head -1); \
	if [ -z "$$app" ]; then echo "ERROR: no .app was produced under build/macos/Build/Products/Debug/"; exit 1; fi; \
	built=$$(find "$$app" -type f -print0 | xargs -0 stat -f '%m' | sort -rn | head -1); \
	echo "==> Opening $$app (freshest file inside: $$(date -r $$built '+%Y-%m-%d %H:%M:%S'))"; \
	open "$$app"

run-orbi-web:
	@if [ ! -f theos_panel/pubspec.yaml ]; then echo "SKIP: theos_panel scaffold is not present"; exit 0; fi; \
	echo "==> Building Orbi for the web. First build takes several MINUTES; later ones are much faster."; \
	echo "    Web builds never receive THEOS_ERP2_API_KEY; sign in from the app."; \
	cd theos_panel && $(FLUTTER) build web || exit 1; \
	if [ ! -f build/web/index.html ]; then echo "ERROR: build/web/index.html was not produced"; exit 1; fi; \
	built=$$(find build/web -type f -print0 | xargs -0 stat -f '%m' | sort -rn | head -1); \
	echo "==> Built (freshest file: $$(date -r $$built '+%Y-%m-%d %H:%M:%S'))"; \
	if [ -f build/.orbi_web_server.pid ] && kill -0 "$$(cat build/.orbi_web_server.pid)" 2>/dev/null; then \
		kill "$$(cat build/.orbi_web_server.pid)" 2>/dev/null || true; sleep 1; \
	fi; \
	( cd build/web && exec nohup python3 -m http.server $(ORBI_WEB_PORT) --bind 127.0.0.1 >../orbi_web_server.log 2>&1 ) & \
	echo $$! > build/.orbi_web_server.pid; \
	sleep 2; \
	echo "==> Serving on http://127.0.0.1:$(ORBI_WEB_PORT)/  (stop it with: make stop-orbi-web)"; \
	open "http://127.0.0.1:$(ORBI_WEB_PORT)/"

stop-orbi-web:
	@pidfile=theos_panel/build/.orbi_web_server.pid; \
	if [ -f "$$pidfile" ] && kill -0 "$$(cat $$pidfile)" 2>/dev/null; then \
		kill "$$(cat $$pidfile)" && echo "Stopped the Orbi web server (pid $$(cat $$pidfile))."; \
		rm -f "$$pidfile"; \
	else echo "No Orbi web server is running."; rm -f "$$pidfile"; fi

# Interactive sessions with hot reload. These REQUIRE a real terminal: run them
# yourself in a shell, never from a non-interactive caller, or they will hang
# with no output.
dev-orbi-macos:
	@if [ -f theos_panel/pubspec.yaml ]; then \
		echo "Interactive session: this NEEDS a real terminal. Use run-orbi-macos otherwise."; \
		cd theos_panel && $(FLUTTER) run -d macos; \
	else echo "SKIP: theos_panel scaffold is not present"; fi

dev-orbi-web:
	@if [ -f theos_panel/pubspec.yaml ]; then \
		echo "Interactive session: this NEEDS a real terminal. Use run-orbi-web otherwise."; \
		echo "Web builds never receive THEOS_ERP2_API_KEY; sign in from the app."; \
		cd theos_panel && $(FLUTTER) run -d chrome; \
	else echo "SKIP: theos_panel scaffold is not present"; fi

build-ios:
	cd theos_pos && $(FLUTTER) build ios --release --no-codesign

build-appbundle:
	cd theos_pos && $(FLUTTER) build appbundle --release

build-macos:
	cd theos_pos && $(FLUTTER) build macos --release

build-windows:
	cd theos_pos && $(FLUTTER) build windows --release

build-web:
	cd theos_pos && $(FLUTTER) build web --release
