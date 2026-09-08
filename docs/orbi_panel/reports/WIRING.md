# App wiring audit

## Delivered

`OrbiSessionComposition` is now the app-level boundary for the active
`AuthServicePort`, retained `SessionRuntime`, capability snapshot, and the
optional home/activity/sync/notification/document ports. `bootstrap` retains
one `SessionRuntime` instance and passes that same instance to
`NativeAuthService` and the composition; no second database/client owner is
created.

The router now has explicit routes for home, sales, cash, approvals,
activities, sync, notices, documents, and settings. Capability policy gates
business routes; the authenticated shell remains reachable while capability
loading is unavailable. Missing composition ports render “no configurado”
instead of an empty success. Home shows only capability-allowed links and an
explicit composition status.

## Audited fallbacks

- Sales/settings and missing composition services use `NotConfiguredPage`.
- Approval adapter remains the existing unavailable adapter until a real
  approval service is injected; its pending backend is not claimed as synced.
- Home/activity/sync feature defaults still exist for direct feature tests;
  the app router does not expose them as configured services without a port.
- Notification and preferences providers still require their documented
  bootstrap overrides (`notificationInboxPortProvider` and
  `sharedPreferencesProvider`); they are not opened by the router unless a
  composition supplies them.

## Pending real integrations

1. Activate a scope-backed home/activity/catalog service and inject its ports.
2. Inject approval, inbox/navigation, document-cache, and sync catalog ports
   from the active `SessionActivation`.
3. Replace the unavailable approval adapter and notification bootstrap guard
   with durable adapters, preserving capability and session revalidation.
4. Add backend health/auth and push/background-sync integrations separately;
   local routing does not imply either capability.

## Capability/company boundary

The current canonical `AuthProfile` contains server, database, user and
installation identity, but no `companyId` or `allowed_company_ids`. The login
bootstrap result likewise exposes only the authenticated user/API key, while
`RuntimeCapabilityService` explicitly requires a company ID. The local
`CapabilitySnapshotStore` is keyed by scope *and* company, so selecting `1` or
deriving a company from an unrelated catalog would be an unsafe fallback.

Accordingly the composition now derives capabilities reactively from
`AuthViewState` and derives catalogs/sync from the current `SessionActivation`,
but publishes no capability snapshot until a canonical company context is
provided. Offline restore can reuse a snapshot only after that context is
selected; logout tears down the runtime and removes the reactive capability
state. A follow-up contract must expose the server-selected company and
allowed companies (or a user-scoped company-context endpoint) before the
login-A/logout/login-B and restore-offline capability tests can be made
meaningful.

## Business composition factory

`theos_panel/lib/app/business_composition_factory.dart` adds an app-level
`OrbiBusinessCompositionFactory`. It accepts only the active
`SessionRuntime` and a matching `CapabilitySnapshot`; a stale lease, missing
activation or scope mismatch returns `null` and closes the previous graph.
Builders inject the runtime-owned `RuntimeSaleCommandPort` and
`SessionApprovalPort`, while the catalog builder may create
`RuntimeCatalogComposition` only for an activation with an Odoo client. An
offline restore therefore has no sync graph and cannot report configured
success. Re-composition on scope B replaces the scope A lease; no new
`SessionRuntime`, database owner or client is constructed by the factory.

Verification: `flutter analyze lib/app/business_composition_factory.dart
test/app/business_composition_factory_test.dart` — clean;
`flutter test test/app/business_composition_factory_test.dart` — 1 test OK.
The test uses an in-memory database owner, composes after A→B activation,
checks the approval graph follows the new lease, and confirms offline restore
does not create catalogs.

The router/providers now consume `businessCompositionProvider`, which rejects
an old business graph when its lease or capability scope no longer matches
`SessionRuntime.active`. Sales, approvals and catalog providers therefore
follow the same composition on scope changes instead of retaining stale ports.

When no supplied business graph exists, the provider now constructs one from
the active runtime: `DriftSaleCommandStore` resolves local/remote orders from
the owned Drift DB and enqueues idempotent confirmation commands;
`SessionApprovalPort` receives a durable `OfflineQueue` writer; and online
activations create `RuntimeCatalogComposition`. Offline restore keeps the
local sale/approval ports but exposes no catalog sync/RPC client. The factory
reuses the active lease and asynchronously closes the previous graph on
scope changes.

Bootstrap now injects lazy identity/capability adapters bound to the same
`SessionRuntime`: they read `active.client` only after activation, pass the
same owner lease to `RuntimeCapabilityService`, and never construct a second
client or database. Native login therefore publishes company identity and a
persisted capability snapshot, which makes the provider-generated business
ports available; logout/close invalidates the lease and the provider returns
null until the next authenticated scope.

Verification: `flutter analyze lib/app/bootstrap.dart` — clean;
`flutter test test/features/auth test/app/business_composition_factory_test.dart`
— 8 tests OK (including identity/scope restore and provider composition).

N04 is now closed: the notification provider returns an explicit unavailable
port when bootstrap has not supplied a runtime, whose stream reports a visible
`StateError` instead of throwing during provider construction. With an active
`SessionRuntime`, `SessionNotificationInboxPort` delegates to the existing
database-owned `RuntimeNotificationInbox` and validates lease scope plus
global/company partition before reads or mutations. Several routes still
intentionally use `NotConfiguredPage` while unrelated runtime ports are not
injected; no fallback found in the audited sales/approval/notification paths
reports a successful operation.

N04 verification: `flutter analyze lib/features/notifications/notification_inbox.dart
lib/app/notification_scope_adapter.dart test/features/notifications/notification_inbox_test.dart`
— clean; `flutter test test/features/notifications/notification_inbox_test.dart`
— 5 tests OK, including no-bootstrap and active-runtime scope/partition cases.

## N04 scope integration

The panel now exposes `SessionNotificationInboxPort` over
`RuntimeNotificationInbox`. It reads and mutates only the `AppDatabase` held
by the active `SessionRuntime`; it never creates a second database. Queries
derive `scopeKey` from the active lease and use `global` or
`company:<id>` from the effective capability snapshot. The system-ID registry
and presenter are initialized from the stable installation ID in bootstrap.

Notification taps use an allowlist and revalidate active session, company and
capability before routing. Unknown/invalid targets are rejected. Full
restart/scope migration coverage remains dependent on an activated runtime
factory in integration tests; no `active/default` sentinel is used by the
connected route.
