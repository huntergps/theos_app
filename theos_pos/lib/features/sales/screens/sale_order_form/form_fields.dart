import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/clients.dart' show Client, SelectClientDialog;
import '../../../../core/database/providers.dart' show partnerProvider;
import '../../../../shared/widgets/order_config_card.dart';
import '../../../../shared/widgets/reactive/reactive_widgets.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../providers/providers.dart';
import '../../widgets/credit_info_card.dart';
import 'edit_dialogs.dart';
import 'form_sections.dart';

// ============================================================================
// HELPER PARA SELECTORES DE CAMPO
// ============================================================================

/// Selecciona un valor del provider en modo edición o del order en modo vista
///
/// Elimina el patrón repetitivo:
/// ```dart
/// final value = isEditing
///     ? ref.watch(provider.select((s) => s.field))
///     : order?.field;
/// ```
T? _selectField<T>(
  WidgetRef ref,
  bool isEditing,
  T? Function(SaleOrderFormState s) selector,
  T? fallback,
) {
  return isEditing
      ? ref.watch(saleOrderFormProvider.select(selector))
      : fallback;
}

/// Fields unificados para SaleOrderFormScreen (Section 2)
///
/// Usa widgets reactivos que se actualizan automáticamente cuando
/// cambian los datos en la base de datos SQLite.
///
/// Soporta dos modos:
/// - Vista (isEditing: false): Solo lectura, usa datos de [order]
/// - Edición (isEditing: true): Editable, usa [saleOrderFormProvider]
class SaleOrderFormFields extends ConsumerWidget {
  final bool isEditing;
  final SaleOrder? order;

  /// Modo compacto - solo muestra la primera fila de cada card
  /// Útil cuando el teclado está visible para ganar espacio
  final bool isCompact;

