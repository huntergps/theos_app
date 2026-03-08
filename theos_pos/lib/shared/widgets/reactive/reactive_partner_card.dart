import 'dart:convert';
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'reactive_field_base.dart';

/// Partner information for ReactivePartnerCard
class PartnerInfo {
  final int? id;
  final String? name;
  final String? vat;
  final String? street;
  final String? phone;
  final String? email;
  final String? avatar;
  final bool isFinalConsumer;
  final String? endCustomerName;
  final String? endCustomerPhone;
  final String? endCustomerEmail;
  final int? referrerId;
  final String? referrerName;

  const PartnerInfo({
    this.id,
    this.name,
    this.vat,
    this.street,
    this.phone,
    this.email,
    this.avatar,
    this.isFinalConsumer = false,
    this.endCustomerName,
    this.endCustomerPhone,
    this.endCustomerEmail,
    this.referrerId,
    this.referrerName,
  });

  PartnerInfo copyWith({
    int? id,
    String? name,
    String? vat,
    String? street,
    String? phone,
    String? email,
    String? avatar,
    bool? isFinalConsumer,
    String? endCustomerName,
    String? endCustomerPhone,
    String? endCustomerEmail,
    int? referrerId,
    String? referrerName,
  }) {
    return PartnerInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      vat: vat ?? this.vat,
      street: street ?? this.street,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      isFinalConsumer: isFinalConsumer ?? this.isFinalConsumer,
      endCustomerName: endCustomerName ?? this.endCustomerName,
      endCustomerPhone: endCustomerPhone ?? this.endCustomerPhone,
      endCustomerEmail: endCustomerEmail ?? this.endCustomerEmail,
      referrerId: referrerId ?? this.referrerId,
      referrerName: referrerName ?? this.referrerName,
    );
  }

  /// Get effective phone (end customer if final consumer, otherwise partner)
  String? get effectivePhone => isFinalConsumer ? endCustomerPhone : phone;

  /// Get effective email (end customer if final consumer, otherwise partner)
  String? get effectiveEmail => isFinalConsumer ? endCustomerEmail : email;
}

/// Callbacks for ReactivePartnerCard
class PartnerCardCallbacks {
  /// Called when user wants to select a different partner
  final VoidCallback? onSelectPartner;

  /// Called when user wants to create a new partner
  final VoidCallback? onCreatePartner;

  /// Called when partner phone changes (inline edit)
  final ValueChanged<String>? onPhoneChanged;

  /// Called when partner email changes (inline edit)
  final ValueChanged<String>? onEmailChanged;

  /// Called when end customer name changes
  final ValueChanged<String>? onEndCustomerNameChanged;

  /// Called when end customer phone changes
  final ValueChanged<String>? onEndCustomerPhoneChanged;

  /// Called when end customer email changes
  final ValueChanged<String>? onEndCustomerEmailChanged;

  /// Called when user wants to select a referrer
  final VoidCallback? onSelectReferrer;

  const PartnerCardCallbacks({
    this.onSelectPartner,
    this.onCreatePartner,
    this.onPhoneChanged,
    this.onEmailChanged,
    this.onEndCustomerNameChanged,
    this.onEndCustomerPhoneChanged,
    this.onEndCustomerEmailChanged,
    this.onSelectReferrer,
  });
}

/// A reactive partner card that handles:
/// - Normal partner display (name, vat, address, phone, email)
/// - Final consumer mode (additional fields for end customer)
/// - Inline editing of phone/email
/// - Partner selection via search dialog
///
/// Usage:
/// ```dart
/// ReactivePartnerCard(
///   config: ReactiveFieldConfig(isEditing: isEditMode),
///   partner: PartnerInfo(
///     id: partnerId,
///     name: partnerName,
///     vat: partnerVat,
///     // ... other fields
///   ),
///   callbacks: PartnerCardCallbacks(
///     onSelectPartner: () => _showSelectPartnerDialog(),
///     onPhoneChanged: (phone) => notifier.updatePartnerPhone(phone),
///     // ... other callbacks
///   ),
///   endCustomerFieldsRequired: exceedsFinalConsumerLimit,
/// )
/// ```
class ReactivePartnerCard extends ConsumerStatefulWidget {
  /// Field configuration (isEditing, isCompact, etc.)
  final ReactiveFieldConfig config;

