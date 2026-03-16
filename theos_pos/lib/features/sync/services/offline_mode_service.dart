import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import '../../../shared/utils/error_utils.dart';
import '../../products/services/stock_sync_service.dart';

/// Configurable limits for offline mode preload (M10 improvement)
class OfflinePreloadLimits {
  /// Maximum number of products to preload (0 = unlimited)
  final int maxProducts;

  /// Maximum number of partners to preload (0 = unlimited)
  final int maxPartners;

  /// Whether to preload all products regardless of limit
  final bool preloadAllProducts;

  /// Whether to preload all partners regardless of limit
  final bool preloadAllPartners;

  const OfflinePreloadLimits({
    this.maxProducts = 5000,
    this.maxPartners = 5000,
    this.preloadAllProducts = false,
    this.preloadAllPartners = false,
  });

  /// Get effective product limit (null if unlimited)
  int? get effectiveProductLimit =>
      preloadAllProducts ? null : (maxProducts > 0 ? maxProducts : null);

  /// Get effective partner limit (null if unlimited)
  int? get effectivePartnerLimit =>
      preloadAllPartners ? null : (maxPartners > 0 ? maxPartners : null);

  Map<String, dynamic> toJson() => {
    'maxProducts': maxProducts,
    'maxPartners': maxPartners,
    'preloadAllProducts': preloadAllProducts,
    'preloadAllPartners': preloadAllPartners,
  };

  factory OfflinePreloadLimits.fromJson(Map<String, dynamic> json) {
    return OfflinePreloadLimits(
      maxProducts: json['maxProducts'] as int? ?? 5000,
      maxPartners: json['maxPartners'] as int? ?? 5000,
      preloadAllProducts: json['preloadAllProducts'] as bool? ?? false,
      preloadAllPartners: json['preloadAllPartners'] as bool? ?? false,
    );
  }

  /// Default limits for most use cases
  static const standard = OfflinePreloadLimits();

  /// Large business limits (more products/partners)
  static const large = OfflinePreloadLimits(
    maxProducts: 20000,
    maxPartners: 10000,
  );

  /// Unlimited - load everything
  static const unlimited = OfflinePreloadLimits(
    preloadAllProducts: true,
    preloadAllPartners: true,
  );
}

/// Simple on-demand offline mode configuration (FASE 4)
///
/// Features:
/// - Toggle offline mode on/off
/// - Pre-download data when activating
/// - Track preload status
/// - Configurable preload limits (M10 improvement)
class OfflineModeConfig {
  final bool isEnabled;
  final DateTime? activatedAt;
  final DateTime? lastPreloadAt;
  final PreloadStatus preloadStatus;
  final OfflinePreloadLimits preloadLimits;

  const OfflineModeConfig({
    this.isEnabled = false,
    this.activatedAt,
    this.lastPreloadAt,
    this.preloadStatus = PreloadStatus.idle,
    this.preloadLimits = const OfflinePreloadLimits(),
  });

  OfflineModeConfig copyWith({
    bool? isEnabled,
    DateTime? activatedAt,
    DateTime? lastPreloadAt,
    PreloadStatus? preloadStatus,
    OfflinePreloadLimits? preloadLimits,
  }) {
    return OfflineModeConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      activatedAt: activatedAt ?? this.activatedAt,
      lastPreloadAt: lastPreloadAt ?? this.lastPreloadAt,
      preloadStatus: preloadStatus ?? this.preloadStatus,
      preloadLimits: preloadLimits ?? this.preloadLimits,
    );
  }

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'activatedAt': activatedAt?.toIso8601String(),
    'lastPreloadAt': lastPreloadAt?.toIso8601String(),
    'preloadStatus': preloadStatus.name,
    'preloadLimits': preloadLimits.toJson(),
  };

  factory OfflineModeConfig.fromJson(Map<String, dynamic> json) {
    return OfflineModeConfig(
      isEnabled: json['isEnabled'] as bool? ?? false,
      activatedAt: json['activatedAt'] != null
          ? DateTime.parse(json['activatedAt'] as String)
          : null,
      lastPreloadAt: json['lastPreloadAt'] != null
          ? DateTime.parse(json['lastPreloadAt'] as String)
          : null,
      preloadStatus: PreloadStatus.values.firstWhere(
        (e) => e.name == json['preloadStatus'],
        orElse: () => PreloadStatus.idle,
      ),
      preloadLimits: json['preloadLimits'] != null
          ? OfflinePreloadLimits.fromJson(
              json['preloadLimits'] as Map<String, dynamic>,
            )
          : const OfflinePreloadLimits(),
    );
  }

  /// Duration since offline mode was activated
  Duration? get activeDuration {
    if (!isEnabled || activatedAt == null) return null;
    return DateTime.now().difference(activatedAt!);
  }
}

