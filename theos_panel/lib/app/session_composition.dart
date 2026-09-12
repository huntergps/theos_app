import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../ui/fluent/orbi_page.dart';

import '../features/activities/activity_center.dart';
import '../features/auth/auth_controller.dart';
import '../features/home/home_center.dart';
import '../features/notifications/notification_inbox.dart';
import '../features/notifications/notification_navigator.dart';
import '../features/reports/document_view.dart';
import '../features/sync/sync_center.dart';
import 'notification_scope_adapter.dart';
import '../features/approvals/approval_contracts.dart';
import 'business_composition_factory.dart';

/// Composition boundary for services belonging to the active app scope.
/// Missing ports remain explicit so the UI cannot report an empty success.
final class OrbiSessionComposition {
  const OrbiSessionComposition({
    this.authService,
    this.runtime,
    this.notificationPresenter,
    this.syncCoordinator,
    this.notificationIds,
    this.capabilities,
    this.home,
    this.activities,
    this.sync,
    this.notifications,
    this.notificationNavigator,
    this.documents,
    this.approvals,
    this.catalogs,
    this.saleCommands,
    this.business,
  });

  final AuthServicePort? authService;
  final SessionRuntime? runtime;
  final SystemNotificationPresenter? notificationPresenter;
  final SyncCoordinatorImpl? syncCoordinator;
  final NotificationSystemIdAllocator? notificationIds;
  final CapabilitySnapshot? capabilities;
  final HomeResumePort? home;
  final ActivityPort? activities;
  final SyncCenterPort? sync;
  final NotificationInboxPort? notifications;
  final NotificationNavigator? notificationNavigator;
  final DocumentRenderPort? documents;
  final ApprovalPort? approvals;
  final RuntimeCatalogComposition? catalogs;
  final RuntimeSaleCommandPort? saleCommands;
  final OrbiBusinessComposition? business;

  List<dynamic> get overrides => [
    orbiSessionCompositionProvider.overrideWithValue(this),
    if (authService != null)
      authServiceProvider.overrideWithValue(authService!),
    runtimeSessionProvider.overrideWithValue(runtime),
    notificationPresenterProvider.overrideWithValue(notificationPresenter),
    notificationSystemIdAllocatorProvider.overrideWithValue(notificationIds),
    if (capabilities != null)
      capabilitySnapshotProvider.overrideWithValue(capabilities!),
    if (home != null) homeResumePortProvider.overrideWithValue(home!),
    if (activities != null) activityPortProvider.overrideWithValue(activities!),
    if (sync != null) syncCenterPortProvider.overrideWithValue(sync!),
    if (syncCoordinator != null)
      syncCoordinatorProvider.overrideWithValue(syncCoordinator!),
    if (notifications != null)
      notificationInboxPortProvider.overrideWithValue(notifications!),
    if (documents != null)
      documentRenderPortProvider.overrideWithValue(documents!),
  ];
}

final orbiSessionCompositionProvider = Provider<OrbiSessionComposition>(
  (ref) => const OrbiSessionComposition(),
);

/// Retains the exact runtime instance used by authentication. Consumers must
/// never construct a second database/client owner for the active scope.
final notificationPresenterProvider = Provider<SystemNotificationPresenter?>(
  (ref) => null,
);

class NotConfiguredPage extends StatelessWidget {
  const NotConfiguredPage({required this.title, super.key, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: title,
    subtitle: 'Todavía no está configurado',
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.settings, size: 40),
          const SizedBox(height: 12),
          Text('$title no configurado', textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}
