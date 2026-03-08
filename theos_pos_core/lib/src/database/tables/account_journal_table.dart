import 'package:drift/drift.dart';

/// AccountJournal - Diarios contables para pagos y ventas
class AccountJournal extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get type =>
      text()(); // sale, purchase, cash, bank, credit, general

  // SRI Configuration
  TextColumn get l10nEcEntity => text().nullable()(); // '001'
  TextColumn get l10nEcEmission => text().nullable()(); // '001'

  // Last known sequences (synced from Odoo)
  IntColumn get lastInvoiceSequence =>
      integer().withDefault(const Constant(0))();
  IntColumn get lastCreditNoteSequence =>
      integer().withDefault(const Constant(0))();
  IntColumn get lastDebitNoteSequence =>
      integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get companyId => integer().nullable()();
  TextColumn get companyName => text().nullable()();
  IntColumn get currencyId => integer().nullable()();
  TextColumn get currencyName => text().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(10))();

  // Card payment fields
  BoolColumn get isCardJournal =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get disponibleVentas =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get disponiblePagos =>
      boolean().withDefault(const Constant(false))();

  // Default card settings (stored as IDs, brands/deadlines resolved from their tables)
  IntColumn get defaultCardBrandId => integer().nullable()();
  IntColumn get defaultCardDeadlineCreditId => integer().nullable()();
  IntColumn get defaultCardDeadlineDebitId => integer().nullable()();

  // M2M relations stored as comma-separated IDs (empty string = no relations)
  TextColumn get cardBrandIds =>
      text().withDefault(const Constant(''))(); // e.g. "1,2,3"
  TextColumn get cardDeadlineCreditIds =>
      text().withDefault(const Constant(''))(); // e.g. "1,2,3"
  TextColumn get cardDeadlineDebitIds =>
      text().withDefault(const Constant(''))(); // e.g. "1,2,3"

  DateTimeColumn get writeDate => dateTime().nullable()();
}