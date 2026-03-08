import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/users/user.model.dart';

void main() {
  group('User - fromOdoo', () {
    test('parses typical user data', () {
      final json = {
        'id': 2,
        'name': 'John Doe',
        'login': 'john@example.com',
        'email': 'john@example.com',
        'lang': 'es_EC',
        'tz': 'America/Guayaquil',
        'signature': '<p>John</p>',
        'partner_id': [10, 'John Doe Partner'],
        'company_id': [1, 'Tech Solutions'],
        'property_warehouse_id': [5, 'Bodega Principal'],
        'avatar_128': 'base64avatardata',
        'notification_type': 'email',
        'work_email': 'john.work@example.com',
        'work_phone': '042000000',
        'mobile_phone': '0991234567',
        'group_ids': [1, 5, 10, 42],
        'write_date': '2024-06-15 10:30:00',
        'out_of_office_from': '2024-07-01',
        'out_of_office_to': '2024-07-15',
        'out_of_office_message': 'On vacation',
        'calendar_default_privacy': 'public',
        'work_location_id': [3, 'Office GYE'],
        'resource_calendar_id': [1, 'Standard 40h'],
        'pin': '1234',
        'private_street': 'Calle Privada 123',
        'private_city': 'Guayaquil',
        'private_state_id': [5, 'Guayas'],
        'private_country_id': [63, 'Ecuador'],
        'private_email': 'john.private@gmail.com',
        'private_phone': '0991234567',
        'emergency_contact': 'Jane Doe',
        'emergency_phone': '0992345678',
      };

      final user = userManager.fromOdoo(json);

      expect(user.id, equals(2));
      expect(user.name, equals('John Doe'));
      expect(user.login, equals('john@example.com'));
      expect(user.email, equals('john@example.com'));
      expect(user.lang, equals('es_EC'));
      expect(user.tz, equals('America/Guayaquil'));
      expect(user.partnerId, equals(10));
      expect(user.partnerName, equals('John Doe Partner'));
      expect(user.companyId, equals(1));
      expect(user.companyName, equals('Tech Solutions'));
      expect(user.warehouseId, equals(5));
      expect(user.warehouseName, equals('Bodega Principal'));
      expect(user.avatar128, equals('base64avatardata'));
      expect(user.groupIds, isEmpty);
      expect(user.workEmail, equals('john.work@example.com'));
      expect(user.workPhone, equals('042000000'));
      expect(user.mobilePhone, equals('0991234567'));
      expect(user.writeDate, isNotNull);
      expect(user.outOfOfficeMessage, equals('On vacation'));
      expect(user.workLocationId, equals(3));
      expect(user.workLocationName, equals('Office GYE'));
      expect(user.resourceCalendarId, equals(1));
      expect(user.pin, equals('1234'));
      expect(user.privateStreet, equals('Calle Privada 123'));
      expect(user.privateCity, equals('Guayaquil'));
      expect(user.privateStateId, equals(5));
      expect(user.privateCountryId, equals(63));
      expect(user.emergencyContact, equals('Jane Doe'));
      expect(user.emergencyPhone, equals('0992345678'));
    });

    test('handles false/null values', () {
      final json = {
        'id': 1,
        'name': 'Minimal User',
        'login': 'min@test.com',
        'email': false,
        'lang': false,
        'tz': false,
        'signature': false,
        'partner_id': false,
        'company_id': false,
        'property_warehouse_id': false,
        'avatar_128': false,
        'notification_type': false,
        'work_email': false,
        'work_phone': false,
        'mobile_phone': false,
        'group_ids': false,
        'write_date': false,
      };

      final user = userManager.fromOdoo(json);

      expect(user.name, equals('Minimal User'));
      expect(user.email, isNull);
      expect(user.lang, isNull);
      expect(user.tz, isNull);
      expect(user.partnerId, isNull);
      expect(user.companyId, isNull);
      expect(user.warehouseId, isNull);
      expect(user.avatar128, isNull);
      expect(user.groupIds, isEmpty);
      expect(user.writeDate, isNull);
    });

    test('parses Many2One correctly', () {
      final json = {
        'id': 1,
        'name': 'Test',
        'login': 'test',
        'partner_id': [42, 'Partner Name'],
        'company_id': [1, 'Company A'],
        'property_warehouse_id': [3, 'WH Main'],
      };

      final user = userManager.fromOdoo(json);

      expect(user.partnerId, equals(42));
      expect(user.partnerName, equals('Partner Name'));
      expect(user.companyId, equals(1));
      expect(user.companyName, equals('Company A'));
      expect(user.warehouseId, equals(3));
      expect(user.warehouseName, equals('WH Main'));
    });
  });

  group('User - Computed Fields', () {
    test('displayName uses name when not empty', () {
      const user = User(id: 1, name: 'John', login: 'john@test.com');
      expect(user.displayName, equals('John'));
    });

    test('displayName falls back to login', () {
      const user = User(id: 1, name: '', login: 'john@test.com');
      expect(user.displayName, equals('john@test.com'));
    });

    test('hasAvatar checks avatar128', () {
      expect(
        const User(id: 1, name: 'T', login: 'l', avatar128: 'data').hasAvatar,
        isTrue,
      );
      expect(
        const User(id: 1, name: 'T', login: 'l', avatar128: '').hasAvatar,
        isFalse,
      );
      expect(
        const User(id: 1, name: 'T', login: 'l').hasAvatar,
        isFalse,
      );
    });

    test('initials from two-word name', () {
      const user = User(id: 1, name: 'John Doe', login: 'l');
      expect(user.initials, equals('JD'));
    });

    test('initials from single name', () {
      const user = User(id: 1, name: 'Admin', login: 'l');
      expect(user.initials, equals('A'));
    });

    test('initials fallback for empty name', () {
      const user = User(id: 1, name: '', login: 'l');
      expect(user.initials, equals('?'));
    });

    test('timezoneDisplay defaults to UTC', () {
      expect(
        const User(id: 1, name: 'T', login: 'l').timezoneDisplay,
        equals('UTC'),
      );
      expect(
        const User(id: 1, name: 'T', login: 'l', tz: 'America/Guayaquil').timezoneDisplay,
        equals('America/Guayaquil'),
      );
    });

    test('hasPermission checks permissions list', () {
      const user = User(
        id: 1,
        name: 'T',
        login: 'l',
        permissions: ['sales.group_sale_manager', 'base.group_system'],
      );
      expect(user.hasPermission('sales.group_sale_manager'), isTrue);
      expect(user.hasPermission('base.group_system'), isTrue);
      expect(user.hasPermission('nonexistent'), isFalse);
    });

    test('hasGroupId checks groupIds list', () {
      const user = User(
        id: 1,
        name: 'T',
        login: 'l',
        groupIds: [1, 5, 10],
      );
      expect(user.hasGroupId(5), isTrue);
      expect(user.hasGroupId(99), isFalse);
    });

    test('isManager checks manager permissions', () {
      const manager = User(
        id: 1,
        name: 'T',
        login: 'l',
        permissions: ['sales.group_sale_manager'],
      );
      expect(manager.isManager, isTrue);

      const admin = User(
        id: 1,
        name: 'T',
        login: 'l',
        permissions: ['base.group_system'],
      );
      expect(admin.isManager, isTrue);
      expect(admin.isAdmin, isTrue);

      const regular = User(id: 1, name: 'T', login: 'l');
      expect(regular.isManager, isFalse);
    });

    test('canMakeSales requires warehouse and salesperson role', () {
      const canSell = User(
        id: 1,
        name: 'T',
        login: 'l',
        warehouseId: 1,
        permissions: ['sales.group_sale_salesman'],
      );
      expect(canSell.canMakeSales, isTrue);

      const noWarehouse = User(
        id: 1,
        name: 'T',
        login: 'l',
        permissions: ['sales.group_sale_salesman'],
      );
      expect(noWarehouse.canMakeSales, isFalse);

      const noRole = User(
        id: 1,
        name: 'T',
        login: 'l',
        warehouseId: 1,
      );
      expect(noRole.canMakeSales, isFalse);
    });

    test('effectiveEmail prefers email over workEmail', () {
      expect(
        const User(id: 1, name: 'T', login: 'l', email: 'a@b.c', workEmail: 'w@b.c')
            .effectiveEmail,
        equals('a@b.c'),
      );
      expect(
        const User(id: 1, name: 'T', login: 'l', workEmail: 'w@b.c').effectiveEmail,
        equals('w@b.c'),
      );
      expect(
        const User(id: 1, name: 'T', login: 'l').effectiveEmail,
        equals(''),
      );
    });

    test('effectivePhone prefers workPhone over mobilePhone', () {
      expect(
        const User(id: 1, name: 'T', login: 'l', workPhone: '042', mobilePhone: '099')
            .effectivePhone,
        equals('042'),
      );
      expect(
        const User(id: 1, name: 'T', login: 'l', mobilePhone: '099').effectivePhone,
        equals('099'),
      );
    });
  });
}