  /// Partner information
  final PartnerInfo partner;

  /// Callbacks for user interactions
  final PartnerCardCallbacks callbacks;

  /// Whether end customer fields are required (for final consumer validation)
  final bool endCustomerFieldsRequired;

  /// Override compact mode (useful when keyboard is visible)
  final bool isCompact;

  const ReactivePartnerCard({
    super.key,
    required this.config,
    required this.partner,
    required this.callbacks,
    this.endCustomerFieldsRequired = false,
    this.isCompact = false,
  });

  @override
  ConsumerState<ReactivePartnerCard> createState() =>
      _ReactivePartnerCardState();
}

class _ReactivePartnerCardState extends ConsumerState<ReactivePartnerCard> {
  /// Cached decoded avatar bytes to avoid re-decoding on every rebuild
  Uint8List? _cachedAvatarBytes;
  String? _cachedAvatarString;
  bool _cachedIsSvg = false;

  @override
  void didUpdateWidget(ReactivePartnerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-decode if avatar string actually changed
    if (widget.partner.avatar != oldWidget.partner.avatar) {
      _cachedAvatarBytes = null;
      _cachedAvatarString = null;
      _cachedIsSvg = false;
    }
  }

  /// Check if bytes represent an SVG image
  bool _isSvgBytes(Uint8List bytes) {
    if (bytes.length < 5) return false;
    // Check for SVG signatures: "<svg" or "<?xml"
    final header = String.fromCharCodes(bytes.take(100));
    return header.contains('<svg') || header.contains('<?xml');
  }

