FLUTTER ?= flutter
DART ?= dart

.PHONY: help deps generate generated-check analyze test verify check-secrets \
	run-macos run-web build-ios build-appbundle build-macos build-windows build-web

help:
	@echo "Theos App monorepo commands"
	@echo "  make deps             Resolve all package dependencies"
	@echo "  make generate         Regenerate Drift/Freezed/Riverpod code"
	@echo "  make generated-check  Regenerate and fail when tracked output changes"
	@echo "  make analyze          Analyze all five packages"
	@echo "  make test             Test all five packages"
	@echo "  make verify           Secret scan, generated check, analysis, and tests"
	@echo "  make run-macos        Run macOS with the local ERP2 test credential"
	@echo "  make run-web          Run Chrome with the local ERP2 test credential"
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

test:
	cd odoo_sdk && $(DART) test
	cd theos_pos_core && $(DART) test
	cd odoo_widgets && $(FLUTTER) test
	cd flutter_qweb && $(FLUTTER) test
	cd theos_pos && $(FLUTTER) test

check-secrets:
	./scripts/check_secrets.sh

verify: check-secrets generated-check analyze test

run-macos:
	./scripts/run_flutter_with_erp2.sh macos

run-web:
	./scripts/run_flutter_with_erp2.sh chrome

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
