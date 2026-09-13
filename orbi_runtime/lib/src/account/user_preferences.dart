import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart' show OdooException, parseOdooString;
import 'package:theos_pos_core/theos_pos_core.dart';

import '../sales/sale_runtime_adapters.dart' show SaleOdooActions;

/// Snapshot de los campos que Orbi edita — la misma lista que
/// `theos_pos`'s `UserPreferencesDialog` guarda DE VERDAD (ver
/// `theos_pos/lib/shared/widgets/user_preferences_dialog.dart:461-575`), más
/// `notification_type`: theos_pos lo MUESTRA (`user_preferences_tab_general.dart`,
/// `RadioGroup`) pero nunca lo incluye en su diff — orden del dueño: "ahí
/// puedes saber qué mostrar", un control de adorno no cuenta como guía, así
/// que en Orbi sí funciona.
///
/// Quedan fuera a propósito, por ser decorativos incluso en theos_pos:
/// posición del chatter, ubicación de trabajo, horario de trabajo y contacto
/// de emergencia (`user_preferences_tab_calendar.dart`/`_tab_private.dart`).
/// Correo y teléfono de trabajo se muestran de sólo lectura (theos_pos los
/// muestra editables pero tampoco los guarda nunca — no hay que replicar ese
/// hueco).
final class UserPreferences {
  const UserPreferences({
    required this.userId,
    required this.name,
    required this.login,
    required this.availableUserFields,
    required this.availablePartnerFields,
    this.partnerId,
    this.lang,
    this.tz,
    this.signature,
    this.notificationType,
    this.warehouseId,
    this.mobilePhone,
    this.workEmail,
    this.workPhone,
    this.avatar128,
    this.email,
    this.phone,
    this.street,
    this.street2,
    this.city,
    this.zip,
    this.countryId,
    this.stateId,
  });

  final int userId;
  final String name;
  final String login;
  final int? partnerId;

  /// Nombres de campo de `res.users` que el servidor conectado de verdad
  /// tiene. `lang`/`tz`/`signature` son del módulo `base` (siempre
  /// presentes); `mobile_phone` (`hr`), `property_warehouse_id`
  /// (`sale_stock`) y `notification_type` (`mail`) pueden faltar según el
  /// servidor — Mepriga, por ejemplo, no tiene `hr` ni `sale_stock`. Sin red
  /// esto sale de la última sonda conocida — ver
  /// [FieldAvailabilityCache.optionalUserFields].
  final Set<String> availableUserFields;

  /// Los ocho campos de `res.partner` que edita esta pantalla son del
  /// módulo `base` (siempre instalado) — este set siempre trae los ocho.
  final Set<String> availablePartnerFields;

  // `res.users` — dev_odoo20/odoo/odoo/addons/base/models/res_users.py:250
  // (lang), :251 (tz), :216 (signature).
  final String? lang;
  final String? tz;
  final String? signature;
  // `addons/mail/models/res_users.py:37`.
  final String? notificationType;
  // `dev_odoo20/odoo/addons/sale_stock/models/res_users.py:9`.
  final int? warehouseId;
  // `dev_odoo20/odoo/addons/hr/models/res_users.py:103`.
  final String? mobilePhone;
  // `addons/hr/models/res_users.py:102,104` — `related_employee_field`, igual
  // origen que `mobile_phone`. Sólo lectura en el diálogo: theos_pos los
  // muestra editables pero nunca los guarda (ver la nota de la clase), así
  // que replicar eso habría sido inventar una función que ni theos_pos tiene.
  final String? workEmail;
  final String? workPhone;
  // Sólo lectura: `avatar_mixin.py:47`, campo `compute`. La escritura real de
  // foto va a `image_1920` (`image_mixin.py:12`), nunca a este campo.
  final String? avatar128;

  // `res.partner` (módulo `base`) —
  // `dev_odoo20/odoo/odoo/addons/base/models/res_partner.py`: `street`:350,
  // `street2`:351, `zip`:352, `city`:353, `state_id`:354, `country_id`:355,
  // `email`:359, `phone`:363.
  final String? email;
  final String? phone;
  final String? street;
  final String? street2;
  final String? city;
  final String? zip;
  final int? countryId;
  final int? stateId;
}

/// Valor de catálogo identificado por el código Odoo (idioma ISO, zona
/// horaria pytz, tipo de notificación) — la clave real que espera la
/// escritura, no un id numérico.
final class UserPreferencesCodeOption {
  const UserPreferencesCodeOption(this.code, this.name);
  final String code;
  final String name;
}

