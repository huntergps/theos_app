# Conflict Resolution Strategies

This document describes the conflict resolution strategies available in `odoo_offline_core` and provides guidance on when to use each one.

## Overview

Conflicts occur when data modified offline is also modified on the server before synchronization. The `odoo_offline_core` package detects conflicts by comparing `write_date` timestamps and provides four resolution strategies.

## How Conflicts Are Detected

```
Local Timeline:
  T1: User modifies record (local write_date = T1)
  T2: User queues offline operation

Server Timeline:
  T3: Another user modifies same record (server write_date = T3)

Sync Time:
  T4: Local app syncs → CONFLICT (T1 < T3)
```

The `ConflictInfo` class captures all relevant data:

```dart
class ConflictInfo {
  final int operationId;
  final String model;
  final int? recordId;
  final DateTime localWriteDate;
  final DateTime serverWriteDate;
  final Map<String, dynamic> localValues;
  final Map<String, dynamic>? serverValues;
}
```

## Resolution Strategies

### 1. `keepLocal` - Local Wins

**Behavior:** Overwrites server data with local changes.

**When to Use:**
- User has explicit authority over their data
- Mobile salesperson updating their own orders
- Personal preferences or settings
- When local data is considered more recent/accurate

**Example:**
```dart
Future<void> resolveWithLocalWins(ConflictInfo conflict) async {
  // Force write local values to server
  await odooClient.write(
    model: conflict.model,
    ids: [conflict.recordId!],
    values: conflict.localValues,
  );

  await database.resolveConflict(
    conflict.operationId,
    resolution: 'local',
  );
}
```

**Risks:**
- May overwrite important server-side changes
- Other users' work may be lost

---

### 2. `keepServer` - Server Wins

**Behavior:** Discards local changes and accepts server data.

**When to Use:**
- Master data that should only be modified on server
- Price lists, product catalogs, tax rates
- Data controlled by administrators
- When server is the source of truth

**Example:**
```dart
Future<void> resolveWithServerWins(ConflictInfo conflict) async {
  // Fetch latest server data
  final serverData = await odooClient.read(
    model: conflict.model,
    ids: [conflict.recordId!],
  );

  // Update local database with server values
  await localRepository.update(conflict.recordId!, serverData.first);

  // Remove the queued operation
  await database.removeOperation(conflict.operationId);

  await database.resolveConflict(
    conflict.operationId,
    resolution: 'server',
  );
}
```

**Risks:**
- User's local work is lost
- May frustrate users if not communicated clearly

---

### 3. `merge` - Field-Level Merge

**Behavior:** Combines local and server changes at the field level.

**When to Use:**
- Collaborative editing scenarios
- When different fields are modified locally vs. server
- Complex records with independent sections
- When preserving both sets of changes is important

**Algorithm:**
```
For each field:
  - If only local changed → use local value
  - If only server changed → use server value
  - If both changed → use most recent (by timestamp) or prompt user
```

**Example:**
```dart
Future<void> resolveWithMerge(ConflictInfo conflict) async {
  final merged = <String, dynamic>{};
  final serverValues = conflict.serverValues ?? {};

  // Get original values (before any changes)
  final original = await getOriginalValues(conflict.recordId!);

  for (final field in {...conflict.localValues.keys, ...serverValues.keys}) {
    final localValue = conflict.localValues[field];
    final serverValue = serverValues[field];
    final originalValue = original[field];

    final localChanged = localValue != originalValue;
    final serverChanged = serverValue != originalValue;

    if (localChanged && !serverChanged) {
      merged[field] = localValue;
    } else if (!localChanged && serverChanged) {
      merged[field] = serverValue;
    } else if (localChanged && serverChanged) {
      // Both changed - use most recent
      if (conflict.localWriteDate.isAfter(conflict.serverWriteDate)) {
        merged[field] = localValue;
      } else {
        merged[field] = serverValue;
      }
    }
  }

  // Write merged values
  await odooClient.write(
    model: conflict.model,
    ids: [conflict.recordId!],
    values: merged,
  );

  await database.resolveConflict(
    conflict.operationId,
    resolution: 'merged',
  );
}
```

**Risks:**
- Complex to implement correctly
- May produce unexpected combinations
- Requires tracking original values

---

### 4. `skip` - Manual Resolution

**Behavior:** Keeps the operation in queue for manual review.

**When to Use:**
- High-value or sensitive data
- Financial transactions
- When automatic resolution is too risky
- Compliance requirements mandate human review

**Example:**
```dart
Future<void> resolveWithSkip(ConflictInfo conflict) async {
  // Store conflict for later review
  await database.storeConflict(
    operationId: conflict.operationId,
    model: conflict.model,
    recordId: conflict.recordId!,
    localValues: conflict.localValues,
    serverValues: conflict.serverValues ?? {},
    localWriteDate: conflict.localWriteDate,
    serverWriteDate: conflict.serverWriteDate,
  );

  // Notify user
  notificationService.show(
    'Conflict detected in ${conflict.model}. Manual review required.',
  );

  await database.resolveConflict(
    conflict.operationId,
    resolution: 'skipped',
  );
}
```

