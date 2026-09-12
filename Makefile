FLUTTER ?= flutter
DART ?= dart

.PHONY: help deps generate generated-check analyze analyze-orbi test test-orbi verify check-secrets \
	run-macos run-web build-ios build-appbundle build-macos build-windows build-web \
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
	@echo "  make run-macos        Run macOS with the local ERP2 test credential"
	@echo "  make run-web          Run Chrome without any injected credential"
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