  const SaleOrderFormFields({
    super.key,
    required this.isEditing,
    this.order,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En modo vista sin order, no mostrar nada
    if (!isEditing && order == null) return const SizedBox.shrink();

    // Un solo método unificado para vista y edición
    return _buildFields(context, ref);
  }

  // ============================================================
  // BUILD UNIFICADO - Un solo widget para vista y edición
  // ============================================================
  Widget _buildFields(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(themedSpacingProvider);

    // Datos de partner - usando helper _selectField
    final partnerId = _selectField(
      ref,
      isEditing,
      (s) => s.partnerId,
      order?.partnerId,
    );

    // Cargar datos completos del partner desde la tabla local res_partners
    final partnerAsync = partnerId != null
        ? ref.watch(partnerProvider(partnerId))
        : null;
    final partner = partnerAsync?.value;

    // Preferir datos de la BD local, fallback a datos del form/order
    final partnerName = partner?.name ?? _selectField(
      ref,
      isEditing,
      (s) => s.partnerName,
      order?.partnerName,
    );
    final partnerVat = partner?.vat ?? _selectField(
      ref,
      isEditing,
      (s) => s.partnerVat,
      order?.partnerVat,
    );
    final partnerStreet = partner?.street ?? _selectField(
      ref,
      isEditing,
      (s) => s.partnerStreet,
      order?.partnerStreet,
    );
    final partnerPhone = partner?.phone ?? _selectField(
      ref,
      isEditing,
      (s) => s.partnerPhone,
      order?.partnerPhone,
    );
    final partnerEmail = partner?.email ?? _selectField(
      ref,
      isEditing,
      (s) => s.partnerEmail,
      order?.partnerEmail,
    );
    final partnerAvatar = partner?.avatar128 ?? _selectField(
      ref,
      isEditing,
      (s) => s.partnerAvatar,
      order?.partnerAvatar,
    );
    final isFinalConsumer =
        _selectField(
          ref,
          isEditing,
          (s) => s.isFinalConsumer,
          order?.isFinalConsumer,
        ) ??
        false;
    final endCustomerName = _selectField(
      ref,
      isEditing,
      (s) => s.endCustomerName,
      order?.endCustomerName,
    );
    final endCustomerPhone = _selectField(
      ref,
      isEditing,
      (s) => s.endCustomerPhone,
      order?.endCustomerPhone,
    );
    final endCustomerEmail = _selectField(
      ref,
      isEditing,
      (s) => s.endCustomerEmail,
      order?.endCustomerEmail,
    );

    // Flags de compañía - usando helper _selectField
    final companyRequiresEndCustomerData =
        _selectField(
          ref,
          isEditing,
          (s) => s.companyRequiresEndCustomerData,
          false,
        ) ??
        false;
    final companyRequiresReferrer =
        _selectField(ref, isEditing, (s) => s.companyRequiresReferrer, false) ??
        false;
    final companyRequiresTipoCanalCliente =
        _selectField(
          ref,
          isEditing,
          (s) => s.companyRequiresTipoCanalCliente,
          false,
        ) ??
        false;

    // Referrer data - added to use within ReactivePartnerCard like POS
    final referrerId = _selectField(
      ref,
      isEditing,
      (s) => s.referrerId,
      order?.referrerId,
    );
    final referrerName = _selectField(
      ref,
      isEditing,
      (s) => s.referrerName,
      order?.referrerName,
    );

    // Callbacks para edición
    final notifier = isEditing
        ? ref.read(saleOrderFormProvider.notifier)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section2Info con widgets reactivos unificados
        FormSection2Info(
          clientCard: ReactivePartnerCard(
            config: ReactiveFieldConfig(label: 'Cliente', isEditing: isEditing),
            partner: PartnerInfo(
              id: partnerId,
              name: partnerName,
              vat: partnerVat,
              street: partnerStreet,
              phone: partnerPhone,
              email: partnerEmail,
              avatar: partnerAvatar,
              isFinalConsumer: isFinalConsumer,
              endCustomerName: endCustomerName,
              endCustomerPhone: endCustomerPhone,
              endCustomerEmail: endCustomerEmail,
              // Pass referrer info to display in same card like POS does
              referrerId: referrerId,
              referrerName: referrerName,
            ),
            callbacks: isEditing
                ? PartnerCardCallbacks(
                    onSelectPartner: () =>
                        _showSelectPartnerDialog(context, ref),
                    onCreatePartner: () =>
                        _showCreateClientOfflineDialog(context, ref),
                    onPhoneChanged: (value) =>
                        notifier!.updatePartnerPhone(value),
                    onEmailChanged: (value) =>
                        notifier!.updatePartnerEmail(value),
                    onEndCustomerNameChanged: (value) =>
                        notifier!.updateField('end_customer_name', value),
                    onEndCustomerPhoneChanged: (value) =>
                        notifier!.updateField('end_customer_phone', value),
                    onEndCustomerEmailChanged: (value) =>
                        notifier!.updateField('end_customer_email', value),
                    // Add referrer callback like POS does
                    onSelectReferrer: companyRequiresReferrer
                        ? () => _showSelectReferrerDialog(context, ref)
                        : null,
                  )
                : const PartnerCardCallbacks(),
            endCustomerFieldsRequired: companyRequiresEndCustomerData,
            isCompact: isCompact,
          ),
          creditCard: PartnerCreditInfoCard(
            partnerId: partnerId,
            orderId: order?.id,
            isCompact: isCompact,
          ),
          datesCard: UnifiedOrderConfigCard(
            isEditing: isEditing,
            isCompact: isCompact,
            dateOrder: order?.dateOrder,
            pricelistName: order?.pricelistName,
            paymentTermName: order?.paymentTermName,
            warehouseName: order?.warehouseName,
            userName: order?.userName,
          ),
        ),

        // Removed ReactiveReferrerField - now displayed inside ReactivePartnerCard
        if (companyRequiresTipoCanalCliente) ...[
          SizedBox(height: spacing.md),
          ReactiveCustomerTypeChannelFields(isEditing: isEditing),
        ],
      ],
    );
  }

  Future<void> _showSelectPartnerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    logger.d('[SaleOrderFormFields]', '>>> Opening SelectClientDialog...');

    final client = await showDialog<Client>(
      context: context,
      builder: (context) => const SelectClientDialog(),
    );

    logger.d('[SaleOrderFormFields]', '>>> Dialog closed, result: $client');

    if (client != null) {
      logger.i(
        '[SaleOrderFormFields]',
        '>>> UPDATING PARTNER: ${client.name} (ID: ${client.id}, VAT: ${client.vat})',
      );

      // Log current state before update
      final stateBefore = ref.read(saleOrderFormProvider);
      logger.d(
        '[SaleOrderFormFields]',
        '>>> State BEFORE update: partnerId=${stateBefore.partnerId}, partnerName=${stateBefore.partnerName}',
      );

      ref.read(saleOrderFormProvider.notifier).updatePartner(
            client.id,
            client.name,
            vat: client.vat,
            street: client.street,
            phone: client.phone ?? client.mobile,
            email: client.email,
            paymentTermIds: null, // Not available in Client model
            propertyPaymentTermId: client.propertyPaymentTermId,
            propertyPaymentTermName: client.propertyPaymentTermName,
          );

      // Log state after update
      final stateAfter = ref.read(saleOrderFormProvider);
      logger.d(
        '[SaleOrderFormFields]',
        '>>> State AFTER update: partnerId=${stateAfter.partnerId}, partnerName=${stateAfter.partnerName}',
      );
    } else {
      logger.d('[SaleOrderFormFields]', '>>> Dialog cancelled (no selection)');
    }
  }

  /// Show dialog to create a client offline
  Future<void> _showCreateClientOfflineDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateClientOfflineDialog(),
    );

    if (result != null) {
      final partnerId = result['id'] as int;
      final partnerName = result['name'] as String;
      final partnerVat = result['vat'] as String?;
      final partnerEmail = result['email'] as String?;
      final partnerPhone = result['phone'] as String?;
      final partnerStreet = result['street'] as String?;

      logger.d(
        '[SaleOrderFormFields]',
        'Created offline partner: $partnerName (localID: $partnerId)',
      );
      ref
          .read(saleOrderFormProvider.notifier)
          .updatePartner(
            partnerId,
            partnerName,
            vat: partnerVat,
            street: partnerStreet,
            phone: partnerPhone,
            email: partnerEmail,
          );
    }
  }

  /// Show dialog to select a referrer
  Future<void> _showSelectReferrerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const SelectClientDialog(),
    );

    if (result != null) {
      final referrerId = result['id'] as int;
      final referrerName = result['name'] as String;

      ref
          .read(saleOrderFormProvider.notifier)
          .updateField('referrer_id', referrerId);
      ref
          .read(saleOrderFormProvider.notifier)
          .updateField('referrer_name', referrerName);
    }
  }
}

