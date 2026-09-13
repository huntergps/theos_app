import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/account/user_preferences_dialog.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockUserPreferencesPort extends Mock implements UserPreferencesPort {}

class _MockUserSecurityActionsPort extends Mock
    implements UserSecurityActionsPort {}

/// Doble de [AvatarImagePicker]: `FilePicker.pickFiles` es estático,
/// imposible de mockear directo con mocktail — ver la doc de la clase real.
class _FakeAvatarImagePicker implements AvatarImagePicker {
  const _FakeAvatarImagePicker(this.bytes);
  final Uint8List? bytes;
  @override
  Future<Uint8List?> pickImage() async => bytes;
}

/// Un PNG mínimo mas real — `img.decodeImage` lo tiene que poder leer de
/// verdad, si no `_optimizeAvatarImage` devuelve `null` y la prueba no
/// probaría nada.
Uint8List _tinyValidImage() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

const _availableUserFields = {
  'id',
  'name',
  'login',
  'partner_id',
  'lang',
  'tz',
  'signature',
  'property_warehouse_id',
  'mobile_phone',
  'notification_type',
};

const _availablePartnerFields = {
  'email',
  'phone',
  'street',
  'street2',
  'city',
  'zip',
  'country_id',
  'state_id',
};

const _basePrefs = UserPreferences(
  userId: 7,
  name: 'Erik Salazar',
  login: 'erik',
  partnerId: 42,
  lang: 'es_EC',
  tz: 'America/Guayaquil',
  notificationType: 'email',
  street: 'Av. Siempre Viva',
  countryId: 63,
  workEmail: 'erik@tecnosmart.com.ec',
  workPhone: '023800000',
  availableUserFields: _availableUserFields,
  availablePartnerFields: _availablePartnerFields,
);

/// Lo que carga un usuario en un servidor SIN `hr` ni `sale_stock` — Mepriga,
/// hoy: sólo base, web, bus, mail, stock, envases y l10n_ec_app_sync.
const _meprigaPrefs = UserPreferences(
  userId: 7,
  name: 'Erik Salazar',
  login: 'erik',
  partnerId: 42,
  lang: 'es_EC',
  tz: 'America/Guayaquil',
  availableUserFields: {'id', 'name', 'login', 'partner_id', 'lang', 'tz', 'signature'},
  availablePartnerFields: _availablePartnerFields,
);

const _baseCatalogs = UserPreferencesCatalogs(
  languages: [
    UserPreferencesCodeOption('es_EC', 'Español (EC)'),
    UserPreferencesCodeOption('en_US', 'English'),
  ],
  timezones: [
    UserPreferencesCodeOption('America/Guayaquil', 'America/Guayaquil'),
    UserPreferencesCodeOption('Europe/Madrid', 'Europe/Madrid'),
  ],
  notificationTypes: [
    UserPreferencesCodeOption('email', 'Correo electrónico'),
    UserPreferencesCodeOption('inbox', 'Bandeja de entrada'),
  ],
  countries: [UserPreferencesOption(63, 'Ecuador')],
  states: [UserPreferencesOption(536, 'Pichincha')],
  warehouses: [UserPreferencesOption(3, 'Almacén Principal')],
);