/// Valor de catálogo identificado por id numérico (país, provincia, almacén).
final class UserPreferencesOption {
  const UserPreferencesOption(this.id, this.name);
  final int id;
  final String name;
}

/// Un grupo de seguridad asignado al usuario — igual forma que
/// `UserGroupInfo` en `theos_pos/lib/shared/widgets/user_preferences_dialog.dart:42-54`,
/// reproducido acá porque `theos_panel` no puede importar `theos_pos`.
final class UserGroupInfo {
  const UserGroupInfo({
    required this.id,
    required this.name,
    this.fullName,
    this.xmlId,
  });
  final int id;
  final String name;
  final String? fullName;
  final String? xmlId;
}

final class UserPreferencesCatalogs {
  const UserPreferencesCatalogs({
    required this.languages,
    required this.timezones,
    required this.notificationTypes,
    required this.countries,
    required this.states,
    required this.warehouses,
  });

  final List<UserPreferencesCodeOption> languages;
  final List<UserPreferencesCodeOption> timezones;
  final List<UserPreferencesCodeOption> notificationTypes;
  final List<UserPreferencesOption> countries;

  /// Vacío cuando `catalogs({countryId: null})` — igual que theos_pos, las
  /// provincias sólo se piden una vez elegido un país.
  final List<UserPreferencesOption> states;
  final List<UserPreferencesOption> warehouses;
}

/// El diff a escribir, ya separado por modelo — igual que
/// `UserRepository.updateUserAndPartner` en theos_pos
/// (`theos_pos/lib/features/users/repositories/user_repository.dart:151`):
/// cada mapa trae sólo los campos que de verdad cambiaron. [partnerId] va
/// aparte porque `save` no lo recibe como parámetro propio — lo trae el
/// propio diff, tomado de la [UserPreferences] cargada.
final class UserPreferencesChange {
  const UserPreferencesChange({
    this.partnerId,
    this.userValues = const {},
    this.partnerValues = const {},
  });

  final int? partnerId;
  final Map<String, dynamic> userValues;
  final Map<String, dynamic> partnerValues;

  bool get isEmpty => userValues.isEmpty && partnerValues.isEmpty;
}

/// Leer y guardar las preferencias personales del usuario — SIEMPRE local
/// primero, nunca RPC directa. Orden del dueño: «todo debe ser offline».
/// [watch]/[catalogs]/[watchGroups] leen sólo de Drift, sin red, y nunca
/// fallan por falta de conexión. [save] escribe la fila local y encola la
/// escritura remota en la MISMA transacción — el despachador real vive en
/// `OdooOfflineOperationAdapter` (`../sales/sale_runtime_adapters.dart`).
abstract interface class UserPreferencesPort {
  /// `null` si el usuario aún no está en `res_users` local (todavía no
  /// sincronizado). Nunca lanza por falta de red: es una tabla Drift.
  Stream<UserPreferences?> watch(int userId);

  /// [countryId] filtra `states`; `null` los deja vacíos, igual que
  /// theos_pos antes de elegir un país.
  Future<UserPreferencesCatalogs> catalogs({int? countryId});

  /// `res_users.group_ids` (CSV) resuelto contra `res_groups` — igual que
  /// `UserRepository.watchCurrentUserGroupIds()` en theos_pos, pero
  /// parametrizado por `userId` en vez de fijo al usuario actual.
  Stream<List<UserGroupInfo>> watchGroups(int userId);

  /// Upsert local optimista + encolado durable en una sola transacción.
  /// Devuelve `true` en cuanto la escritura LOCAL se confirmó — nunca
  /// rechaza por falta de red, porque nunca intenta hablar con el servidor
  /// directamente. El resultado remoto (aplicado/rechazado) lo resuelve el
  /// despachador, después, de forma asíncrona.
  Future<bool> save(int userId, UserPreferencesChange change);
}

/// Implementación 100% local — sin `SaleOdooActions`, sin `isOnline`: no hay
/// nada en esta clase que necesite red. La probamos con `AppDatabase(NativeDatabase.memory())`.
final class LocalUserPreferencesPort implements UserPreferencesPort {
  const LocalUserPreferencesPort({required this.database, required this.queue});

  final AppDatabase database;
  final OfflineQueueDataSource queue;

