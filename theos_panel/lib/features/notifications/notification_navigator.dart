import 'package:orbi_runtime/orbi_runtime.dart';

abstract interface class NotificationNavigationValidation {
  Future<bool> sessionIsActive(NotificationScope scope);
  Future<bool> companyIsAllowed(NotificationScope scope);
  Future<bool> targetExists(NotificationTarget target, NotificationScope scope);
  Future<bool> canOpen(NotificationTarget target, NotificationScope scope);
}

typedef NotificationTargetOpener = Future<void> Function(
  NotificationTarget target,
  NotificationScope scope,
);

/// Resolves only explicitly allowlisted, read-only destinations. It never
/// interprets a target as a command or URL.
final class NotificationNavigator {
  NotificationNavigator({
    required this.validation,
    required this.opener,
    required Set<String> allowedTargetTypes,
  }) : allowedTargetTypes = Set.unmodifiable(allowedTargetTypes);

  final NotificationNavigationValidation validation;
  final NotificationTargetOpener opener;
  final Set<String> allowedTargetTypes;

  Future<NotificationNavigationResult> open({
    required NotificationTarget target,
    required NotificationScope scope,
  }) async {
    if (!allowedTargetTypes.contains(target.type) ||
        !_safeReference(target.reference)) {
      return NotificationNavigationResult.rejected;
    }
    if (!await validation.sessionIsActive(scope) ||
        !await validation.companyIsAllowed(scope) ||
        !await validation.targetExists(target, scope) ||
        !await validation.canOpen(target, scope)) {
      return NotificationNavigationResult.rejected;
    }
    await opener(target, scope);
    return NotificationNavigationResult.opened;
  }

  static bool _safeReference(String reference) {
    if (reference.trim().isEmpty || reference.contains('://')) return false;
    return RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(reference);
  }
}

enum NotificationNavigationResult { opened, rejected }