const _meprigaEditsWithMobileAndWarehouseChanged = UserPreferencesEdits(
  lang: 'es_EC',
  tz: 'America/Guayaquil',
  notificationType: 'email',
  signature: '',
  warehouseId: 3,
  mobilePhone: '0999999999',
  removeAvatar: false,
  newAvatarBase64: null,
  email: '',
  phone: '',
  street: '',
  street2: '',
  city: '',
  zip: '',
  countryId: null,
  stateId: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const UserPreferencesChange());
  });

  late _MockUserPreferencesPort preferences;
  late _MockUserSecurityActionsPort security;

  setUp(() {
    preferences = _MockUserPreferencesPort();
    security = _MockUserSecurityActionsPort();
    when(() => preferences.watch(any())).thenAnswer(
      (_) => Stream.value(_basePrefs),
    );
    when(
      () => preferences.catalogs(countryId: any(named: 'countryId')),
    ).thenAnswer((_) async => _baseCatalogs);
    when(() => preferences.watchGroups(any())).thenAnswer(
      (_) => Stream.value(const [
        UserGroupInfo(id: 1, name: 'Ventas', fullName: 'Punto de venta'),
      ]),
    );
    when(() => security.isOnline).thenReturn(true);
    when(() => security.listDevices()).thenAnswer((_) async => const []);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      FluentApp(
        theme: OrbiFluentTheme.light,
        home: ScaffoldPage(
          content: Builder(
            builder: (context) => HyperlinkButton(
              onPressed: () => showUserPreferencesDialog(
                context,
                userId: 7,
                preferences: preferences,
                security: security,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('buildUserPreferencesChange — un campo no disponible nunca entra al diff', () {
    test(
      'mobile_phone y property_warehouse_id ausentes de Mepriga no se envían',
      () {
        final change = buildUserPreferencesChange(
          initial: _meprigaPrefs,
          edited: _meprigaEditsWithMobileAndWarehouseChanged,
        );

        expect(change.userValues.containsKey('mobile_phone'), isFalse);
        expect(
          change.userValues.containsKey('property_warehouse_id'),
          isFalse,
        );
      },
    );
  });

  testWidgets(
    '(a) sin red, con datos locales sembrados, el diálogo muestra idioma, '
    'zona horaria y dirección',
    (tester) async {
      when(() => security.isOnline).thenReturn(false);

      await open(tester);

      expect(find.text('Español (EC)'), findsOneWidget);
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.text('America/Guayaquil'), findsWidgets);
      await tester.tap(find.text('Privado'));
      await tester.pumpAndSettle();
      final street = tester.widget<TextBox>(
        find.byWidgetPredicate((w) => w is TextBox && w.controller?.text == 'Av. Siempre Viva'),
      );
      expect(street.controller!.text, 'Av. Siempre Viva');
    },
  );

  testWidgets(
    '(b) cambiar la zona horaria y guardar llama a save sólo con {tz}',
    (tester) async {
      when(() => preferences.save(any(), any())).thenAnswer((_) async => true);

      await open(tester);

      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('user_preferences_tz')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Europe/Madrid').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('user_preferences_save')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => preferences.save(7, captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final change = captured.single as UserPreferencesChange;
      expect(change.userValues, {'tz': 'Europe/Madrid'});
      expect(change.partnerValues, isEmpty);
    },
  );

  testWidgets(
    '(c) aparecen Grupos y Seguridad, y Grupos lista los nombres',
    (tester) async {
      await open(tester);

      expect(find.text('Grupos'), findsOneWidget);
      expect(find.text('Seguridad'), findsOneWidget);

      await tester.tap(find.text('Grupos'));
      await tester.pumpAndSettle();

      expect(find.text('Punto de venta'), findsOneWidget);
    },
  );

  testWidgets(
    '(d) sin red, Cambiar contraseña dice que necesita conexión y no llama al puerto',
    (tester) async {
      when(() => security.isOnline).thenReturn(false);

      await open(tester);

      await tester.tap(find.text('Seguridad'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('user_preferences_change_password')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Cambiar la contraseña necesita conexión con el servidor.'),
        findsOneWidget,
      );
      verifyNever(
        () => security.changePassword(
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    },
  );

  testWidgets('(e) sin cambios, Guardar está desactivado', (tester) async {
    await open(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('user_preferences_save')),
    );
    expect(button.onPressed, isNull);
    verifyNever(() => preferences.save(any(), any()));
  });

  testWidgets('cambiar la firma sí activa Guardar', (tester) async {
    await open(tester);

    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextBox && w.maxLines == 4),
      'Nueva firma',
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('user_preferences_save')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    '(f) la cabecera muestra el correo de trabajo sembrado, sin campo editable',
    (tester) async {
      await open(tester);

      final workEmailText = tester.widget<Text>(
        find.byKey(const ValueKey('user_preferences_work_email')),
      );
      expect(workEmailText.data, 'erik@tecnosmart.com.ec');
      // No es un TextBox: no hay forma de editarlo desde el diálogo.
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('user_preferences_work_email')),
          matching: find.byType(TextBox),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    '(g) elegir una imagen y guardar llama a save con image_1920 no vacío',
    (tester) async {
      when(() => preferences.save(any(), any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        FluentApp(
          theme: OrbiFluentTheme.light,
          home: ScaffoldPage(
            content: Builder(
              builder: (context) => HyperlinkButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) => UserPreferencesDialog(
                    userId: 7,
                    preferences: preferences,
                    security: security,
                    imagePicker: _FakeAvatarImagePicker(_tinyValidImage()),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('user_preferences_pick_avatar')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('user_preferences_save')));
      await tester.pumpAndSettle();

      final captured = verify(
        () => preferences.save(7, captureAny()),
      ).captured;
      final change = captured.single as UserPreferencesChange;
      expect(change.userValues['image_1920'], isNotNull);
      expect((change.userValues['image_1920'] as String).isNotEmpty, isTrue);
    },
  );
}