**UI for Manual Resolution:**
```dart
class ConflictResolutionDialog extends StatelessWidget {
  final ConflictInfo conflict;

  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Conflict in ${conflict.model}'),
      content: Column(
        children: [
          Text('Your changes:'),
          JsonViewer(conflict.localValues),
          Text('Server changes:'),
          JsonViewer(conflict.serverValues),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => resolve(ConflictResolutionStrategy.keepLocal),
          child: Text('Keep Mine'),
        ),
        TextButton(
          onPressed: () => resolve(ConflictResolutionStrategy.keepServer),
          child: Text('Keep Server'),
        ),
        TextButton(
          onPressed: () => showMergeEditor(),
          child: Text('Merge...'),
        ),
      ],
    );
  }
}
```

---

## Best Practices

### 1. Choose Strategy by Model

```dart
ConflictResolutionStrategy getStrategyForModel(String model) {
  return switch (model) {
    // Master data - server wins
    'product.product' => ConflictResolutionStrategy.keepServer,
    'product.pricelist' => ConflictResolutionStrategy.keepServer,
    'account.tax' => ConflictResolutionStrategy.keepServer,

    // User-owned data - local wins
    'sale.order' => ConflictResolutionStrategy.keepLocal,
    'res.partner' => ConflictResolutionStrategy.merge,

    // Financial - manual review
    'account.move' => ConflictResolutionStrategy.skip,
    'account.payment' => ConflictResolutionStrategy.skip,

    // Default
    _ => ConflictResolutionStrategy.skip,
  };
}
```

### 2. Log All Resolutions

```dart
Future<void> resolveConflict(
  ConflictInfo conflict,
  ConflictResolutionStrategy strategy,
) async {
  // Log for audit trail
  await database.logSyncOperation(
    model: conflict.model,
    method: 'conflict_resolution',
    odooId: conflict.recordId,
    localId: conflict.operationId,
    result: strategy.name,
    errorMessage: jsonEncode({
      'local_values': conflict.localValues,
      'server_values': conflict.serverValues,
      'local_write_date': conflict.localWriteDate.toIso8601String(),
      'server_write_date': conflict.serverWriteDate.toIso8601String(),
    }),
  );

  // Apply resolution
  await applyResolution(conflict, strategy);
}
```

### 3. Notify Users

```dart
void notifyConflictResolution(
  ConflictInfo conflict,
  ConflictResolutionStrategy strategy,
) {
  final message = switch (strategy) {
    ConflictResolutionStrategy.keepLocal =>
      'Your changes were applied to ${conflict.model}',
    ConflictResolutionStrategy.keepServer =>
      'Server changes were applied to ${conflict.model}',
    ConflictResolutionStrategy.merge =>
      'Changes were merged for ${conflict.model}',
    ConflictResolutionStrategy.skip =>
      'Conflict in ${conflict.model} requires review',
  };

  showNotification(message);
}
```

### 4. Prevent Conflicts

The best conflict is one that never happens:

```dart
// 1. Use optimistic locking
await odooClient.write(
  model: 'sale.order',
  ids: [orderId],
  values: {
    ...changes,
    'write_date': expectedWriteDate, // Will fail if changed
  },
);

// 2. Lock records during editing
await odooClient.call(
  model: 'sale.order',
  method: 'action_lock',
  args: [orderId],
);

// 3. Sync frequently
Timer.periodic(Duration(minutes: 5), (_) => syncService.sync());

// 4. Show real-time updates via WebSocket
wsService.eventsOfType<OdooRecordEvent>().listen((event) {
  if (event.model == 'sale.order' && isEditing(event.recordId)) {
    showWarning('This order was modified by another user');
  }
});
```

---

## Conflict Resolution Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    SYNC OPERATION                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                ┌─────────────────────┐
                │ Check write_date    │
                │ local vs server     │
                └──────────┬──────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
    ┌─────────────────┐      ┌─────────────────┐
    │ No Conflict     │      │ CONFLICT        │
    │ (sync normally) │      │ Detected        │
    └─────────────────┘      └────────┬────────┘
                                      │
                                      ▼
                           ┌─────────────────────┐
                           │ Get Strategy        │
                           │ for Model           │
                           └──────────┬──────────┘
                                      │
         ┌────────────┬───────────────┼───────────────┬────────────┐
         │            │               │               │            │
         ▼            ▼               ▼               ▼            │
   ┌──────────┐ ┌──────────┐  ┌──────────┐  ┌──────────┐          │
   │keepLocal │ │keepServer│  │  merge   │  │   skip   │          │
   │          │ │          │  │          │  │          │          │
   │ Overwrite│ │ Discard  │  │ Combine  │  │ Queue for│          │
   │ server   │ │ local    │  │ fields   │  │ review   │          │
   └────┬─────┘ └────┬─────┘  └────┬─────┘  └────┬─────┘          │
        │            │             │             │                 │
        └────────────┴─────────────┴─────────────┘                 │
                           │                                       │
                           ▼                                       │
                ┌─────────────────────┐                           │
                │ Log Resolution      │                           │
                │ Notify User         │                           │
                │ Update Database     │                           │
                └─────────────────────┘                           │
                                                                   │
                           ┌───────────────────────────────────────┘
                           │ (if skip)
                           ▼
                ┌─────────────────────┐
                │ Show Conflict UI    │
                │ User Chooses        │
                │ Resolution          │
                └─────────────────────┘
```

---

## See Also

- `sync_types.dart` - `ConflictInfo` and `ConflictResolutionStrategy` definitions
- `offline_queue_processor.dart` - Queue processing with conflict detection
- `i_odoo_database.dart` - `storeConflict()` and `resolveConflict()` interface
