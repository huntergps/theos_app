# Theos App

The independent Orbi ERP application `theos_panel` is planned in the
[Orbi implementation handoff](docs/orbi_panel/README.md), including architecture,
notifications, extraction boundaries and an ordered backlog. That plan does not
claim that the new application is already implemented or verified.

Theos App is an offline-first Flutter client for selling, collecting payments,
and invoicing against Odoo 19.x and 20.x. The product targets iPad first, then
Android, macOS, Windows, and web.

The current sources of truth are the
[product specification](docs/specs/PROJECT_COMPLETION_V1.md), the
[technical plan](docs/specs/PROJECT_COMPLETION_V1_PLAN.md), the
[implementation tasks](docs/specs/PROJECT_COMPLETION_V1_TASKS.md), the current
[architecture](theos_pos/ARCHITECTURE.md), and CI. Audit and verification
reports are evidence from a specific run; they do not replace those sources of
truth.

Operational procedures live in the runbooks for
[installation and configuration](docs/runbooks/INSTALLATION.md),
[release builds](docs/runbooks/RELEASE.md), and
[offline recovery and support](docs/runbooks/OFFLINE_SUPPORT.md).

## Architecture

```text
theos_pos        Flutter UI, Riverpod composition, and platform shells
    │
    ├── theos_pos_core   Domain models, Drift persistence, and services
    ├── odoo_sdk         Odoo JSON-2 client, session, and offline sync
    ├── odoo_widgets     Reusable Fluent UI fields and builders
    └── flutter_qweb     QWeb interpretation and PDF generation
```

Features must use the unified Odoo client/repository boundary. Widgets do not
own tax, total, sync, or financial state transitions, and version differences
belong in capabilities or adapters rather than screens.

## Requirements

- Flutter 3.47.1 (Dart 3.13.1), matching CI.
- Native toolchains for the platform being built.
- Odoo credentials supplied at runtime or through ignored environment files.

The committed lockfiles were resolved with Flutter 3.47.1. Do not run a
dependency upgrade as part of an unrelated change; regenerate and commit a
lockfile only with the pinned SDK.

## Setup and verification

Run these commands from the repository root:

```bash
make deps
make generate
make analyze
make test
make check-secrets
```

`make verify` runs the secret scan, verifies generated Dart sources, analyzes
all five packages, and executes every existing suite. Individual commands are
shown in the `Makefile`; no workspace framework is required.

## Release builds

```bash
make build-ios       # macOS only; unsigned
make build-appbundle # Android App Bundle
make build-macos     # macOS only
make build-windows   # Windows only
make build-web       # configurable hosting base path
```

CI runs analysis and tests on Linux and builds iOS, Android, macOS, Windows,
and web with Flutter 3.47.1. Signing, store publication, and Odoo schema/module
changes on production still require separate authorization.

## Odoo integration configuration

Integration tests read `ODOO19_*` and `ODOO20_*` values from the environment.
Never commit server passwords, API keys, cookies, certificates, database dumps,
or populated `.env` files. `erp2` is a test tenant: it can be read and written
without case-by-case authorization. Production (`newerp`) stays off-limits —
`scripts/verify_orbi_erp2.py` rejects any host containing `newerp`, and this
never changes.
