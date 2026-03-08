import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show Client;
import 'credit/credit_status_badge.dart';

/// Client card widget for displaying partner information
///
/// Shows client avatar, name, VAT, contact info, and credit status.
/// Supports selection mode, edit actions, and credit display.
///
/// Usage:
/// ```dart
/// ClientCard(
///   client: client,
///   onTap: () => selectClient(client),
///   showCreditStatus: true,
/// )
/// ```
class ClientCard extends StatelessWidget {
  final Client client;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool isSelected;
  final bool showCreditStatus;
  final bool showContactInfo;
  final bool compact;

  const ClientCard({
    super.key,
    required this.client,
    this.onTap,
    this.onEdit,
    this.isSelected = false,
    this.showCreditStatus = true,
    this.showContactInfo = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        padding: EdgeInsets.all(compact ? 8 : 12),
        backgroundColor: isSelected
            ? theme.accentColor.withAlpha(25)
            : theme.cardColor,
        borderColor: isSelected ? theme.accentColor : null,
        child: compact ? _buildCompactContent(theme) : _buildFullContent(theme),
      ),
    );
  }

  Widget _buildCompactContent(FluentThemeData theme) {
    return Row(
      children: [
        _buildAvatar(size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                client.name,
                style: theme.typography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (client.vat != null)
                Text(
                  client.vat!,
                  style: theme.typography.caption,
                  maxLines: 1,
                ),
            ],
          ),
        ),
        if (showCreditStatus && client.hasCreditLimit)
          CreditStatusBadge.fromClient(client, compact: true),
      ],
    );
  }

  Widget _buildFullContent(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header row with avatar and basic info
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: theme.typography.bodyStrong,
                  ),
                  if (client.vat != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'RUC: ${client.vat}',
                      style: theme.typography.caption,
                    ),
                  ],
                  if (client.isCompany) ...[
                    const SizedBox(height: 4),
                    _buildCompanyBadge(theme),
                  ],
                ],
              ),
            ),
            if (showCreditStatus && client.hasCreditLimit)
              CreditStatusBadge.fromClient(client),
            if (onEdit != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(FluentIcons.edit, size: 14),
                onPressed: onEdit,
              ),
            ],
          ],
        ),

        // Contact info
        if (showContactInfo && _hasContactInfo()) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildContactInfo(theme),
        ],
      ],
    );
  }

  Widget _buildAvatar({double size = 48}) {
    if (client.avatar128 != null && client.avatar128!.isNotEmpty) {
      try {
        final bytes = base64Decode(client.avatar128!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(size),
          ),
        );
      } catch (_) {
        return _buildDefaultAvatar(size);
      }
    }
    return _buildDefaultAvatar(size);
  }

  Widget _buildDefaultAvatar(double size) {
    final initials = _getInitials(client.name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getAvatarColor(client.name),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyBadge(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accentColor.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.org,
            size: 12,
            color: theme.accentColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Empresa',
            style: TextStyle(
              color: theme.accentColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(FluentThemeData theme) {
    return Column(
      children: [
        if (client.effectivePhone.isNotEmpty)
          _buildContactRow(
            FluentIcons.phone,
            client.effectivePhone,
            theme,
          ),
        if (client.effectiveEmail.isNotEmpty) ...[
          if (client.effectivePhone.isNotEmpty) const SizedBox(height: 4),
          _buildContactRow(
            FluentIcons.mail,
            client.effectiveEmail,
            theme,
          ),
        ],
        if (client.street != null) ...[
          if (client.effectivePhone.isNotEmpty ||
              client.effectiveEmail.isNotEmpty)
            const SizedBox(height: 4),
          _buildContactRow(
            FluentIcons.map_pin,
            client.street!,
            theme,
          ),
        ],
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String text, FluentThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.typography.caption?.color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.typography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool _hasContactInfo() {
    return client.effectivePhone.isNotEmpty ||
        client.effectiveEmail.isNotEmpty ||
        client.street != null;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
    ];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }
}
