import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../../core/database/providers.dart';
import '../../../../../../core/services/config_service.dart';

/// Tab para mostrar las salidas de efectivo de la sesion
class CashOutsTab extends ConsumerWidget {
  final int sessionId;

  const CashOutsTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashOutsAsync = ref.watch(sessionCashOutsProvider(sessionId));
    final theme = FluentTheme.of(context);
    final appConfig = ref.watch(configServiceProvider);
    // Construir formato datetime basado en el formato de fecha configurado
    final dateTimeFormat = _buildDateTimeFormat(appConfig.dateFormat);
    final dateFormat = DateFormat(dateTimeFormat, 'es');

    return cashOutsAsync.when(
      data: (cashOuts) {
        if (cashOuts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.money, size: 48),
                  SizedBox(height: 16),
                  Text('No hay salidas de efectivo registradas.'),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: cashOuts.length,
          itemBuilder: (context, index) {
            final cashOut = cashOuts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile.selectable(
                leading: Icon(FluentIcons.money, color: Colors.red),
                title: Text(cashOut.name ?? 'Sin motivo'),
                subtitle: Text(
                  dateFormat.format(cashOut.date),
                ),
                trailing: Text(
                  '-${cashOut.amount.toCurrency()}',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            );
          },
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

  /// Construye un formato de fecha/hora basado en el formato de fecha base
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