  @override
  Stream<UserPreferences?> watch(int userId) {
    final query = database.select(database.resUsers)
      ..where((t) => t.odooId.equals(userId));
    return query.watchSingleOrNull().asyncMap((userRow) async {
      if (userRow == null) return null;

      ResPartnerData? partnerRow;
      final partnerId = userRow.partnerId;
      if (partnerId != null) {
        partnerRow = await (database.select(
          database.resPartner,
        )..where((t) => t.odooId.equals(partnerId))).getSingleOrNull();
      }

      final availableUserFields = await FieldAvailabilityCache(
        database,
      ).knownAvailableUserFields();

      return UserPreferences(
        userId: userRow.odooId,
        name: userRow.name,
        login: userRow.login,
        partnerId: partnerId,
        availableUserFields: availableUserFields,
        availablePartnerFields: FieldAvailabilityCache.basePartnerFields,
        lang: userRow.lang,
        tz: userRow.tz,
        signature: userRow.signature,
        notificationType: availableUserFields.contains('notification_type')
            ? userRow.notificationType
            : null,
        warehouseId: availableUserFields.contains('property_warehouse_id')
            ? userRow.propertyWarehouseId
            : null,
        mobilePhone: availableUserFields.contains('mobile_phone')
            ? userRow.mobilePhone
            : null,
        workEmail: userRow.workEmail,
        workPhone: userRow.workPhone,
        avatar128: userRow.avatar128,
        email: partnerRow?.email,
        phone: partnerRow?.phone,
        street: partnerRow?.street,
        street2: partnerRow?.street2,
        city: partnerRow?.city,
        zip: partnerRow?.zip,
        countryId: partnerRow?.countryId,
        stateId: partnerRow?.stateId,
      );
    });
  }