// ============================================================================
// CARD DE CONFIGURACION UNIFICADA - Vista y Edición en un solo widget
// ============================================================================

/// Card de configuración de orden unificada (fecha, pricelist, payment term, warehouse, user)
///
/// Wrapper around [OrderConfigCard] that connects to [saleOrderFormProvider].
/// Un solo widget que maneja tanto vista como edición mediante [isEditing].
///
/// En modo vista: Muestra valores como texto (no editable)
/// En modo edición: Muestra selectores interactivos (ReactiveMasterSelector)
class UnifiedOrderConfigCard extends ConsumerWidget {
  /// Indica si está en modo edición
  final bool isEditing;

  /// Modo compacto - solo muestra fecha (útil cuando el teclado está visible)
  final bool isCompact;

  /// Datos para modo vista (requerido si !isEditing)
  final DateTime? dateOrder;
  final String? pricelistName;
  final String? paymentTermName;
  final String? warehouseName;
  final String? userName;

  const UnifiedOrderConfigCard({
    super.key,
    required this.isEditing,
    this.isCompact = false,
    this.dateOrder,
    this.pricelistName,
    this.paymentTermName,
    this.warehouseName,
    this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En modo edición, usamos los valores del form state
    // En modo vista, usamos los props pasados
    final effectiveDateOrder = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.dateOrder))
        : dateOrder;
    final effectivePricelistId = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.pricelistId))
        : null;
    final effectivePricelistName = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.pricelistName))
        : pricelistName;
    final effectivePaymentTermId = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.paymentTermId))
        : null;
    final effectivePaymentTermName = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.paymentTermName))
        : paymentTermName;
    final effectiveWarehouseId = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.warehouseId))
        : null;
    final effectiveWarehouseName = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.warehouseName))
        : warehouseName;
    final effectiveUserId = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.userId))
        : null;
    final effectiveUserName = isEditing
        ? ref.watch(saleOrderFormProvider.select((s) => s.userName))
        : userName;
    final partnerPaymentTermIds = ref.watch(
      saleOrderFormProvider.select((s) => s.partnerPaymentTermIds),
    );

    final notifier = ref.read(saleOrderFormProvider.notifier);

    return OrderConfigCard(
      isCompact: isCompact,
      isEditing: isEditing,
      dateOrder: effectiveDateOrder,
      pricelistId: effectivePricelistId,
      pricelistName: effectivePricelistName,
      paymentTermId: effectivePaymentTermId,
      paymentTermName: effectivePaymentTermName,
      warehouseId: effectiveWarehouseId,
      warehouseName: effectiveWarehouseName,
      userId: effectiveUserId,
      userName: effectiveUserName,
      authorizedPaymentTermIds: partnerPaymentTermIds,
      onDateChanged: (date) => notifier.updateField('date_order', date),
      onPricelistChanged: (id) => notifier.updateField('pricelist_id', id),
      onPaymentTermChanged: (id) => notifier.updateField('payment_term_id', id),
      onWarehouseChanged: (id) => notifier.updateField('warehouse_id', id),
      onUserChanged: (id) => notifier.updateField('user_id', id),
    );
  }
}

// ============================================================================
// CAMPO DE REFERIDOR REACTIVO - Vista y Edición unificados
// ============================================================================

