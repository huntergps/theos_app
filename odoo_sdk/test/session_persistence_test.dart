@Tags(['unit'])
library;

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockOdooHttpClient extends Mock implements OdooHttpClient {}

class MockOdooCrudApi extends Mock implements OdooCrudApi {}

class MockSessionPersistence extends Mock implements SessionPersistence {}

// ---------------------------------------------------------------------------
// In-memory SessionPersistence for integration-style tests
// ---------------------------------------------------------------------------

class InMemorySessionPersistence implements SessionPersistence {
  OdooSessionResult? _stored;

  @override
  Future<void> saveSession(OdooSessionResult session) async {
    _stored = session;
  }

  @override
  Future<OdooSessionResult?> loadSession() async => _stored;

  @override
  Future<void> clearSession() async {
    _stored = null;
  }

  /// Expose stored value for assertions.
  OdooSessionResult? get stored => _stored;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

OdooClientConfig _testConfig() => const OdooClientConfig(
  baseUrl: 'https://odoo.example.com',
  apiKey: 'test-api-key',
  database: 'test-db',
  allowInsecure: true,
);

OdooSessionResult _testSession({
  String sessionId = 'sess-abc-123',
  int uid = 42,
  int partnerId = 7,
}) => OdooSessionResult(sessionId: sessionId, uid: uid, partnerId: partnerId);

Response<dynamic> _jsonRpcResponse(Map<String, dynamic> result) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: 200,
      data: {'jsonrpc': '2.0', 'result': result},
    );