  @override
  Future<UserPreferencesCatalogs> catalogs({int? countryId}) async {
    final languageRows =
        await (database.select(database.resLang)
              ..where((t) => t.active.equals(true))
              ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
            .get();
    final countryRows = await (database.select(
      database.resCountry,
    )..orderBy([(t) => drift.OrderingTerm.asc(t.name)])).get();
    final warehouseRows =
        await (database.select(database.stockWarehouse)
              ..where((t) => t.active.equals(true))
              ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
            .get();
    final stateRows = countryId == null
        ? const <ResCountryStateData>[]
        : await (database.select(database.resCountryState)
                ..where((t) => t.countryId.equals(countryId))
                ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
              .get();

    final fieldSelections = FieldSelectionDatasource(database);
    final timezoneSelection = await fieldSelections.getFieldSelection(
      'res.users',
      'tz',
    );
    final notificationSelection = await fieldSelections.getFieldSelection(
      'res.users',
      'notification_type',
    );

    return UserPreferencesCatalogs(
      languages: [
        for (final row in languageRows)
          UserPreferencesCodeOption(row.code, row.name),
      ],
      timezones: _codeOptionsFromSelection(timezoneSelection),
      notificationTypes: _codeOptionsFromSelection(notificationSelection),
      countries: [
        for (final row in countryRows)
          UserPreferencesOption(row.odooId, row.name),
      ],
      states: [
        for (final row in stateRows)
          UserPreferencesOption(row.odooId, row.name),
      ],
      warehouses: [
        for (final row in warehouseRows)
          UserPreferencesOption(row.odooId, row.name),
      ],
    );
  }

  @override
  Stream<List<UserGroupInfo>> watchGroups(int userId) {
    final query = database.customSelect(
      'SELECT group_ids FROM res_users WHERE odoo_id = ? LIMIT 1',
      variables: [drift.Variable.withInt(userId)],
      readsFrom: {database.resUsers},
    );
    return query.watchSingleOrNull().asyncMap((row) async {
      final groupIdsCsv = row?.read<String?>('group_ids');
      if (groupIdsCsv == null || groupIdsCsv.isEmpty) {
        return const <UserGroupInfo>[];
      }
      final groupIds = groupIdsCsv
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toSet();
      if (groupIds.isEmpty) return const <UserGroupInfo>[];

      final rows = await (database.select(
        database.resGroups,
      )..where((t) => t.odooId.isIn(groupIds))).get();
      final groups = [
        for (final r in rows)
          UserGroupInfo(
            id: r.odooId,
            name: r.name,
            fullName: r.fullName,
            xmlId: r.xmlId,
          ),
      ]..sort((a, b) => a.name.compareTo(b.name));
      return groups;
    });
  }

  @override
  Future<bool> save(int userId, UserPreferencesChange change) async {
    if (change.isEmpty) return true;
    await database.transaction(() async {
      if (change.userValues.isNotEmpty) {
        await _upsertLocalUser(userId, change.userValues);
        await queue.queueOperation(
          model: 'res.users',
          method: 'write',
          recordId: userId,
          values: Map<String, dynamic>.from(change.userValues),
        );
      }
      if (change.partnerValues.isNotEmpty) {
        final partnerId = change.partnerId;
        if (partnerId == null) {
          throw StateError(
            'partnerValues sin partnerId al guardar preferencias',
          );
        }
        await _upsertLocalPartner(partnerId, change.partnerValues);
        await queue.queueOperation(
          model: 'res.partner',
          method: 'write',
          recordId: partnerId,
          values: Map<String, dynamic>.from(change.partnerValues),
        );
      }
    });
    return true;
  }

  /// Espeja `UserRepository._updateLocalUser` de theos_pos
  /// (`theos_pos/lib/features/users/repositories/user_repository.dart:674-715`),
  /// sin `image_1920`: ese campo escribe la foto en 1920px, `avatar128`
  /// cachea la miniatura de 128px que Odoo COMPUTA — no son el mismo dato, y
  /// redimensionar acá exigiría una dependencia de imágenes que este
  /// runtime no tiene. La miniatura se refresca sola con la próxima
  /// sincronización real, no con un valor optimista inventado.
  Future<void> _upsertLocalUser(int userId, Map<String, dynamic> values) {
    return (database.update(
      database.resUsers,
    )..where((t) => t.odooId.equals(userId))).write(
      ResUsersCompanion(
        lang: values.containsKey('lang')
            ? drift.Value(values['lang'] as String?)
            : const drift.Value.absent(),
        tz: values.containsKey('tz')
            ? drift.Value(values['tz'] as String?)
            : const drift.Value.absent(),
        signature: values.containsKey('signature')
            ? drift.Value(values['signature'] as String?)
            : const drift.Value.absent(),
        notificationType: values.containsKey('notification_type')
            ? drift.Value(values['notification_type'] as String?)
            : const drift.Value.absent(),
        propertyWarehouseId: values.containsKey('property_warehouse_id')
            ? drift.Value(values['property_warehouse_id'] as int?)
            : const drift.Value.absent(),
        mobilePhone: values.containsKey('mobile_phone')
            ? drift.Value(values['mobile_phone'] as String?)
            : const drift.Value.absent(),
      ),
    );
  }

  Future<void> _upsertLocalPartner(int partnerId, Map<String, dynamic> values) {
    return (database.update(
      database.resPartner,
    )..where((t) => t.odooId.equals(partnerId))).write(
      ResPartnerCompanion(
        email: values.containsKey('email')
            ? drift.Value(values['email'] as String?)
            : const drift.Value.absent(),
        phone: values.containsKey('phone')
            ? drift.Value(values['phone'] as String?)
            : const drift.Value.absent(),
        street: values.containsKey('street')
            ? drift.Value(values['street'] as String?)
            : const drift.Value.absent(),
        street2: values.containsKey('street2')
            ? drift.Value(values['street2'] as String?)
            : const drift.Value.absent(),
        city: values.containsKey('city')
            ? drift.Value(values['city'] as String?)
            : const drift.Value.absent(),
        zip: values.containsKey('zip')
            ? drift.Value(values['zip'] as String?)
            : const drift.Value.absent(),
        countryId: values.containsKey('country_id')
            ? drift.Value(values['country_id'] as int?)
            : const drift.Value.absent(),
        stateId: values.containsKey('state_id')
            ? drift.Value(values['state_id'] as int?)
            : const drift.Value.absent(),
      ),
    );
  }

  static List<UserPreferencesCodeOption> _codeOptionsFromSelection(
    List<dynamic>? selection,
  ) {
    if (selection == null) return const [];
    return [
      for (final entry in selection)
        if (entry is List &&
            entry.length == 2 &&
            entry[0] is String &&
            entry[1] is String)
          UserPreferencesCodeOption(entry[0] as String, entry[1] as String),
    ];
  }
}

/// Recuerda, sin red, cuáles de los campos OPCIONALES de `res.users` existen
/// en el servidor conectado — sin tocar el esquema Drift: reutiliza la tabla
/// `field_selections` (`theos_pos_core/lib/src/database/tables/sync_tables.dart:141-146`),
/// pensada para cachear selecciones de Odoo, como marcador de existencia.
///
/// Por qué es seguro reusarla:
/// - `mobile_phone`/`property_warehouse_id` son `Char`/`Many2one`, nunca
///   `Selection` — ninguna otra parte del código cachea nada bajo esas
///   claves, así que no hay colisión con un dato real.
/// - `notification_type` SÍ es `Selection` y ya se cachea con su clave real
///   (`CommonRepository.getNotificationTypes()` en theos_pos) — reusar esa
///   MISMA fila como señal de disponibilidad es correcto: si el campo no
///   existe, ese `fields_get` nunca puebla la fila.
/// - El borrado de catálogos en Orbi lo dispara `sync.deleted.record`, no
///   "faltó en el último fetch" — una fila de disponibilidad nunca se borra
///   por accidente en un ciclo de sync ajeno.
final class FieldAvailabilityCache {
  const FieldAvailabilityCache(this.database);
  final AppDatabase database;

  static const _model = 'res.users';

  /// Prefijo que ningún nombre real de campo de Odoo puede tener (Odoo no
  /// usa `:` en nombres de campo) — evita chocar con una caché de selección
  /// real bajo el mismo nombre de campo.
  static const _markerPrefix = '_field_available:';

  /// `mobile_phone` (`hr`) y `property_warehouse_id` (`sale_stock`) son los
  /// únicos dos que necesitan marcador propio — ver la doc de la clase.
  static const optionalUserFields = ['mobile_phone', 'property_warehouse_id'];

  static const basePartnerFields = {
    'email',
    'phone',
    'street',
    'street2',
    'city',
    'zip',
    'country_id',
    'state_id',
  };

  /// Escrito por quien haga la sonda `fields_get` en línea (sync-cuenta o el
  /// próximo `refresh` de este archivo) tras confirmar que el campo existe.
  Future<void> markAvailable(String field) {
    return FieldSelectionDatasource(
      database,
    ).upsertFieldSelection(_model, '$_markerPrefix$field', const ['1']);
  }

  /// Borra un marcador viejo cuando el campo deja de existir en el servidor
  /// (p. ej. se desinstaló `hr` o `sale_stock`) — sin esto, un marcador de
  /// una sincronización anterior seguiría diciendo "disponible" para
  /// siempre y el formulario intentaría escribir un campo que Odoo ya no
  /// tiene.
  Future<void> markUnavailable(String field) {
    return FieldSelectionDatasource(
      database,
    ).deleteFieldSelection(_model, '$_markerPrefix$field');
  }

  /// `{'lang','tz','signature'}` (módulo `base`, siempre presentes) más los
  /// opcionales confirmados por sonda o por caché real de selección.
  Future<Set<String>> knownAvailableUserFields() async {
    final selections = FieldSelectionDatasource(database);
    final available = <String>{'lang', 'tz', 'signature'};
    for (final field in optionalUserFields) {
      if (await selections.hasFieldSelection(_model, '$_markerPrefix$field')) {
        available.add(field);
      }
    }
    // `notification_type` es Selection: su propia caché de opciones (la que
    // ya escribe `CommonRepository.getNotificationTypes()` en theos_pos) ya
    // sirve de marcador — sin fila, el campo nunca se confirmó.
    if (await selections.hasFieldSelection(_model, 'notification_type')) {
      available.add('notification_type');
    }
    return available;
  }
}

/// `res.device` — igual forma que `ResDevice` en
/// `theos_pos/lib/shared/models/res_device.model.dart`, reproducido acá
/// porque `theos_panel` no puede importar `theos_pos`. Sin caché local,
/// igual que theos_pos: es una lista de sesiones vivas, mostrar una
/// "revocada en otro lado" como activa es su propio riesgo de seguridad, no
/// uno que resolver acá.
final class UserDevice {
  const UserDevice({
    required this.id,
    required this.revoked,
    this.platform,
    this.browser,
    this.ipAddress,
    this.country,
    this.city,
    this.lastActivity,
  });

  final int id;
  final String? platform;
  final String? browser;
  final String? ipAddress;
  final String? country;
  final String? city;
  final DateTime? lastActivity;
  final bool revoked;
}

enum UserSecurityActionOutcome { applied, rejected, offline }

final class UserSecurityActionResult {
  const UserSecurityActionResult.applied()
    : outcome = UserSecurityActionOutcome.applied,
      serverMessage = null;
  const UserSecurityActionResult.rejected(this.serverMessage)
    : outcome = UserSecurityActionOutcome.rejected;
  const UserSecurityActionResult.offline()
    : outcome = UserSecurityActionOutcome.offline,
      serverMessage = null;

  final UserSecurityActionOutcome outcome;

  /// Texto de Odoo tal cual (`UserError`/contraseña incorrecta), nunca una
  /// paráfrasis del cliente. `null` para `applied` y `offline`.
  final String? serverMessage;

  bool get isApplied => outcome == UserSecurityActionOutcome.applied;
}

/// Cambiar contraseña, listar y revocar dispositivos — deliberadamente
/// ONLINE-ONLY, sin cola: una contraseña o una revocación reproducida
/// después de que el usuario ya cambió de idea es un problema de seguridad,
/// no de conveniencia (mismo razonamiento que
/// `CollectionSessionSupervisionPort` para acciones de confianza en
/// persona). Mismos RPC que theos_pos
/// (`theos_pos/lib/features/users/repositories/user_repository.dart`).
abstract interface class UserSecurityActionsPort {
  bool get isOnline;

  /// `res.users.change_password(old_passwd, new_passwd)` — `user_repository.dart:420-434`.
  Future<UserSecurityActionResult> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// `res.device.search_read` con `revoked=false` — `user_repository.dart:322-341`.
  Future<List<UserDevice>> listDevices();

  /// `res.device.mobile_revoke_device(password)` — `user_repository.dart:349-362`.
  Future<UserSecurityActionResult> revokeDevice(int deviceId, String password);

  /// `res.users.mobile_revoke_all_devices(password)` — `user_repository.dart:399-411`.
  Future<UserSecurityActionResult> revokeAllDevices(String password);
}

final class OdooUserSecurityActionsPort implements UserSecurityActionsPort {
  const OdooUserSecurityActionsPort({
    required this.actions,
    required this.isOnline,
  });

  final SaleOdooActions actions;

  @override
  final bool isOnline;

  static const _deviceFields = [
    'id',
    'platform',
    'browser',
    'ip_address',
    'country',
    'city',
    'last_activity',
    'revoked',
  ];

  @override
  Future<UserSecurityActionResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isOnline) return const UserSecurityActionResult.offline();
    try {
      final result = await actions.call(
        model: 'res.users',
        method: 'change_password',
        kwargs: {'old_passwd': oldPassword, 'new_passwd': newPassword},
      );
      return result == true
          ? const UserSecurityActionResult.applied()
          : const UserSecurityActionResult.rejected(null);
    } on OdooException catch (error) {
      return UserSecurityActionResult.rejected(error.message);
    }
  }

  @override
  Future<List<UserDevice>> listDevices() async {
    if (!isOnline) return const [];
    final result = await actions.call(
      model: 'res.device',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['revoked', '=', false],
        ],
        'fields': _deviceFields,
      },
    );
    if (result is! List) return const [];
    return [
      for (final row in result)
        if (row is Map) _deviceFromOdoo(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Future<UserSecurityActionResult> revokeDevice(
    int deviceId,
    String password,
  ) async {
    if (!isOnline) return const UserSecurityActionResult.offline();
    try {
      await actions.call(
        model: 'res.device',
        method: 'mobile_revoke_device',
        ids: [deviceId],
        kwargs: {'password': password},
      );
      return const UserSecurityActionResult.applied();
    } on OdooException catch (error) {
      return UserSecurityActionResult.rejected(error.message);
    }
  }

  @override
  Future<UserSecurityActionResult> revokeAllDevices(String password) async {
    if (!isOnline) return const UserSecurityActionResult.offline();
    try {
      await actions.call(
        model: 'res.users',
        method: 'mobile_revoke_all_devices',
        kwargs: {'password': password},
      );
      return const UserSecurityActionResult.applied();
    } on OdooException catch (error) {
      return UserSecurityActionResult.rejected(error.message);
    }
  }

  static UserDevice _deviceFromOdoo(Map<String, dynamic> data) {
    final lastActivity = data['last_activity'];
    return UserDevice(
      id: data['id'] as int,
      platform: parseOdooString(data['platform']),
      browser: parseOdooString(data['browser']),
      ipAddress: parseOdooString(data['ip_address']),
      country: parseOdooString(data['country']),
      city: parseOdooString(data['city']),
      lastActivity: lastActivity is String
          ? DateTime.tryParse('${lastActivity}Z')
          : null,
      revoked: data['revoked'] == true,
    );
  }
}