  Uint8List? _getAvatarBytes() {
    final avatar = widget.partner.avatar;
    if (avatar == null || avatar.isEmpty) return null;

    // Return cached bytes if avatar string hasn't changed
    if (_cachedAvatarString == avatar && _cachedAvatarBytes != null) {
      return _cachedAvatarBytes;
    }

    // Decode and cache
    try {
      _cachedAvatarBytes = base64Decode(avatar);
      _cachedAvatarString = avatar;
      _cachedIsSvg = _isSvgBytes(_cachedAvatarBytes!);
      return _cachedAvatarBytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);

    final avatarBytes = _getAvatarBytes();
    final hasAvatar = avatarBytes != null;
    final showLargeAvatar =
        hasAvatar && !(widget.isCompact || widget.config.isCompact);

    Widget buildAvatar() {
      if (avatarBytes == null) return const SizedBox.shrink();

      // Use SvgPicture for SVG images (Odoo placeholder), MemoryImage for raster
      if (_cachedIsSvg) {
        return Container(
          width: 100,
          height: 100,
          margin: EdgeInsets.only(right: spacing.ms),
          decoration: BoxDecoration(
            color: theme.resources.controlFillColorSecondary,
            border:
                Border.all(color: theme.resources.surfaceStrokeColorDefault),
          ),
          child: ClipRRect(
            child: SvgPicture.memory(
              avatarBytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      return Container(
        width: 100,
        height: 100,
        margin: EdgeInsets.only(right: spacing.ms),
        decoration: BoxDecoration(
          color: theme.resources.controlFillColorSecondary,
          border: Border.all(color: theme.resources.surfaceStrokeColorDefault),
          image: DecorationImage(
            image: MemoryImage(avatarBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Card(
      padding: EdgeInsets.all(spacing.ms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large Avatar on the left
          if (showLargeAvatar) buildAvatar(),

          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Partner name with select/create buttons
                _PartnerNameRow(
                  name: widget.partner.name,
                  isEditing: widget.config.isEditing,
                  onSelect: widget.callbacks.onSelectPartner,
                  onCreate: widget.callbacks.onCreatePartner,
                ),

                // In compact mode, only show name row
                if (!(widget.isCompact || widget.config.isCompact)) ...[
                  // Row 2: End customer name (only for final consumer)
                  if (widget.partner.isFinalConsumer) ...[
                    SizedBox(height: spacing.xs),
                    _EndCustomerNameRow(
                      name: widget.partner.endCustomerName,
                      isEditing: widget.config.isEditing,
                      isRequired: widget.endCustomerFieldsRequired,
                      onChanged: widget.callbacks.onEndCustomerNameChanged,
                    ),
                  ],

                  // Row 3: VAT (RUC/Cédula)
                  SizedBox(height: spacing.xs),
                  _InfoRow(
                    icon: FluentIcons.permissions,
                    value: widget.partner.vat,
                    theme: theme,
                  ),

                  // Row 4: Street/Address
                  SizedBox(height: spacing.xs),
                  _InfoRow(
                    icon: FluentIcons.map_pin,
                    value: widget.partner.street,
                    theme: theme,
                  ),

                  // Row 5: Phone (with inline edit)
                  SizedBox(height: spacing.xs),
                  _PhoneRow(
                    phone: widget.partner.effectivePhone,
                    isEditing: widget.config.isEditing,
                    isFinalConsumer: widget.partner.isFinalConsumer,
                    isRequired:
                        widget.partner.isFinalConsumer &&
                        widget.endCustomerFieldsRequired,
                    onChanged: widget.partner.isFinalConsumer
                        ? widget.callbacks.onEndCustomerPhoneChanged
                        : widget.callbacks.onPhoneChanged,
                  ),

                  // Row 6: Email (with inline edit)
                  SizedBox(height: spacing.xs),
                  _EmailRow(
                    email: widget.partner.effectiveEmail,
                    isEditing: widget.config.isEditing,
                    isFinalConsumer: widget.partner.isFinalConsumer,
                    isRequired:
                        widget.partner.isFinalConsumer &&
                        widget.endCustomerFieldsRequired,
                    onChanged: widget.partner.isFinalConsumer
                        ? widget.callbacks.onEndCustomerEmailChanged
                        : widget.callbacks.onEmailChanged,
                  ),

                  // Row 7: Referrer (displayed always, editable button when editing)
                  if (widget.partner.referrerId != null ||
                      widget.config.isEditing) ...[
                    SizedBox(height: spacing.xs),
                    _ReferrerRow(
                      referrerName: widget.partner.referrerName,
                      isEditing: widget.config.isEditing,
                      onSelect: widget.callbacks.onSelectReferrer,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Partner name row with select/create buttons
class _PartnerNameRow extends StatelessWidget {
  final String? name;
  final bool isEditing;
  final VoidCallback? onSelect;
  final VoidCallback? onCreate;

  const _PartnerNameRow({
    required this.name,
    required this.isEditing,
    this.onSelect,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isEmpty = name == null || name!.isEmpty;

    return Row(
      children: [
        Icon(
          FluentIcons.contact,
          size: 16,
          color: isEmpty ? theme.inactiveColor : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isEmpty ? 'Sin cliente' : name!,
            style: theme.typography.body?.copyWith(
              fontWeight: FontWeight.w600,
              color: isEmpty ? theme.inactiveColor : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isEditing) ...[
          IconButton(
            icon: const Icon(FluentIcons.search, size: 14),
            onPressed: onSelect,
          ),
          if (onCreate != null)
            IconButton(
              icon: const Icon(FluentIcons.add, size: 14),
              onPressed: onCreate,
            ),
        ],
      ],
    );
  }
}

/// End customer name row (for final consumer)
class _EndCustomerNameRow extends StatefulWidget {
  final String? name;
  final bool isEditing;
  final bool isRequired;
  final ValueChanged<String>? onChanged;

  const _EndCustomerNameRow({
    required this.name,
    required this.isEditing,
    required this.isRequired,
    this.onChanged,
  });

  @override
  State<_EndCustomerNameRow> createState() => _EndCustomerNameRowState();
}

class _EndCustomerNameRowState extends State<_EndCustomerNameRow> {
  late TextEditingController _controller;
  bool _isUserEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name ?? '');
  }

  @override
  void didUpdateWidget(_EndCustomerNameRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller text if not actively editing and value changed externally
    if (widget.name != oldWidget.name && !_isUserEditing) {
      _controller.text = widget.name ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _isUserEditing = true;
    widget.onChanged?.call(value);
    // Reset editing flag after a short delay to allow for external updates
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _isUserEditing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (widget.isEditing && widget.onChanged != null) {
      return Row(
        children: [
          const Icon(FluentIcons.contact_info, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _controller,
              placeholder: widget.isRequired
                  ? 'Nombre cliente final *'
                  : 'Nombre cliente final',
              onChanged: _onTextChanged,
            ),
          ),
        ],
      );
    }

    return _InfoRow(
      icon: FluentIcons.contact_info,
      label: 'Cliente:',
      value: widget.name,
      theme: theme,
    );
  }
}

/// Static info row (icon + optional label + value)
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? value;
  final FluentThemeData theme;

  const _InfoRow({
    required this.icon,
    this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: isEmpty ? theme.inactiveColor : null),
        const SizedBox(width: 8),
        if (label != null) ...[
          Text(
            label!,
            style: theme.typography.body?.copyWith(color: theme.inactiveColor),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            isEmpty ? '-' : value!,
            style: theme.typography.body?.copyWith(
              color: isEmpty ? theme.inactiveColor : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone row with inline editing support
class _PhoneRow extends StatefulWidget {
  final String? phone;
  final bool isEditing;
  final bool isFinalConsumer;
  final bool isRequired;
  final ValueChanged<String>? onChanged;

  const _PhoneRow({
    required this.phone,
    required this.isEditing,
    required this.isFinalConsumer,
    required this.isRequired,
    this.onChanged,
  });

  @override
  State<_PhoneRow> createState() => _PhoneRowState();
}

class _PhoneRowState extends State<_PhoneRow> {
  bool _isInlineEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.phone ?? '');
  }

  @override
  void didUpdateWidget(_PhoneRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phone != oldWidget.phone && !_isInlineEditing) {
      _controller.text = widget.phone ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isInlineEditing = true);
  }

  void _saveAndClose() {
    widget.onChanged?.call(_controller.text.trim());
    setState(() => _isInlineEditing = false);
  }

  void _cancel() {
    _controller.text = widget.phone ?? '';
    setState(() => _isInlineEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final label = widget.isFinalConsumer ? 'Teléfono cliente' : 'Teléfono';

    if (_isInlineEditing) {
      return Row(
        children: [
          const Icon(FluentIcons.phone, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _controller,
              placeholder: widget.isRequired ? '$label *' : label,
              autofocus: true,
              onSubmitted: (_) => _saveAndClose(),
            ),
          ),
          IconButton(
            icon: Icon(FluentIcons.check_mark, size: 14, color: Colors.green),
            onPressed: _saveAndClose,
          ),
          IconButton(
            icon: Icon(FluentIcons.cancel, size: 14, color: Colors.red),
            onPressed: _cancel,
          ),
        ],
      );
    }

    final isEmpty = widget.phone == null || widget.phone!.isEmpty;

    return GestureDetector(
      onTap: widget.isEditing && widget.onChanged != null
          ? _startEditing
          : null,
      child: MouseRegion(
        cursor: widget.isEditing && widget.onChanged != null
            ? SystemMouseCursors.text
            : SystemMouseCursors.basic,
        child: Row(
          children: [
            Icon(
              FluentIcons.phone,
              size: 14,
              color: isEmpty ? theme.inactiveColor : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEmpty ? '-' : widget.phone!,
                style: theme.typography.body?.copyWith(
                  color: isEmpty ? theme.inactiveColor : null,
                ),
              ),
            ),
            if (widget.isEditing && widget.onChanged != null)
              Icon(FluentIcons.edit, size: 12, color: theme.inactiveColor),
          ],
        ),
      ),
    );
  }
}

/// Email row with inline editing support
class _EmailRow extends StatefulWidget {
  final String? email;
  final bool isEditing;
  final bool isFinalConsumer;
  final bool isRequired;
  final ValueChanged<String>? onChanged;

  const _EmailRow({
    required this.email,
    required this.isEditing,
    required this.isFinalConsumer,
    required this.isRequired,
    this.onChanged,
  });

  @override
  State<_EmailRow> createState() => _EmailRowState();
}

class _EmailRowState extends State<_EmailRow> {
  bool _isInlineEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.email ?? '');
  }

  @override
  void didUpdateWidget(_EmailRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email != oldWidget.email && !_isInlineEditing) {
      _controller.text = widget.email ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isInlineEditing = true);
  }

  void _saveAndClose() {
    widget.onChanged?.call(_controller.text.trim());
    setState(() => _isInlineEditing = false);
  }

  void _cancel() {
    _controller.text = widget.email ?? '';
    setState(() => _isInlineEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final label = widget.isFinalConsumer ? 'Email cliente' : 'Email';

    if (_isInlineEditing) {
      return Row(
        children: [
          const Icon(FluentIcons.mail, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _controller,
              placeholder: widget.isRequired ? '$label *' : label,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _saveAndClose(),
            ),
          ),
          IconButton(
            icon: Icon(FluentIcons.check_mark, size: 14, color: Colors.green),
            onPressed: _saveAndClose,
          ),
          IconButton(
            icon: Icon(FluentIcons.cancel, size: 14, color: Colors.red),
            onPressed: _cancel,
          ),
        ],
      );
    }

    final isEmpty = widget.email == null || widget.email!.isEmpty;

    return GestureDetector(
      onTap: widget.isEditing && widget.onChanged != null
          ? _startEditing
          : null,
      child: MouseRegion(
        cursor: widget.isEditing && widget.onChanged != null
            ? SystemMouseCursors.text
            : SystemMouseCursors.basic,
        child: Row(
          children: [
            Icon(
              FluentIcons.mail,
              size: 14,
              color: isEmpty ? theme.inactiveColor : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEmpty ? '-' : widget.email!,
                style: theme.typography.body?.copyWith(
                  color: isEmpty ? theme.inactiveColor : null,
                ),
              ),
            ),
            if (widget.isEditing && widget.onChanged != null)
              Icon(FluentIcons.edit, size: 12, color: theme.inactiveColor),
          ],
        ),
      ),
    );
  }
}

/// Referrer row with select button
class _ReferrerRow extends StatelessWidget {
  final String? referrerName;
  final bool isEditing;
  final VoidCallback? onSelect;

  const _ReferrerRow({
    required this.referrerName,
    required this.isEditing,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isEmpty = referrerName == null || referrerName!.isEmpty;

    if (isEditing && onSelect != null) {
      return GestureDetector(
        onTap: onSelect,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.people, size: 14, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEmpty ? 'Seleccionar referidor...' : referrerName!,
                    style: theme.typography.body?.copyWith(
                      color: isEmpty ? theme.inactiveColor : Colors.purple,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(FluentIcons.chevron_right, size: 12, color: Colors.purple),
              ],
            ),
          ),
        ),
      );
    }

    // View mode: simple row
    return Row(
      children: [
        Icon(
          FluentIcons.people,
          size: 14,
          color: isEmpty ? theme.inactiveColor : Colors.purple,
        ),
        const SizedBox(width: 8),
        Text(
          'Referidor: ',
          style: theme.typography.body?.copyWith(color: theme.inactiveColor),
        ),
        Expanded(
          child: Text(
            isEmpty ? '-' : referrerName!,
            style: theme.typography.body?.copyWith(
              color: isEmpty ? theme.inactiveColor : Colors.purple,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A simplified partner info row (for lists, grids, etc.)
class ReactivePartnerInfoRow extends ConsumerWidget {
  final PartnerInfo partner;
  final bool showVat;
  final bool showPhone;
  final VoidCallback? onTap;

  const ReactivePartnerInfoRow({
    super.key,
    required this.partner,
    this.showVat = true,
    this.showPhone = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final isEmpty = partner.name == null || partner.name!.isEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            FluentIcons.contact,
            size: 14,
            color: isEmpty ? theme.inactiveColor : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEmpty ? '-' : partner.name!,
                  style: theme.typography.body,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showVat && partner.vat != null)
                  Text(
                    partner.vat!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
                if (showPhone && partner.effectivePhone != null)
                  Text(
                    partner.effectivePhone!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
          if (partner.isFinalConsumer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CF',
                style: theme.typography.caption?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
