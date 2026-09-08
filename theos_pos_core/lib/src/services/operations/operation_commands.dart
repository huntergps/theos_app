import 'operation_outcome.dart';

class CommandScope {
  final String scopeKey;
  final int companyId;

  CommandScope({required String scopeKey, required int companyId})
    : scopeKey = _nonEmpty(scopeKey, 'scopeKey'),
      companyId = _positive(companyId, 'companyId');
}

class CommandTarget {
  final EntityReference entity;
  final int? expectedVersion;

  CommandTarget({required this.entity, int? expectedVersion})
    : expectedVersion = expectedVersion {
    if (expectedVersion != null && expectedVersion < 0) {
      throw ArgumentError.value(expectedVersion, 'expectedVersion');
    }
  }
}

abstract class OperationCommand {
  final CommandScope scope;
  final String commandId;
  final CommandTarget target;

  OperationCommand({
    required this.scope,
    required String commandId,
    required this.target,
  }) : commandId = _nonEmpty(commandId, 'commandId');
}

class CreateOrder extends OperationCommand {
  CreateOrder({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class UpdateOrder extends OperationCommand {
  UpdateOrder({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class RequestApproval extends OperationCommand {
  RequestApproval({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class ConfirmOrder extends OperationCommand {
  ConfirmOrder({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class GenerateDispatch extends OperationCommand {
  GenerateDispatch({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class RegisterCollection extends OperationCommand {
  RegisterCollection({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class OpenCashSession extends OperationCommand {
  OpenCashSession({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

class CloseCashSession extends OperationCommand {
  CloseCashSession({
    required super.scope,
    required super.commandId,
    required super.target,
  });
}

String _nonEmpty(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty)
    throw ArgumentError.value(value, name, 'Must not be empty');
  return trimmed;
}

int _positive(int value, String name) {
  if (value <= 0) throw ArgumentError.value(value, name, 'Must be positive');
  return value;
}
