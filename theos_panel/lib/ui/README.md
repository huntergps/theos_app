# Orbi UI

This directory contains the presentation layer for the Orbi panel. Its pieces
are grouped by responsibility:

- `bindings/` contains typed editing state and record selection controllers.
  Field bindings expose values, save callbacks and save/conflict status without
  making widgets aware of storage or transport details. They are not database
  records and do not independently decide business permissions.
- `components/` contains reusable controls and record surfaces. Record grid/list
  implementations live under `components/records/`; bound fields live under
  `components/fields/`. Their old paths are compatibility exports for existing
  imports; `orbi_components.dart` still holds the existing shared screen controls.
- `layouts/` contains responsive composition shared by screens, such as the
  adaptive wide/compact layout.

The runtime/core owns observable data, persistence, synchronization and actions.
Widgets consume bindings/controllers and request typed actions; they do not own
business data or durable operations.

UI widgets must not execute SQL, access Odoo directly, or infer authorization
from role names. Those concerns belong to the runtime and its authorized
adapters. This organization intentionally adds no package or dependency.

New consumers should import the implementation's responsibility folder. Old
imports remain valid during gradual adoption; do not copy implementations into
both locations. Feature-specific forms stay in `features/<area>/`, not in this
shared directory. Theme configuration remains in `app/theme/`.

Reactive flow: local repository observation -> screen adapter -> binding or
record controller -> widget. Edits return through the owning draft/use case.
The widget owns focus/caret, not an independent persistent copy of the record.
Extracting a package is deferred until there is a real second application
consumer with compatible UI needs. `odoo_widgets` remains Fluent-based and is
not a dependency of this Material UI library.
