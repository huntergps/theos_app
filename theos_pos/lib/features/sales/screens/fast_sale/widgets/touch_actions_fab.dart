import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/theme/spacing.dart';
import '../fast_sale_providers.dart';

/// Notifier que controla si el FAB táctil está expandido
class _TouchFabExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void collapse() => state = false;
}

/// Provider que controla si el FAB táctil está expandido
final _touchFabExpandedProvider =
    NotifierProvider<_TouchFabExpandedNotifier, bool>(
  _TouchFabExpandedNotifier.new,
);

/// Provider que detecta si hay teclado físico conectado
///
/// Retorna `true` si se detecta un dispositivo de entrada físico (teclado),
/// lo que indica que el usuario no necesita el FAB táctil.
///
/// Estrategia de detección:
/// - En desktop (Windows/Linux/macOS) siempre hay teclado → false
/// - En mobile/tablet: se asume touch-only a menos que haya hardware conectado
/// El estado se inicializa una vez por sesión y no cambia en caliente,
/// ya que HardwareKeyboard.instance no expone un stream de conexión/desconexión.
final hasPhysicalKeyboardProvider = Provider<bool>((ref) {
  // En la práctica, detectar teclado físico en Flutter es indirecto.
  // defaultTargetPlatform nos dice la plataforma de compilación, pero
  // un tablet Android puede o no tener teclado bluetooth.
  //
  // La mejor heurística disponible sin plugins externos:
  // - Verificar si hay teclas actualmente presionadas (indica hardware real)
  // - Como proxy confiable: plataformas desktop siempre tienen teclado
  final platform = defaultTargetPlatform;
  final isDesktopPlatform = platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux ||
      platform == TargetPlatform.macOS;

  if (isDesktopPlatform) return true;

  // Para Android/iOS: verificar si el HardwareKeyboard tiene claves conocidas
  // (bluetooth keyboard conectado activo). Esta detección es imperfecta pero
  // es el mejor proxy disponible sin flutter_keyboard_visibility o similar.
  // Se considera que hay teclado si existen teclas físicas presionadas ahora.
  return HardwareKeyboard.instance.physicalKeysPressed.isNotEmpty;
});

/// Barra de acciones táctiles flotante para tablet y móvil sin teclado físico
///
/// Aparece como un FAB circular en la esquina inferior derecha que al pulsarse
/// expande un menú vertical con las acciones críticas de la pantalla FastSale:
///
/// - Buscar producto (equivale a F2)
/// - Nueva orden     (equivale a F4)
/// - Buscar cliente  (equivale a F3)
/// - Confirmar orden (equivale a F9)
/// - Cobrar          (equivale a F8 / ir a pagos)
///
/// El FAB es semi-transparente cuando está cerrado para no bloquear contenido.
/// Solo se muestra en dispositivos sin teclado físico (tablet/móvil touch).
///
/// Uso:
/// ```dart
/// Stack(
///   children: [
///     mainContent,
///     const TouchActionsFab(),
///   ],
/// )
/// ```
class TouchActionsFab extends ConsumerStatefulWidget {
  const TouchActionsFab({super.key});

  @override
  ConsumerState<TouchActionsFab> createState() => _TouchActionsFabState();
}

class _TouchActionsFabState extends ConsumerState<TouchActionsFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final isExpanded = ref.read(_touchFabExpandedProvider);
    ref.read(_touchFabExpandedProvider.notifier).toggle();
    if (!isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _collapse() {
    ref.read(_touchFabExpandedProvider.notifier).collapse();
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(_touchFabExpandedProvider);
    final theme = FluentTheme.of(context);

    return Positioned(
      right: Spacing.md,
      bottom: Spacing.md,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Acciones expandidas — aparecen de abajo a arriba
          AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: _expandAnimation.value,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _buildActionItems(theme),
            ),
          ),

          // Botón principal del FAB
          _FabMainButton(
            isExpanded: isExpanded,
            onTap: _toggle,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItems(FluentThemeData theme) {
    final notifier = ref.read(fastSaleProvider.notifier);
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final order = activeTab?.order;

    // Determinar qué acciones están disponibles
    final hasLines = activeTab != null && activeTab.lines.isNotEmpty;
    final hasPartner = order?.partnerId != null;
    final hasInvoice =
        order?.hasQueuedInvoice == true || order?.isFullyInvoiced == true;
    final canConfirm =
        order != null && order.canConfirm && hasLines && hasPartner && !hasInvoice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Cobrar — solo si hay orden confirmada (o tiene líneas)
        if (hasLines)
          _FabActionItem(
            icon: FluentIcons.payment_card,
            label: 'Cobrar',
            color: AppColors.success,
            onTap: () {
              _collapse();
              ref.read(orderPanelTabProvider.notifier).goToPayments();
            },
          ),

        const SizedBox(height: Spacing.xs),

        // Confirmar orden
        if (canConfirm)
          _FabActionItem(
            icon: FluentIcons.check_mark,
            label: 'Confirmar',
            color: AppColors.successBackground,
            onTap: () {
              _collapse();
              notifier.confirmActiveOrder();
            },
          ),

        if (canConfirm) const SizedBox(height: Spacing.xs),

        // Buscar cliente
        _FabActionItem(
          icon: FluentIcons.contact,
          label: 'Cliente',
          color: AppColors.primaryBackground,
          onTap: () {
            _collapse();
            notifier.toggleCustomerPanel();
          },
        ),

        const SizedBox(height: Spacing.xs),

        // Buscar producto
        _FabActionItem(
          icon: FluentIcons.search,
          label: 'Buscar',
          color: AppColors.primaryBackground,
          onTap: () {
            _collapse();
            notifier.setInputMode(KeypadInputMode.search);
            requestSearchInputFocus();
          },
        ),

        const SizedBox(height: Spacing.xs),

        // Nueva orden
        _FabActionItem(
          icon: FluentIcons.add,
          label: 'Nueva',
          color: theme.accentColor,
          onTap: () {
            _collapse();
            notifier.addNewTab();
          },
        ),

        const SizedBox(height: Spacing.xs),
      ],
    );
  }
}

/// Botón principal del FAB (ícono hamburguesa/X)
class _FabMainButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _FabMainButton({
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isExpanded
              ? AppColors.primaryBackground
              : AppColors.primaryBackground.withAlpha(204), // ~80% opacidad
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            isExpanded ? FluentIcons.chrome_close : FluentIcons.more,
            key: ValueKey(isExpanded),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Item de acción individual del FAB expandido
///
/// Muestra una píldora con ícono + label + fondo de color.
/// Tamaño de touch target: mínimo 48px de alto para uso táctil.
class _FabActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FabActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.ms,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withAlpha(230), // ~90% opacidad
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: Spacing.xs),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
