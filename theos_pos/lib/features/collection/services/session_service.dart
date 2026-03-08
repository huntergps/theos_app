import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
// Datasources - using interfaces for Dependency Inversion
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

class SessionService {
  final Uuid _uuid = const Uuid();
  // Managers
  final CollectionSessionManager _sessionManager;
  final AccountPaymentManager _paymentManager;
  final CashOutManager _cashOutManager;
  final CollectionSessionDepositManager _depositManager;

  SessionService(
    DatabaseHelper dbHelper, {
    required CollectionSessionManager sessionManager,
    required AccountPaymentManager paymentManager,
    required CashOutManager cashOutManager,
    required CollectionSessionDepositManager depositManager,
  })  : _sessionManager = sessionManager,
        _paymentManager = paymentManager,
        _cashOutManager = cashOutManager,
        _depositManager = depositManager;

  // Singleton instance - now requires datasources to be injected
  // Consider using provider pattern instead of singleton
  static SessionService? _instance;
  static SessionService get instance {
    if (_instance == null) {
      throw StateError('SessionService not initialized. Use provider instead.');
    }
    return _instance!;
  }

  static void initialize(SessionService service) {
    _instance = service;
  }

  Future<List<CollectionConfig>> getConfigs() async {
    return collectionConfigManager.searchLocal();
  }

  Future<CollectionSession?> getSession(int id) async {
    return _sessionManager.getSessionById(id);
  }

  /// Opens a new session locally
  /// Creates locally first, then returns immediately for UI responsiveness
  /// The caller should trigger background sync separately
  Future<CollectionSession> openSession(
    CollectionConfig config,
    double openingBalance,
    int userId,
    String userName,
  ) async {
    final sessionUuid = _uuid.v4();

    // Generate a unique negative temporary ID based on timestamp
    // This prevents UNIQUE constraint violations when multiple sessions are created locally
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final newSession = CollectionSession(
      id: tempId, // Unique temporary local ID (will be replaced with Odoo ID after sync)
      sessionUuid: sessionUuid,
      name:
          '${config.name}/$sessionUuid', // Temporary name (will be replaced with Odoo sequence)
      state: SessionState.openingControl,
      configId: config.id,
      configName: config.name,
      companyId: config.companyId,
      companyName: config.companyName,
      userId: userId,
      userName: userName,
      cashRegisterBalanceStart: openingBalance,
      startAt: DateTime.now(),
      isSynced: false, // Will be synced in background
    );

    await _sessionManager.smartUpsert(newSession);
    return newSession;
  }

  /// Checks if there's an existing local session for a config that hasn't been synced
  Future<bool> hasUnsyncedSessionForConfig(int configId) async {
    final sessions = await _sessionManager.getAllSessions();
    return sessions.any(
      (s) =>
          s.configId == configId &&
          (!s.isSynced || s.id < 0) &&
          s.state != SessionState.closed,
    );
  }

  /// Calculates the theoretical cash balance
  /// Formula: Start + Cash Payments - Cash Outs - Cash Deposits
  double computeCashBalance(
    CollectionSession session,
    List<AccountPayment> payments,
    List<CashOut> cashOuts,
    List<CollectionSessionDeposit> deposits,
  ) {
    // 1. Sum cash payments (only paid/in_process)
    final cashPayments = payments
        .where(
          (p) =>
              p.paymentMethodCategory == 'cash' &&
              ['paid', 'in_process'].contains(p.state),
        )
        .fold<double>(0.0, (sum, p) => sum + p.amount);

    // 2. Sum Cash Outs (only posted or draft if we want to include them in theoretical)
    // Odoo includes draft in theoretical balance usually?
    // In Odoo: total_cash_outs = sum(session.cash_out_ids.mapped('amount'))
    // It sums ALL cash outs linked to the session.
    final totalCashOuts = cashOuts.fold<double>(
      0.0,
      (sum, c) => sum + c.amount,
    );

    // 3. Sum Cash Deposits (only cash type)
    // In Odoo: total_cash_deposits = sum(session.deposit_ids.filtered(lambda x: x.deposit_type == 'cash').mapped('amount'))
    final totalCashDeposits = deposits
        .where((d) => d.depositType == DepositType.cash)
        .fold<double>(0.0, (sum, d) => sum + d.amount);

    return session.cashRegisterBalanceStart +
        cashPayments -
        totalCashOuts -
        totalCashDeposits;
  }

  /// Classifies a payment based on its properties (Invoice vs Debt vs Advance)
  String classifyPayment(AccountPayment payment, List<int> sessionInvoiceIds) {
    if (payment.invoiceId == null) {
      return 'debt'; // Default to debt for payments without invoice
    }
    if (sessionInvoiceIds.contains(payment.invoiceId)) {
      return 'invoice_day';
    } else {
      return 'debt';
    }
  }

  /// Updates the session totals and breakdown
  Future<void> updateSessionTotals(CollectionSession session) async {
    final payments = await _paymentManager.getBySessionId(session.id);
    final cashOuts = await _cashOutManager.getBySessionId(session.id);
    final deposits = await _depositManager.getBySessionId(session.id);

    // Calculate totals
    double totalCash = 0;
    double totalCards = 0;

    for (final p in payments) {
      if (p.paymentMethodCategory == 'cash') totalCash += p.amount;
      if (p.paymentMethodCategory == 'card_credit' ||
          p.paymentMethodCategory == 'card_debit') {
        totalCards += p.amount;
      }
    }

    final balanceEnd = computeCashBalance(
      session,
      payments,
      cashOuts,
      deposits,
    );
    final difference = session.cashRegisterBalanceEndReal - balanceEnd;

    final updatedSession = session.copyWith(
      totalCash: totalCash,
      totalCards: totalCards,
      cashRegisterBalanceEnd: balanceEnd,
      cashRegisterDifference: difference,
    );

    await _sessionManager.smartUpsert(updatedSession);
  }
}
