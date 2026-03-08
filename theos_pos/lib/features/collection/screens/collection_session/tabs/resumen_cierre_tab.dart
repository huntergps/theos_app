import 'package:fluent_ui/fluent_ui.dart';

import '../widgets/action_buttons_row.dart';
import '../widgets/resumen_efectivo_table.dart';
import '../widgets/facturas_emitidas_table.dart';
import '../widgets/detalle_retiros_table.dart';
import '../widgets/control_depositos_table.dart';
import '../widgets/cheques_recibidos_table.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tab de resumen de cierre de la sesion de cobranza
class ResumenCierreTab extends StatelessWidget {
  final CollectionSession session;
  final VoidCallback? onRegisterFund;
  final VoidCallback? onRegisterCash;
  final VoidCallback? onRegisterCashOut;
  final VoidCallback? onRegisterDeposit;
  final VoidCallback? onRegisterAdvance;

  const ResumenCierreTab({
    super.key,
    required this.session,
    this.onRegisterFund,
    this.onRegisterCash,
    this.onRegisterCashOut,
    this.onRegisterDeposit,
    this.onRegisterAdvance,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Action buttons row
              ActionButtonsRow(
                session: session,
                onRegisterFund: onRegisterFund,
                onRegisterCash: onRegisterCash,
                onRegisterCashOut: onRegisterCashOut,
                onRegisterDeposit: onRegisterDeposit,
                onRegisterAdvance: onRegisterAdvance,
              ),
              const SizedBox(height: 16),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        children: [
                          ResumenEfectivoTable(session: session),
                          const SizedBox(height: 16),
                          FacturasEmitidasTable(session: session),
                          const SizedBox(height: 16),
                          DetalleRetirosTable(session: session),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right column
                    Expanded(
                      child: Column(
                        children: [
                          ControlDepositosTable(session: session),
                          const SizedBox(height: 16),
                          ChequesRecibidosTable(session: session),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ResumenEfectivoTable(session: session),
                    const SizedBox(height: 16),
                    FacturasEmitidasTable(session: session),
                    const SizedBox(height: 16),
                    DetalleRetirosTable(session: session),
                    const SizedBox(height: 16),
                    ControlDepositosTable(session: session),
                    const SizedBox(height: 16),
                    ChequesRecibidosTable(session: session),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