/// Campo de referidor reactivo para l10n_ec_sale_base
///
/// Soporta modo vista (muestra el nombre) y edición (botón de selección).
class ReactiveReferrerField extends ConsumerWidget {
  final bool isEditing;

  const ReactiveReferrerField({super.key, required this.isEditing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final referrerId = ref.watch(
      saleOrderFormProvider.select((s) => s.referrerId),
    );
    final referrerName = ref.watch(
      saleOrderFormProvider.select((s) => s.referrerName),
    );

    return Card(
      backgroundColor: Colors.purple.withValues(alpha: 0.05),
      borderColor: Colors.purple.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.people, size: 14, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Referidor',
                style: theme.typography.bodyStrong?.copyWith(
                  color: Colors.purple,
                ),
              ),
              if (isEditing) ...[
                const SizedBox(width: 8),
                Text(
                  '(obligatorio)',
                  style: theme.typography.caption?.copyWith(
                    color: Colors.purple.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (isEditing)
            Button(
              onPressed: () => _showSelectReferrerDialog(context, ref),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    referrerId != null
                        ? FluentIcons.contact
                        : FluentIcons.add_friend,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    referrerName ?? 'Seleccionar referidor...',
                    style: referrerId == null
                        ? theme.typography.body?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          )
                        : null,
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Icon(FluentIcons.contact, size: 14, color: Colors.purple),
                const SizedBox(width: 8),
                Text(referrerName ?? '-', style: theme.typography.body),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showSelectReferrerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const SelectClientDialog(),
    );

    if (result != null) {
      final referrerId = result['id'] as int;
      final referrerName = result['name'] as String;

      ref
          .read(saleOrderFormProvider.notifier)
          .updateField('referrer_id', referrerId);
      ref
          .read(saleOrderFormProvider.notifier)
          .updateField('referrer_name', referrerName);
    }
  }
}

// ============================================================================
// CAMPOS DE TIPO/CANAL CLIENTE REACTIVOS - Vista y Edición unificados
// ============================================================================

/// Campos de tipo y canal de cliente para l10n_ec_sale_base
///
/// Soporta modo vista (muestra los valores) y edición (selectores).
/// Usa [OdooSelectionField] para ambos modos.
class ReactiveCustomerTypeChannelFields extends ConsumerWidget {
  final bool isEditing;

  static final tipoClienteOptions = [
    SelectionOption(value: 'consumo', label: 'Consumo'),
    SelectionOption(value: 'corporativo', label: 'Corporativo'),
    SelectionOption(value: 'profesional', label: 'Profesional'),
    SelectionOption(value: 'gobierno', label: 'Gobierno'),
    SelectionOption(value: 'otro', label: 'Otro'),
  ];

  static final canalClienteOptions = [
    SelectionOption(value: 'local', label: 'Local'),
    SelectionOption(value: 'email', label: 'Email'),
    SelectionOption(value: 'whatsapp', label: 'WhatsApp'),
    SelectionOption(value: 'telefono', label: 'Teléfono'),
    SelectionOption(value: 'web', label: 'Web'),
    SelectionOption(value: 'otro', label: 'Otro'),
  ];

  const ReactiveCustomerTypeChannelFields({super.key, required this.isEditing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final tipoCliente = ref.watch(
      saleOrderFormProvider.select((s) => s.tipoCliente),
    );
    final canalCliente = ref.watch(
      saleOrderFormProvider.select((s) => s.canalCliente),
    );
    final notifier = ref.read(saleOrderFormProvider.notifier);

    return Card(
      backgroundColor: Colors.teal.withValues(alpha: 0.05),
      borderColor: Colors.teal.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.contact_list, size: 14, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Tipo y Canal de Cliente',
                style: theme.typography.bodyStrong?.copyWith(
                  color: Colors.teal,
                ),
              ),
              if (isEditing) ...[
                const SizedBox(width: 8),
                Text(
                  '(obligatorio)',
                  style: theme.typography.caption?.copyWith(
                    color: Colors.teal.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OdooSelectionField<String>(
                  config: ReactiveFieldConfig(
                    label: 'Tipo de Cliente',
                    isEditing: isEditing,
                    isRequired: true,
                  ),
                  value: tipoCliente,
                  options: tipoClienteOptions,
                  placeholder: 'Seleccionar...',
                  onChanged: (value) =>
                      notifier.updateField('tipo_cliente', value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OdooSelectionField<String>(
                  config: ReactiveFieldConfig(
                    label: 'Canal de Cliente',
                    isEditing: isEditing,
                    isRequired: true,
                  ),
                  value: canalCliente,
                  options: canalClienteOptions,
                  placeholder: 'Seleccionar...',
                  onChanged: (value) =>
                      notifier.updateField('canal_cliente', value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
