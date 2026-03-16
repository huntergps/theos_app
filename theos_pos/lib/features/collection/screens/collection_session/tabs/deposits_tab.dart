import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/database/providers.dart';
import '../../../../../core/database/repositories/repository_providers.dart';
import '../../../../../core/services/config_service.dart';

import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../widgets/deposit_form_dialog.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tab para mostrar y gestionar los depositos de la sesion
class DepositsTab extends ConsumerWidget {
  final int sessionId;
  final bool canEdit;

  const DepositsTab({
    super.key,
    required this.sessionId,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositsAsync = ref.watch(sessionDepositsProvider(sessionId));
    final theme = FluentTheme.of(context);
    final appConfig = ref.watch(configServiceProvider);
    final dateTimeFormat = _buildDateTimeFormat(appConfig.dateFormat);
    final dateFormat = DateFormat(dateTimeFormat, 'es');

    return depositsAsync.when(
      data: (deposits) {
        return Column(
          children: [
            // Header con boton de agregar
            if (canEdit)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Depositos (${deposits.length})',
                      style: theme.typography.subtitle,
                    ),
                    FilledButton(
                      onPressed: () => _showAddDialog(context, ref),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.add, size: 14),
                          SizedBox(width: 8),
                          Text('Nuevo Deposito'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Lista o mensaje vacio
            Expanded(
              child: deposits.isEmpty
                  ? _buildEmptyState(context, ref)
                  : _buildDepositsList(
                      context,
                      ref,
                      deposits,
                      theme,
                      dateFormat,
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (error, _) => Center(
        child: InfoBar(
          title: const Text('Error'),
          content: Text(error.toString()),
          severity: InfoBarSeverity.error,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.bank, size: 48),
            const SizedBox(height: 16),
            const Text('No hay depositos registrados en esta sesion.'),
            if (canEdit) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _showAddDialog(context, ref),
                child: const Text('Agregar Deposito'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDepositsList(
    BuildContext context,
    WidgetRef ref,
    List<CollectionSessionDeposit> deposits,
    FluentThemeData theme,
    DateFormat dateFormat,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: deposits.length,
      itemBuilder: (context, index) {
        final deposit = deposits[index];
        return _buildDepositCard(context, ref, deposit, theme, dateFormat);
      },
    );
  }

  Widget _buildDepositCard(
    BuildContext context,
    WidgetRef ref,
    CollectionSessionDeposit deposit,
    FluentThemeData theme,
    DateFormat dateFormat,
  ) {
    final typeInfo = _getDepositTypeInfo(deposit.depositType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con tipo y monto
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    typeInfo.icon,
                    size: 16,
                    color: typeInfo.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeInfo.label,
                        style: theme.typography.bodyStrong,
                      ),
                      if (deposit.bankJournalName != null)
                        Text(
                          deposit.bankJournalName!,
                          style: theme.typography.caption?.copyWith(
                            color: theme.inactiveColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  deposit.amount.toCurrency(),
                  style: theme.typography.subtitle?.copyWith(
                    color: theme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Detalles
            Row(
              children: [
                // Fecha
                Expanded(
                  child: _buildDetailItem(
                    theme,
                    FluentIcons.calendar,
                    'Fecha',
                    deposit.depositDate != null
                        ? dateFormat.format(deposit.depositDate!)
                        : '-',
                  ),
                ),
                // Papeleta
                if (deposit.depositSlipNumber != null)
                  Expanded(
                    child: _buildDetailItem(
                      theme,
                      FluentIcons.number_field,
                      'Papeleta',
                      deposit.depositSlipNumber!,
                    ),
                  ),
              ],
            ),

            // Desglose para depositos mixtos
            if (deposit.depositType == DepositType.mixed) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      theme,
                      FluentIcons.money,
                      'Efectivo',
                      deposit.cashAmount.toCurrency(),
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      theme,
                      FluentIcons.check_list,
                      'Cheques (${deposit.checkCount})',
                      deposit.checkAmount.toCurrency(),
                    ),
                  ),
                ],
              ),
            ],

            // Acciones
            if (canEdit) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Button(
                    onPressed: () => _showEditDialog(context, ref, deposit),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.edit, size: 12),
                        SizedBox(width: 6),
                        Text('Editar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    FluentThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 12, color: theme.inactiveColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
            Text(value, style: theme.typography.body),
          ],
        ),
      ],
    );
  }

  ({IconData icon, String label, Color color}) _getDepositTypeInfo(
      DepositType type) {
    switch (type) {
      case DepositType.cash:
        return (
          icon: FluentIcons.money,
          label: 'Deposito Efectivo',
          color: Colors.green,
        );
      case DepositType.check:
        return (
          icon: FluentIcons.check_list,
          label: 'Deposito Cheques',
          color: Colors.blue,
        );
      case DepositType.mixed:
        return (
          icon: FluentIcons.switch_widget,
          label: 'Deposito Mixto',
          color: Colors.orange,
        );
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<CollectionSessionDeposit>(
      context: context,
      builder: (context) => DepositFormDialog(sessionId: sessionId),
    );

    if (result != null && context.mounted) {
      try {
        final repository = ref.read(collectionRepositoryProvider);
        if (repository == null) {
          throw Exception('Repository no disponible');
        }
        final resultEither = await repository.createDeposit(result);

        resultEither.fold(
          (failure) {
            if (context.mounted) {
              CopyableInfoBar.showError(
                context,
                title: 'Error al guardar deposito',
                message: 'No se pudo guardar el deposito: ${failure.message}',
              );
            }
          },
          (deposit) {
            // Refresh the deposits list
            ref.invalidate(sessionDepositsProvider(sessionId));

            if (context.mounted) {
              CopyableInfoBar.showSuccess(
                context,
                title: 'Éxito',
                message: 'Depósito guardado correctamente',
              );
            }
          },
        );
      } catch (e) {
        logger.e('[DepositsTab]', 'Error saving deposit: $e');
        if (context.mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Error al guardar deposito',
            message: 'Ocurrio un error inesperado. Intente nuevamente.',
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    CollectionSessionDeposit deposit,
  ) async {
    final result = await showDialog<CollectionSessionDeposit>(
      context: context,
      builder: (context) => DepositFormDialog(
        sessionId: sessionId,
        initialDeposit: deposit,
      ),
    );

    if (result != null && context.mounted) {
      try {
        final repository = ref.read(collectionRepositoryProvider);
        if (repository == null) {
          throw Exception('Repository no disponible');
        }
        final resultEither = await repository.updateDeposit(result);

        resultEither.fold(
          (failure) {
            if (context.mounted) {
              CopyableInfoBar.showError(
                context,
                title: 'Error al actualizar deposito',
                message: 'No se pudo actualizar el deposito: ${failure.message}',
              );
            }
          },
          (updatedDeposit) {
            // Refresh the deposits list
            ref.invalidate(sessionDepositsProvider(sessionId));

            if (context.mounted) {
              CopyableInfoBar.showSuccess(
                context,
                title: 'Éxito',
                message: 'Depósito actualizado correctamente',
              );
            }
          },
        );
      } catch (e) {
        logger.e('[DepositsTab]', 'Error updating deposit: $e');
        if (context.mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Error al actualizar deposito',
            message: 'Ocurrio un error inesperado. Intente nuevamente.',
          );
        }
      }
    }
  }

  String _buildDateTimeFormat(String baseFormat) {
    if (baseFormat.contains('H') ||
        baseFormat.contains('h') ||
        (baseFormat.contains('m') && baseFormat.contains('a'))) {
      return baseFormat;
    }
    if (baseFormat == 'dd/MM/yyyy') {
      return 'dd/MM/yyyy HH:mm';
    } else if (baseFormat == 'MM/dd/yyyy') {
      return 'MM/dd/yyyy h:mm a';
    } else if (baseFormat == 'yyyy-MM-dd') {
      return 'yyyy-MM-dd HH:mm';
    } else if (baseFormat == 'd MMM, yyyy') {
      return 'd MMM, yyyy h:mm a';
    }
    return '$baseFormat HH:mm';
  }
}
