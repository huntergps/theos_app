import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/base_form_dialog.dart';
import '../../../../../shared/widgets/reactive/reactive_widgets.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Diálogo para crear/editar un depósito.
/// 
/// Migrado a usar [StatefulFormDialog] para consistencia
/// con otros diálogos de formulario.
class DepositFormDialog extends StatefulFormDialog<CollectionSessionDeposit> {
  final int sessionId;
  final CollectionSessionDeposit? initialDeposit;

  const DepositFormDialog({
    super.key,
    required this.sessionId,
    this.initialDeposit,
  });

  bool get _isEditing => initialDeposit != null;

  @override
  FormDialogConfig get config => FormDialogConfig(
    title: _isEditing ? 'Editar Depósito' : 'Nuevo Depósito',
    icon: _isEditing ? FluentIcons.edit : FluentIcons.add,
    maxWidth: 500,
    primaryButtonText: _isEditing ? 'Guardar' : 'Crear',
  );

  @override
  StatefulFormDialogState<CollectionSessionDeposit, DepositFormDialog> createState() =>
      _DepositFormDialogState();
}

class _DepositFormDialogState
    extends StatefulFormDialogState<CollectionSessionDeposit, DepositFormDialog> {
  late DepositType _depositType;
  late double _amount;
  late double _cashAmount;
  late double _checkAmount;
  late int _checkCount;
  late DateTime? _depositDate;
  late DateTime? _accountingDate;
  late String _depositSlipNumber;
  late String _bankReference;
  late String _depositorName;
  late String _notes;

  @override
  void initState() {
    super.initState();
    final deposit = widget.initialDeposit;
    _depositType = deposit?.depositType ?? DepositType.cash;
    _amount = deposit?.amount ?? 0.0;
    _cashAmount = deposit?.cashAmount ?? 0.0;
    _checkAmount = deposit?.checkAmount ?? 0.0;
    _checkCount = deposit?.checkCount ?? 0;
    _depositDate = deposit?.depositDate ?? DateTime.now();
    _accountingDate = deposit?.accountingDate ?? DateTime.now();
    _depositSlipNumber = deposit?.depositSlipNumber ?? '';
    _bankReference = deposit?.bankReference ?? '';
    _depositorName = deposit?.depositorName ?? '';
    _notes = deposit?.notes ?? '';
  }

  @override
  FormDialogConfig get currentConfig => widget.config.copyWith(
    isPrimaryEnabled: _amount > 0 && _depositDate != null,
  );

  @override
  FormValidationState validate() {
    return FormValidationState.fromErrors([
      if (_amount <= 0) 'El monto debe ser mayor a 0',
      if (_depositDate == null) 'La fecha de depósito es requerida',
    ]);
  }

  @override
  Widget buildForm(BuildContext context) {
    final theme = FluentTheme.of(context);

    return SizedBox(
      width: 450,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo de deposito
          ReactiveSelectionField<DepositType>(
            config: ReactiveFieldConfig(
              label: 'Tipo de Depósito',
              isEditing: true,
              prefixIcon: FluentIcons.bank,
            ),
            value: _depositType,
            options: [
              SelectionOption(
                value: DepositType.cash,
                label: 'Efectivo',
                icon: FluentIcons.money,
                color: Colors.green,
              ),
              SelectionOption(
                value: DepositType.check,
                label: 'Cheque',
                icon: FluentIcons.check_list,
                color: Colors.blue,
              ),
              SelectionOption(
                value: DepositType.mixed,
                label: 'Mixto',
                icon: FluentIcons.switch_widget,
                color: Colors.orange,
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _depositType = value;
                  _updateAmounts();
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Fecha de deposito
          ReactiveDateField(
            config: ReactiveFieldConfig(
              label: 'Fecha de Depósito',
              isEditing: true,
              prefixIcon: FluentIcons.calendar,
              isRequired: true,
            ),
            value: _depositDate,
            showTime: true,
            onChanged: (date) {
              setState(() => _depositDate = date);
            },
          ),
          const SizedBox(height: 16),

          // Fecha contable
          ReactiveDateField(
            config: ReactiveFieldConfig(
              label: 'Fecha Contable',
              isEditing: true,
              prefixIcon: FluentIcons.calendar,
            ),
            value: _accountingDate,
            onChanged: (date) {
              setState(() => _accountingDate = date);
            },
          ),
          const SizedBox(height: 16),

          // Montos segun tipo
          if (_depositType == DepositType.cash ||
              _depositType == DepositType.mixed) ...[
            ReactiveMoneyField(
              config: ReactiveFieldConfig(
                label: 'Monto Efectivo',
                isEditing: true,
                prefixIcon: FluentIcons.money,
              ),
              value: _cashAmount,
              onChanged: (value) {
                setState(() {
                  _cashAmount = value ?? 0;
                  _updateAmounts();
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          if (_depositType == DepositType.check ||
              _depositType == DepositType.mixed) ...[
            ReactiveMoneyField(
              config: ReactiveFieldConfig(
                label: 'Monto Cheques',
                isEditing: true,
                prefixIcon: FluentIcons.check_list,
              ),
              value: _checkAmount,
              onChanged: (value) {
                setState(() {
                  _checkAmount = value ?? 0;
                  _updateAmounts();
                });
              },
            ),
            const SizedBox(height: 16),
            ReactiveNumberField(
              config: ReactiveFieldConfig(
                label: 'Cantidad de Cheques',
                isEditing: true,
                prefixIcon: FluentIcons.number_field,
              ),
              value: _checkCount.toDouble(),
              decimals: 0,
              min: 0,
              onChanged: (value) {
                setState(() {
                  _checkCount = (value ?? 0).toInt();
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          // Total (solo lectura)
          _buildTotalCard(theme),
          const SizedBox(height: 16),

          // Datos del comprobante
          _buildSectionHeader(theme, 'Datos del Comprobante'),
          const SizedBox(height: 12),

          ReactiveTextField(
            config: ReactiveFieldConfig(
              label: 'Número de Papeleta',
              isEditing: true,
              prefixIcon: FluentIcons.number_field,
            ),
            value: _depositSlipNumber,
            onChanged: (value) {
              setState(() => _depositSlipNumber = value ?? '');
            },
          ),
          const SizedBox(height: 16),

          ReactiveTextField(
            config: ReactiveFieldConfig(
              label: 'Referencia Bancaria',
              isEditing: true,
              prefixIcon: FluentIcons.bank,
            ),
            value: _bankReference,
            onChanged: (value) {
              setState(() => _bankReference = value ?? '');
            },
          ),
          const SizedBox(height: 16),

          ReactiveTextField(
            config: ReactiveFieldConfig(
              label: 'Nombre del Depositante',
              isEditing: true,
              prefixIcon: FluentIcons.contact,
            ),
            value: _depositorName,
            onChanged: (value) {
              setState(() => _depositorName = value ?? '');
            },
          ),
          const SizedBox(height: 16),

          ReactiveMultilineField(
            config: ReactiveFieldConfig(
              label: 'Notas',
              isEditing: true,
              prefixIcon: FluentIcons.edit_note,
            ),
            value: _notes,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) {
              setState(() => _notes = value ?? '');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(FluentIcons.calculator, size: 16, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('TOTAL:', style: theme.typography.bodyStrong),
            ],
          ),
          Text(
            _amount.toCurrency(),
            style: theme.typography.subtitle?.copyWith(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(FluentThemeData theme, String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: theme.accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: theme.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _updateAmounts() {
    switch (_depositType) {
      case DepositType.cash:
        _amount = _cashAmount;
        _checkAmount = 0;
        _checkCount = 0;
        break;
      case DepositType.check:
        _amount = _checkAmount;
        _cashAmount = 0;
        break;
      case DepositType.mixed:
        _amount = _cashAmount + _checkAmount;
        break;
    }
  }

  @override
  Future<CollectionSessionDeposit?> onSubmit() async {
    return CollectionSessionDeposit(
      id: widget.initialDeposit?.id ?? 0,
      collectionSessionId: widget.sessionId,
      depositType: _depositType,
      amount: _amount,
      cashAmount: _cashAmount,
      checkAmount: _checkAmount,
      checkCount: _checkCount,
      depositDate: _depositDate,
      accountingDate: _accountingDate,
      depositSlipNumber: _depositSlipNumber.isNotEmpty ? _depositSlipNumber : null,
      bankReference: _bankReference.isNotEmpty ? _bankReference : null,
      depositorName: _depositorName.isNotEmpty ? _depositorName : null,
      notes: _notes.isNotEmpty ? _notes : null,
      isSynced: false,
    );
  }
}
