# F01 · CI/build integration

## Changes

- `Makefile` now resolves, analyzes, and tests `orbi_runtime` and `theos_panel`
  when their `pubspec.yaml` files exist. Missing scaffold directories are
  reported as `SKIP`, not represented as passing package results.
- CI quality runs those two conditional validations after the existing package
  checks.
- Existing Ubuntu, macOS, and Windows build jobs also build `theos_panel` on
  their capable host when its scaffold exists. Added explicit scaffold builds
  for Android App Bundle and Linux desktop on Ubuntu, and unsigned iOS on
  macOS. Existing `theos_pos` builds and artifact paths remain unchanged.

## Evidence

- At initial integration the scaffolds were absent; the concurrent workspace
  later exposed `theos_panel/pubspec.yaml`. No release build is certified here:
  a local probe was stopped while the concurrently-created scaffold was still
  changing, so CI remains the authoritative host-specific build.
- No six-platform support is asserted: Linux, iOS, Android, web, macOS, and
  Windows are only configured per capable host; configuration is not a claim
  that the scaffold is functional or release-ready.
- No ERP2 credentials, secrets, or integration tests were added.

## Validation and limits

- `make -n analyze-orbi`, `make -n test-orbi`, and all six `build-orbi-*`
  targets validate Make expansion; YAML Psych and `git diff --check` pass.
- YAML syntax was checked structurally with Ruby Psych if available.
- Full Flutter analysis/tests/builds for Orbi cannot run until F01 creates both
  packages; platform builds remain host/toolchain dependent. The local host is
  macOS, so Linux/Android CI builds were not executed locally.
