import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/src/services/polling_connectivity_monitor.dart';
import 'package:odoo_sdk/src/services/server_connectivity_service.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockNetworkMonitor extends Mock implements NetworkConnectivityMonitor {}

// ---------------------------------------------------------------------------
// PollingConnectivityMonitor tests
// ---------------------------------------------------------------------------

/// A simpler approach: test PollingConnectivityMonitor by using a local
/// HTTP server.
void main() {
  group('PollingConnectivityMonitor', () {
    late HttpServer server;
    late PollingConnectivityMonitor monitor;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response
          ..statusCode = HttpStatus.noContent
          ..close();
      });

      monitor = PollingConnectivityMonitor(
        checkUrl: 'http://127.0.0.1:${server.port}/',
        checkInterval: const Duration(milliseconds: 100),
        timeout: const Duration(seconds: 2),
      );
    });

    tearDown(() async {
      monitor.dispose();
      await server.close(force: true);
    });

    test('checkConnectivity returns true when server responds', () async {
      final result = await monitor.checkConnectivity();
      expect(result, isTrue);
    });

    test('checkConnectivity returns false when server is gone', () async {
      final port = server.port;
      await server.close(force: true);

      // Point to a port that is no longer listening
      final deadMonitor = PollingConnectivityMonitor(
        checkUrl: 'http://127.0.0.1:$port/',
        timeout: const Duration(milliseconds: 500),
      );
      addTearDown(deadMonitor.dispose);

      final result = await deadMonitor.checkConnectivity();
      expect(result, isFalse);
    });

    test('checkConnectivity returns false on timeout', () async {
      // Create a server that never responds
      final slowServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      // Don't listen — connection will hang
      addTearDown(() => slowServer.close(force: true));

      final timeoutMonitor = PollingConnectivityMonitor(
        checkUrl: 'http://127.0.0.1:${slowServer.port}/',
        timeout: const Duration(milliseconds: 200),
      );
      addTearDown(timeoutMonitor.dispose);

      final result = await timeoutMonitor.checkConnectivity();
      expect(result, isFalse);
    });

    test('connectivityStream emits on state change', () async {
      // First call establishes "connected" baseline (default _lastKnownState is true,
      // so going true won't emit). We need to go false first, then true.
      await server.close(force: true);

      final deadMonitor = PollingConnectivityMonitor(
        checkUrl: 'http://127.0.0.1:1/', // unreachable
        timeout: const Duration(milliseconds: 200),
      );
      addTearDown(deadMonitor.dispose);

      final states = <bool>[];
      deadMonitor.connectivityStream.listen(states.add);

      // Should go from true (default) -> false
      await deadMonitor.checkConnectivity();
      // Give stream time to deliver
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, contains(false));
    });

    test('connectivityStream does not emit when state unchanged', () async {
      final states = <bool>[];
      monitor.connectivityStream.listen(states.add);

      // Two consecutive successful checks — default state is true,
      // so no change event should fire.
      await monitor.checkConnectivity();
      await monitor.checkConnectivity();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states, isEmpty);
    });

    test('start and stop control periodic checking', () async {
      var callCount = 0;
      // Replace server handler to count calls
      await server.close(force: true);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        callCount++;
        request.response
          ..statusCode = HttpStatus.noContent
          ..close();
      });

      final periodicMonitor = PollingConnectivityMonitor(
        checkUrl: 'http://127.0.0.1:${server.port}/',
        checkInterval: const Duration(milliseconds: 50),
        timeout: const Duration(seconds: 2),
      );
      addTearDown(periodicMonitor.dispose);

      periodicMonitor.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      periodicMonitor.stop();
      final countAfterStop = callCount;

      // Should have made several calls
      expect(countAfterStop, greaterThan(0));

      // Wait a bit more and verify no new calls
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(callCount, countAfterStop);
    });
  });

  // -------------------------------------------------------------------------
  // ConnectivityStatus tests
  // -------------------------------------------------------------------------

  group('ConnectivityStatus', () {
    test('canAttemptRemote is false when isManualOffline', () {
      const status = ConnectivityStatus(
        hasNetwork: true,
        serverState: ServerConnectionState.online,
        isManualOffline: true,
      );
      expect(status.canAttemptRemote, isFalse);
    });

    test('canAttemptRemote is true when online and not manual offline', () {
      const status = ConnectivityStatus(
        hasNetwork: true,
        serverState: ServerConnectionState.online,
      );
      expect(status.canAttemptRemote, isTrue);
    });

    test('shouldSkipRemote is true when isManualOffline', () {
      const status = ConnectivityStatus(
        hasNetwork: true,
        serverState: ServerConnectionState.online,
        isManualOffline: true,
      );
      expect(status.shouldSkipRemote, isTrue);
    });

    test('isManualOffline defaults to false', () {
      const status = ConnectivityStatus();
      expect(status.isManualOffline, isFalse);
    });

    test('copyWith propagates isManualOffline', () {
      const original = ConnectivityStatus(isManualOffline: false);
      final copied = original.copyWith(isManualOffline: true);
      expect(copied.isManualOffline, isTrue);
      expect(original.isManualOffline, isFalse);
    });

    test('copyWith preserves isManualOffline when not specified', () {
      const original = ConnectivityStatus(isManualOffline: true);
      final copied = original.copyWith(hasNetwork: false);
      expect(copied.isManualOffline, isTrue);
    });

    test('equality includes isManualOffline', () {
      const a = ConnectivityStatus(isManualOffline: false);
      const b = ConnectivityStatus(isManualOffline: true);
      expect(a, isNot(equals(b)));
    });

    test('hashCode differs with isManualOffline', () {
      const a = ConnectivityStatus(isManualOffline: false);
      const b = ConnectivityStatus(isManualOffline: true);
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('toString includes manualOffline', () {
      const status = ConnectivityStatus(isManualOffline: true);
      expect(status.toString(), contains('manualOffline: true'));
    });
  });

  // -------------------------------------------------------------------------
  // ServerHealthService manual offline mode tests
  // -------------------------------------------------------------------------

  group('ServerHealthService manual offline mode', () {
    late ServerHealthService service;
    var healthCheckCalled = false;

    setUp(() {
      healthCheckCalled = false;
      service = ServerHealthService(
        config: const ServerHealthConfig(
          normalCheckInterval: Duration(seconds: 60),
          recoveryCheckInterval: Duration(seconds: 10),
        ),
        healthCheck: () async {
          healthCheckCalled = true;
        },
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('isManualOffline starts as false', () {
      expect(service.isManualOffline, isFalse);
    });

    test('setManualOfflineMode(true) sets server unreachable and manual offline', () async {
      await service.initialize();

      final states = <ConnectivityStatus>[];
      service.statusStream.listen(states.add);

      service.setManualOfflineMode(true);

      expect(service.isManualOffline, isTrue);
      expect(service.status.serverState, ServerConnectionState.unreachable);
      expect(service.status.isManualOffline, isTrue);
      expect(service.status.canAttemptRemote, isFalse);
      expect(service.status.shouldSkipRemote, isTrue);
    });

    test('setManualOfflineMode(true) emits status update', () async {
      await service.initialize();

      final completer = Completer<ConnectivityStatus>();
      service.statusStream.listen((s) {
        if (!completer.isCompleted) completer.complete(s);
      });

      // Allow the listener to register before emitting
      await Future<void>.delayed(Duration.zero);

      service.setManualOfflineMode(true);

      final emitted = await completer.future.timeout(
        const Duration(seconds: 1),
      );
      expect(emitted.isManualOffline, isTrue);
    });

    test('setManualOfflineMode(false) resumes and triggers health check', () async {
      await service.initialize();
      service.setManualOfflineMode(true);
      healthCheckCalled = false;

      service.setManualOfflineMode(false);

      expect(service.isManualOffline, isFalse);
      expect(service.status.isManualOffline, isFalse);

      // Health check should have been called
      // Give it a tick to run
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(healthCheckCalled, isTrue);
    });

    test('setManualOfflineMode is idempotent', () async {
      await service.initialize();

      final states = <ConnectivityStatus>[];
      service.statusStream.listen(states.add);

      service.setManualOfflineMode(true);
      final countAfterFirst = states.length;

      service.setManualOfflineMode(true); // no-op
      expect(states.length, countAfterFirst);
    });

    test('manual offline stops health check timers', () async {
      await service.initialize();
      healthCheckCalled = false;

      service.setManualOfflineMode(true);
      healthCheckCalled = false;

      // Wait longer than any reasonable check interval for tests
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // No health check should have been triggered by timers
      expect(healthCheckCalled, isFalse);
    });
  });
}