Response<dynamic> _sessionInfoResponse({required int uid}) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
  data: {
    'result': {'uid': uid, 'partner_id': 7},
  },
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockOdooHttpClient mockHttp;
  late MockOdooCrudApi mockCrud;
  late OdooClientConfig config;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://odoo.example.com'));
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    mockHttp = MockOdooHttpClient();
    mockCrud = MockOdooCrudApi();
    config = _testConfig();

    when(() => mockHttp.config).thenReturn(config);
  });

  // -------------------------------------------------------------------------
  // SessionPersistence interface (InMemory impl)
  // -------------------------------------------------------------------------
  group('InMemorySessionPersistence', () {
    late InMemorySessionPersistence persistence;

    setUp(() => persistence = InMemorySessionPersistence());

    test('starts empty', () async {
      expect(await persistence.loadSession(), isNull);
    });

    test('saves and loads session', () async {
      final session = _testSession();
      await persistence.saveSession(session);

      final loaded = await persistence.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.sessionId, equals('sess-abc-123'));
      expect(loaded.uid, equals(42));
    });

    test('clearSession removes stored session', () async {
      await persistence.saveSession(_testSession());
      await persistence.clearSession();
      expect(await persistence.loadSession(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // logout()
  // -------------------------------------------------------------------------
  group('logout', () {
    test('calls /web/session/destroy and clears local session', () async {
      final mockPersistence = MockSessionPersistence();
      when(() => mockPersistence.clearSession()).thenAnswer((_) async {});

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      // Set a current session manually via the public clearSession/restore path
      // We use authenticateSession to set _currentSession, but that's complex.
      // Instead, we restore from persistence:
      when(
        () => mockPersistence.loadSession(),
      ).thenAnswer((_) async => _testSession());
      await manager.restoreSession();
      expect(manager.hasSession, isTrue);

      // Mock the /web/session/destroy call
      when(
        () => mockHttp.post(
          any(),
          data: any(named: 'data'),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _jsonRpcResponse({}));

      await manager.logout();

      expect(manager.hasSession, isFalse);
      expect(manager.currentSession, isNull);
      verify(() => mockPersistence.clearSession()).called(1);
      verify(
        () => mockHttp.post(
          any(that: contains('/web/session/destroy')),
          data: any(named: 'data'),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);
    });

    test('does not throw when server call fails', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.post(
          any(),
          data: any(named: 'data'),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );

      // Should complete without throwing
      await manager.logout();
      expect(manager.hasSession, isFalse);
    });

    test('clears session info cache on logout', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      // Prime the session info cache
      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _sessionInfoResponse(uid: 42));

      final info = await manager.getSessionInfo();
      expect(info, isNotNull);

      // Mock the /web/session/destroy call
      when(
        () => mockHttp.post(
          any(),
          data: any(named: 'data'),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _jsonRpcResponse({}));

      await manager.logout();

      // After logout, getSessionInfo should make a fresh request (not cached)
      // Reset mock to return different data
      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _sessionInfoResponse(uid: 99));

      final infoAfter = await manager.getSessionInfo();
      expect(infoAfter?['uid'], equals(99));
    });
  });

  // -------------------------------------------------------------------------
  // isSessionValid()
  // -------------------------------------------------------------------------
  group('isSessionValid', () {
    test('returns true when uid > 0', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _sessionInfoResponse(uid: 42));

      expect(await manager.isSessionValid(), isTrue);
    });

    test('returns false when uid is 0', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _sessionInfoResponse(uid: 0));

      expect(await manager.isSessionValid(), isFalse);
    });

    test('returns false on 401 response', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 401,
          ),
        ),
      );

      expect(await manager.isSessionValid(), isFalse);
    });

    test('returns false on 403 response', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 403,
          ),
        ),
      );

      expect(await manager.isSessionValid(), isFalse);
    });

    test('returns false on network error', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(await manager.isSessionValid(), isFalse);
    });

    test('returns false when config has no apiKey', () async {
      const emptyConfig = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: '',
        database: 'test-db',
        allowInsecure: true,
      );
      when(() => mockHttp.config).thenReturn(emptyConfig);

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      expect(await manager.isSessionValid(), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // restoreSession()
  // -------------------------------------------------------------------------
  group('restoreSession', () {
    test('loads session from persistence and sets as current', () async {
      final mockPersistence = MockSessionPersistence();
      final session = _testSession();

      when(
        () => mockPersistence.loadSession(),
      ).thenAnswer((_) async => session);

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      final restored = await manager.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.uid, equals(42));
      expect(manager.hasSession, isTrue);
      expect(manager.currentSession?.sessionId, equals('sess-abc-123'));
    });

    test('returns null when persistence has no session', () async {
      final mockPersistence = MockSessionPersistence();
      when(() => mockPersistence.loadSession()).thenAnswer((_) async => null);

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      final restored = await manager.restoreSession();

      expect(restored, isNull);
      expect(manager.hasSession, isFalse);
    });

    test('returns null when no persistence is configured', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      final restored = await manager.restoreSession();
      expect(restored, isNull);
      expect(manager.hasSession, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // authenticateSession + persistence
  // -------------------------------------------------------------------------
  group('authenticateSession with persistence', () {
    test('saves session to persistence on success', () async {
      final persistence = InMemorySessionPersistence();

      // Both auth strategies require specific setup. We need the httpClient
      // to return a valid JSON-RPC authenticate response for the
      // JsonRpcAuthStrategy. MobileAuthStrategy needs crudApi.
      // The easiest path: make mobile strategy unavailable (it checks
      // crudApi capabilities), and have JsonRpc succeed.

      // JsonRpcAuthStrategy calls httpClient.post for /web/session/authenticate
      when(
        () => mockHttp.post(
          any(),
          data: any(named: 'data'),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 200,
          data: {
            'result': {
              'session_id': 'new-sess-789',
              'uid': 10,
              'partner_id': 5,
            },
          },
        ),
      );

      // MobileAuthStrategy calls crudApi.call — make it fail so it falls through
      when(
        () => mockCrud.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
          args: any(named: 'args'),
          kwargs: any(named: 'kwargs'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(Exception('not available'));

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: persistence,
      );

      final result = await manager.authenticateSession(
        login: 'admin',
        password: 'admin',
      );

      expect(result, isNotNull);
      expect(result!.uid, equals(10));
      expect(persistence.stored, isNotNull);
      expect(persistence.stored!.uid, equals(10));
    });
  });

  // -------------------------------------------------------------------------
  // initializeFromStorage()
  // -------------------------------------------------------------------------
  group('initializeFromStorage', () {
    test('restores and validates a valid session', () async {
      final mockPersistence = MockSessionPersistence();
      final session = _testSession();

      when(
        () => mockPersistence.loadSession(),
      ).thenAnswer((_) async => session);

      // getSessionInfo returns valid uid
      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _sessionInfoResponse(uid: 42));

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      final result = await manager.initializeFromStorage();

      expect(result, isNotNull);
      expect(result!.uid, equals(42));
      expect(manager.hasSession, isTrue);
      verifyNever(() => mockPersistence.clearSession());
    });

    test('clears session when validation fails', () async {
      final mockPersistence = MockSessionPersistence();
      final session = _testSession();

      when(
        () => mockPersistence.loadSession(),
      ).thenAnswer((_) async => session);
      when(() => mockPersistence.clearSession()).thenAnswer((_) async {});

      // getSessionInfo returns uid=0 (expired)
      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _sessionInfoResponse(uid: 0));

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      final result = await manager.initializeFromStorage();

      expect(result, isNull);
      expect(manager.hasSession, isFalse);
      verify(() => mockPersistence.clearSession()).called(1);
    });

    test('returns null when no session is persisted', () async {
      final mockPersistence = MockSessionPersistence();
      when(() => mockPersistence.loadSession()).thenAnswer((_) async => null);

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      final result = await manager.initializeFromStorage();
      expect(result, isNull);
      expect(manager.hasSession, isFalse);
    });

    test('clears session on server error during validation', () async {
      final mockPersistence = MockSessionPersistence();
      final session = _testSession();

      when(
        () => mockPersistence.loadSession(),
      ).thenAnswer((_) async => session);
      when(() => mockPersistence.clearSession()).thenAnswer((_) async {});

      // getSessionInfo throws (server unreachable) — caught inside getSessionInfo, returns null
      when(
        () => mockHttp.get(
          any(),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        ),
      );

      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
        persistence: mockPersistence,
      );

      final result = await manager.initializeFromStorage();

      expect(result, isNull);
      expect(manager.hasSession, isFalse);
      verify(() => mockPersistence.clearSession()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // No persistence configured (graceful no-ops)
  // -------------------------------------------------------------------------
  group('without persistence', () {
    test('logout works without persistence', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      when(
        () => mockHttp.post(
          any(),
          data: any(named: 'data'),
          headers: any(named: 'headers'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => _jsonRpcResponse({}));

      await manager.logout();
      expect(manager.hasSession, isFalse);
    });

    test('initializeFromStorage returns null without persistence', () async {
      final manager = OdooSessionManager(
        httpClient: mockHttp,
        crudApi: mockCrud,
      );

      final result = await manager.initializeFromStorage();
      expect(result, isNull);
    });
  });
}
