import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Fila de botones de accion para la sesion de cobranza
class ActionButtonsRow extends StatelessWidget {
  final CollectionSession session;
  final VoidCallback? onRegisterFund;
  final VoidCallback? onRegisterCash;
  final VoidCallback? onRegisterCashOut;
  final VoidCallback? onRegisterDeposit;
  final VoidCallback? onRegisterAdvance;

  const ActionButtonsRow({
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Button(
          onPressed: onRegisterFund,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.money, size: 16),
              SizedBox(width: 6),
              Text('Registrar Fondo'),
            ],
          ),
        ),
        Button(
          onPressed: onRegisterCash,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.calculator, size: 16),
              SizedBox(width: 6),
              Text('Registrar Efectivo'),
            ],
          ),
        ),
        Button(
          onPressed: onRegisterCashOut,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.down, size: 16),
              SizedBox(width: 6),
              Text('Registrar Salida'),
            ],
          ),
        ),
        Button(
          onPressed: onRegisterDeposit,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.bank, size: 16),
              SizedBox(width: 6),
              Text('Registrar Deposito'),
            ],
          ),
        ),
        Button(
          onPressed: onRegisterAdvance,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.pinned, size: 16),
              SizedBox(width: 6),
              Text('Registrar Anticipo'),
            ],
          ),
        ),
      ],
    );
  }
}
