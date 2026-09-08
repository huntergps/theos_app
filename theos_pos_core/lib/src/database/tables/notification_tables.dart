import 'package:drift/drift.dart';

class NotificationEntries extends Table {
  TextColumn get id => text()();
  TextColumn get scopeKey => text()();
  TextColumn get partitionKey => text()();
  IntColumn get companyId => integer().nullable()();
  TextColumn get sourceKey => text()();
  IntColumn get revision => integer()();
  TextColumn get kind => text()();
  TextColumn get severity => text()();
  TextColumn get titleKey => text()();
  TextColumn get bodyKey => text()();
  TextColumn get argsJson => text().withDefault(const Constant('{}'))();
  TextColumn get fallbackText => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get targetType => text().nullable()();
  TextColumn get targetReference => text().nullable()();
  TextColumn get origin => text()();
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(scope_key, partition_key, source_key)',
    "CHECK((partition_key = 'global' AND company_id IS NULL) OR (company_id > 0 AND partition_key = 'company:' || CAST(company_id AS TEXT)))",
  ];
}

class NotificationDeliveries extends Table {
  TextColumn get entryId => text()();
  TextColumn get scopeKey => text()();
  IntColumn get revision => integer()();
  TextColumn get channel => text()();
  TextColumn get state => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  IntColumn get systemId => integer().nullable()();
  DateTimeColumn get leaseExpiresAt => dateTime().nullable()();
  TextColumn get errorKey => text().nullable()();

  @override
  Set<Column> get primaryKey => {scopeKey, entryId, revision, channel};

  @override
  List<String> get customConstraints => [
    'UNIQUE(scope_key, entry_id, revision, channel)',
  ];
}

class NotificationCursors extends Table {
  TextColumn get scopeKey => text()();
  TextColumn get partitionKey => text()();
  TextColumn get source => text()();
  TextColumn get cursorValue => text().nullable()();
  BoolColumn get baselineComplete =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {scopeKey, partitionKey, source};
}

class NotificationSystemIds extends Table {
  TextColumn get scopeKey => text()();
  TextColumn get entryId => text()();
  TextColumn get channel => text()();
  IntColumn get systemId => integer()();

  @override
  Set<Column> get primaryKey => {scopeKey, entryId, channel};

  @override
  List<String> get customConstraints => ['UNIQUE(system_id)'];
}