enum PreloadStatus { idle, inProgress, completed, failed }

/// Result of preload operation
class PreloadResult {
  final bool success;
  final int productsLoaded;
  final int partnersLoaded;
  final int stockRecordsLoaded;
  final Duration duration;
  final String? errorMessage;

  const PreloadResult({
    required this.success,
    this.productsLoaded = 0,
    this.partnersLoaded = 0,
    this.stockRecordsLoaded = 0,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'productsLoaded': productsLoaded,
    'partnersLoaded': partnersLoaded,
    'stockRecordsLoaded': stockRecordsLoaded,
    'durationMs': duration.inMilliseconds,
    'errorMessage': errorMessage,
  };
}

/// Service for on-demand offline mode
class OfflineModeService {
  static const String _configKey = 'offline_mode_config';
  static const String _lastPreloadResultKey = 'offline_mode_last_preload';

  final OdooClient? _odooClient;
  final StockSyncService? _stockSyncService;
  final AppDatabase _db;

  OfflineModeService({
    OdooClient? odooClient,
    StockSyncService? stockSyncService,
    required AppDatabase db,
  }) : _odooClient = odooClient,
       _stockSyncService = stockSyncService,
       _db = db;

  /// Load configuration from SharedPreferences
  Future<OfflineModeConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);
      if (jsonStr == null) return const OfflineModeConfig();
      return OfflineModeConfig.fromJson(
        json.decode(jsonStr) as Map<String, dynamic>,
      );
    } catch (e) {
      logger.e('[OfflineModeService] Error loading config: $e');
      return const OfflineModeConfig();
    }
  }

  /// Save configuration to SharedPreferences
  Future<void> saveConfig(OfflineModeConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, json.encode(config.toJson()));
      logger.d(
        '[OfflineModeService] Config saved: enabled=${config.isEnabled}',
      );
    } catch (e) {
      logger.e('[OfflineModeService] Error saving config: $e');
    }
  }

  /// Activate offline mode and preload data
  ///
  /// [limits] - Optional custom preload limits. If null, uses saved config limits.
  Future<PreloadResult> activateOfflineMode({
    void Function(String message, double progress)? onProgress,
    OfflinePreloadLimits? limits,
  }) async {
    logger.d('[OfflineModeService] Activating offline mode...');

    // Get current config for limits
    final currentConfig = await loadConfig();
    final effectiveLimits = limits ?? currentConfig.preloadLimits;

    // Save initial state
    await saveConfig(
      OfflineModeConfig(
        isEnabled: true,
        activatedAt: DateTime.now(),
        preloadStatus: PreloadStatus.inProgress,
        preloadLimits: effectiveLimits,
      ),
    );

    // Preload data with configured limits
    final result = await preloadData(
      onProgress: onProgress,
      limits: effectiveLimits,
    );

    // Update final state
    await saveConfig(
      OfflineModeConfig(
        isEnabled: true,
        activatedAt: DateTime.now(),
        lastPreloadAt: DateTime.now(),
        preloadStatus: result.success
            ? PreloadStatus.completed
            : PreloadStatus.failed,
        preloadLimits: effectiveLimits,
      ),
    );

    return result;
  }

  /// Deactivate offline mode
  Future<void> deactivateOfflineMode() async {
    logger.d('[OfflineModeService] Deactivating offline mode...');
    final config = await loadConfig();
    await saveConfig(config.copyWith(isEnabled: false));
  }

  /// Toggle offline mode
  Future<PreloadResult?> toggleOfflineMode({
    void Function(String message, double progress)? onProgress,
  }) async {
    final config = await loadConfig();
    if (config.isEnabled) {
      await deactivateOfflineMode();
      return null;
    } else {
      return await activateOfflineMode(onProgress: onProgress);
    }
  }

  /// Update preload limits without re-activating offline mode
  Future<void> updatePreloadLimits(OfflinePreloadLimits limits) async {
    final config = await loadConfig();
    await saveConfig(config.copyWith(preloadLimits: limits));
    logger.d(
      '[OfflineModeService] Preload limits updated: '
      'products=${limits.effectiveProductLimit ?? "unlimited"}, '
      'partners=${limits.effectivePartnerLimit ?? "unlimited"}',
    );
  }

  /// Preload all necessary data for offline mode
  ///
  /// [limits] - Optional preload limits. If null, uses default limits.
  Future<PreloadResult> preloadData({
    void Function(String message, double progress)? onProgress,
    OfflinePreloadLimits? limits,
  }) async {
    final startTime = DateTime.now();
    final effectiveLimits = limits ?? const OfflinePreloadLimits();

    if (_odooClient == null) {
      return const PreloadResult(
        success: false,
        errorMessage: 'No Odoo client available',
      );
    }

    logger.d(
      '[OfflineModeService] Starting data preload with limits: '
      'products=${effectiveLimits.effectiveProductLimit ?? "unlimited"}, '
      'partners=${effectiveLimits.effectivePartnerLimit ?? "unlimited"}',
    );
    onProgress?.call('Iniciando pre-carga...', 0.0);

    int productsLoaded = 0;
    int partnersLoaded = 0;
    int stockRecordsLoaded = 0;

    try {
      // 1. Preload products with configured limit
      onProgress?.call('Cargando productos...', 0.1);
      productsLoaded = await _preloadProducts(
        limit: effectiveLimits.effectiveProductLimit,
      );
      logger.d('[OfflineModeService] Products loaded: $productsLoaded');

      // 2. Preload partners with configured limit
      onProgress?.call('Cargando clientes...', 0.4);
      partnersLoaded = await _preloadPartners(
        limit: effectiveLimits.effectivePartnerLimit,
      );
      logger.d('[OfflineModeService] Partners loaded: $partnersLoaded');

      // 3. Preload stock by warehouse
      onProgress?.call('Cargando existencias...', 0.7);
      if (_stockSyncService != null) {
        final stockStats = await _stockSyncService.syncAllStock();
        stockRecordsLoaded = stockStats['products_synced'] ?? 0;
        logger.d('[OfflineModeService] Stock loaded: $stockRecordsLoaded');
      }

      onProgress?.call('Pre-carga completada', 1.0);

      final duration = DateTime.now().difference(startTime);
      final result = PreloadResult(
        success: true,
        productsLoaded: productsLoaded,
        partnersLoaded: partnersLoaded,
        stockRecordsLoaded: stockRecordsLoaded,
        duration: duration,
      );

      await _saveLastPreloadResult(result);
      logger.d(
        '[OfflineModeService] Preload completed in ${duration.inSeconds}s',
      );
      return result;
    } catch (e) {
      logger.e('[OfflineModeService] Preload failed: $e');

      final duration = DateTime.now().difference(startTime);
      final result = PreloadResult(
        success: false,
        productsLoaded: productsLoaded,
        partnersLoaded: partnersLoaded,
        stockRecordsLoaded: stockRecordsLoaded,
        duration: duration,
        errorMessage: friendlyErrorMessage(e),
      );

      await _saveLastPreloadResult(result);
      return result;
    }
  }

  /// Get last preload result
  Future<PreloadResult?> getLastPreloadResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_lastPreloadResultKey);
      if (jsonStr == null) return null;

      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PreloadResult(
        success: jsonData['success'] as bool,
        productsLoaded: jsonData['productsLoaded'] as int? ?? 0,
        partnersLoaded: jsonData['partnersLoaded'] as int? ?? 0,
        stockRecordsLoaded: jsonData['stockRecordsLoaded'] as int? ?? 0,
        duration: Duration(milliseconds: jsonData['durationMs'] as int? ?? 0),
        errorMessage: jsonData['errorMessage'] as String?,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get pending operations count
  Future<int> getPendingOperationsCount() async {
    final ops = await _db.select(_db.offlineQueue).get();
    return ops.length;
  }

  /// Watch pending operations count — reactive stream from Drift
  Stream<int> watchPendingOperationsCount() {
    return _db.select(_db.offlineQueue).watch().map((ops) => ops.length);
  }

  // ============ Private Methods ============

  /// Preload products with optional limit (null = unlimited)
  Future<int> _preloadProducts({int? limit}) async {
    try {
      // If no limit, we need to paginate to get all records
      if (limit == null) {
        return await _preloadProductsUnlimited();
      }

      final products = await _odooClient!.searchRead(
        model: 'product.product',
        domain: [
          ['sale_ok', '=', true],
          ['active', '=', true],
        ],
        fields: [
          'id',
          'name',
          'default_code',
          'list_price',
          'standard_price',
          'barcode',
          'categ_id',
          'uom_id',
          'active',
        ],
        limit: limit,
      );

      for (final product in products) {
        // Manual upsert for products
        final existing =
            await (_db.select(_db.productProduct)
                  ..where((t) => t.odooId.equals(product['id'] as int)))
                .getSingleOrNull();

        final companion = ProductProductCompanion(
          odooId: drift.Value(product['id'] as int),
          name: drift.Value(product['name'] as String? ?? ''),
          defaultCode: drift.Value(product['default_code'] as String?),
          listPrice: drift.Value(
            (product['list_price'] as num?)?.toDouble() ?? 0.0,
          ),
          standardPrice: drift.Value(
            (product['standard_price'] as num?)?.toDouble() ?? 0.0,
          ),
          barcode: drift.Value(product['barcode'] as String?),
          categId: drift.Value(odoo.extractMany2oneId(product['categ_id'])),
          uomId: drift.Value(odoo.extractMany2oneId(product['uom_id'])),
          active: drift.Value(product['active'] as bool? ?? true),
          writeDate: drift.Value(DateTime.now()),
        );

        if (existing != null) {
          await (_db.update(_db.productProduct)
                ..where((t) => t.odooId.equals(product['id'] as int)))
              .write(companion);
        } else {
          await _db.into(_db.productProduct).insert(companion);
        }
      }

      return products.length;
    } catch (e) {
      logger.e('[OfflineModeService] Error preloading products: $e');
      return 0;
    }
  }

  /// Preload all products in batches (for unlimited mode)
  Future<int> _preloadProductsUnlimited() async {
    const batchSize = 1000;
    int totalLoaded = 0;
    int offset = 0;

    try {
      while (true) {
        final products = await _odooClient!.searchRead(
          model: 'product.product',
          domain: [
            ['sale_ok', '=', true],
            ['active', '=', true],
          ],
          fields: [
            'id',
            'name',
            'default_code',
            'list_price',
            'standard_price',
            'barcode',
            'categ_id',
            'uom_id',
            'active',
          ],
          limit: batchSize,
          offset: offset,
        );

        if (products.isEmpty) break;

        for (final product in products) {
          // Manual upsert for products (unlimited)
          final existing =
              await (_db.select(_db.productProduct)
                    ..where((t) => t.odooId.equals(product['id'] as int)))
                  .getSingleOrNull();

          final companion = ProductProductCompanion(
            odooId: drift.Value(product['id'] as int),
            name: drift.Value(product['name'] as String? ?? ''),
            defaultCode: drift.Value(product['default_code'] as String?),
            listPrice: drift.Value(
              (product['list_price'] as num?)?.toDouble() ?? 0.0,
            ),
            standardPrice: drift.Value(
              (product['standard_price'] as num?)?.toDouble() ?? 0.0,
            ),
            barcode: drift.Value(product['barcode'] as String?),
            categId: drift.Value(odoo.extractMany2oneId(product['categ_id'])),
            uomId: drift.Value(odoo.extractMany2oneId(product['uom_id'])),
            active: drift.Value(product['active'] as bool? ?? true),
            writeDate: drift.Value(DateTime.now()),
          );

          if (existing != null) {
            await (_db.update(_db.productProduct)
                  ..where((t) => t.odooId.equals(product['id'] as int)))
                .write(companion);
          } else {
            await _db.into(_db.productProduct).insert(companion);
          }
        }

        totalLoaded += products.length;
        offset += batchSize;

        if (products.length < batchSize) break;
      }

      logger.d('[OfflineModeService] Preloaded all products: $totalLoaded');
      return totalLoaded;
    } catch (e) {
      logger.e(
        '[OfflineModeService] Error preloading products (unlimited): $e',
      );
      return totalLoaded;
    }
  }

  /// Preload partners with optional limit (null = unlimited)
  Future<int> _preloadPartners({int? limit}) async {
    try {
      // If no limit, we need to paginate to get all records
      if (limit == null) {
        return await _preloadPartnersUnlimited();
      }

      final partners = await _odooClient!.searchRead(
        model: 'res.partner',
        domain: [
          ['customer_rank', '>', 0],
          ['active', '=', true],
        ],
        fields: ['id', 'name', 'vat', 'email', 'phone', 'street', 'city'],
        limit: limit,
      );

      for (final partner in partners) {
        // Manual upsert for partners
        final existing =
            await (_db.select(_db.resPartner)
                  ..where((t) => t.odooId.equals(partner['id'] as int)))
                .getSingleOrNull();

        final companion = ResPartnerCompanion(
          odooId: drift.Value(partner['id'] as int),
          name: drift.Value(partner['name'] as String? ?? ''),
          vat: drift.Value(partner['vat'] as String?),
          email: drift.Value(partner['email'] as String?),
          phone: drift.Value(partner['phone'] as String?),
          street: drift.Value(partner['street'] as String?),
          city: drift.Value(partner['city'] as String?),
          writeDate: drift.Value(DateTime.now()),
        );

        if (existing != null) {
          await (_db.update(_db.resPartner)
                ..where((t) => t.odooId.equals(partner['id'] as int)))
              .write(companion);
        } else {
          await _db.into(_db.resPartner).insert(companion);
        }
      }

      return partners.length;
    } catch (e) {
      logger.e('[OfflineModeService] Error preloading partners: $e');
      return 0;
    }
  }

  /// Preload all partners in batches (for unlimited mode)
  Future<int> _preloadPartnersUnlimited() async {
    const batchSize = 1000;
    int totalLoaded = 0;
    int offset = 0;

    try {
      while (true) {
        final partners = await _odooClient!.searchRead(
          model: 'res.partner',
          domain: [
            ['customer_rank', '>', 0],
            ['active', '=', true],
          ],
          fields: ['id', 'name', 'vat', 'email', 'phone', 'street', 'city'],
          limit: batchSize,
          offset: offset,
        );

        if (partners.isEmpty) break;

        for (final partner in partners) {
          // Manual upsert for partners (unlimited)
          final existing =
              await (_db.select(_db.resPartner)
                    ..where((t) => t.odooId.equals(partner['id'] as int)))
                  .getSingleOrNull();

          final companion = ResPartnerCompanion(
            odooId: drift.Value(partner['id'] as int),
            name: drift.Value(partner['name'] as String? ?? ''),
            vat: drift.Value(partner['vat'] as String?),
            email: drift.Value(partner['email'] as String?),
            phone: drift.Value(partner['phone'] as String?),
            street: drift.Value(partner['street'] as String?),
            city: drift.Value(partner['city'] as String?),
            writeDate: drift.Value(DateTime.now()),
          );

          if (existing != null) {
            await (_db.update(_db.resPartner)
                  ..where((t) => t.odooId.equals(partner['id'] as int)))
                .write(companion);
          } else {
            await _db.into(_db.resPartner).insert(companion);
          }
        }

        totalLoaded += partners.length;
        offset += batchSize;

        if (partners.length < batchSize) break;
      }

      logger.d('[OfflineModeService] Preloaded all partners: $totalLoaded');
      return totalLoaded;
    } catch (e) {
      logger.e(
        '[OfflineModeService] Error preloading partners (unlimited): $e',
      );
      return totalLoaded;
    }
  }

  Future<void> _saveLastPreloadResult(PreloadResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastPreloadResultKey,
        json.encode(result.toJson()),
      );
    } catch (e) {
      logger.e('[OfflineModeService] Error saving preload result: $e');
    }
  }
}
