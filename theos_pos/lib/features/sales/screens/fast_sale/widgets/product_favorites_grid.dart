import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, CreditIssue, PartnerBank;

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/platform/global_notification_service.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../fast_sale_providers.dart';
import 'product_favorites_providers.dart';

// ============================================================================
// Widget principal: ProductFavoritesGrid
// ============================================================================

/// Panel de productos favoritos/frecuentes para la pantalla FastSale.
///
/// Muestra un grid compacto de los 20 productos más vendidos en los últimos
/// 30 días, con una barra de filtro horizontal por categorías.
///
/// Al tocar una tarjeta se agrega 1 unidad del producto a la orden activa.
/// Si la orden no es editable, las tarjetas se muestran deshabilitadas.
class ProductFavoritesGrid extends ConsumerWidget {
  const ProductFavoritesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(fastSaleCanEditProvider);
    final products = ref.watch(favoriteGridProductsProvider);
    final countsAsync = ref.watch(frequentProductCountsProvider);
    final isLoading = countsAsync.isLoading && products.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de filtro por categorías
        const _CategoryFilterBar(),

        // Divisor
        Divider(
          style: DividerThemeData(
            horizontalMargin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: FluentTheme.of(context)
                  .resources
                  .dividerStrokeColorDefault,
            ),
          ),
        ),

        // Grid de productos
        Expanded(
          child: isLoading
              ? const Center(child: ProgressRing())
              : products.isEmpty
                  ? const _EmptyProductsState()
                  : _ProductGrid(
                      products: products,
                      canEdit: canEdit,
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// Barra de filtro por categorías
// ============================================================================

class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(favoriteFilterCategoriesProvider);
    final selected = ref.watch(favoritesSelectedCategoryProvider);
    final theme = FluentTheme.of(context);

    // Altura minima 48px para cumplir el estandar de touch target accesible
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: 4,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: Spacing.xs),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isActive = selected == cat;
          return _CategoryChip(
            label: cat.name,
            isActive: isActive,
            theme: theme,
            onTap: () => ref
                .read(favoritesSelectedCategoryProvider.notifier)
                .select(cat),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final FluentThemeData theme;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryBackground
              : theme.resources.cardBackgroundFillColorDefault,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.primaryBackground
                : theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: isActive
                ? Colors.white
                : null,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ============================================================================
// Grid de productos
// ============================================================================

class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  final bool canEdit;

  const _ProductGrid({
    required this.products,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200 ? 4 : (width > 600 ? 3 : 2);

    return GridView.builder(
      padding: const EdgeInsets.all(Spacing.xs),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: Spacing.xs,
        crossAxisSpacing: Spacing.xs,
        childAspectRatio: 1.55,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(
          product: product,
          canEdit: canEdit,
          onTap: canEdit
              ? () => _addProduct(context, ref, product)
              : null,
        );
      },
    );
  }

  void _addProduct(BuildContext context, WidgetRef ref, Product product) {
    ref.read(fastSaleProvider.notifier).addProduct(
          productId: product.id,
          productName: product.name,
          productCode: product.defaultCode,
          quantity: 1.0,
          uomId: product.uomId,
          uomName: product.uomName,
          priceUnit: product.listPrice,
          taxIds:
              product.taxIdsList.isNotEmpty ? product.taxIdsList : null,
        );

    // Feedback breve para confirmar que el producto fue agregado y
    // evitar que el cajero toque dos veces y duplique líneas.
    final displayName = product.defaultCode != null && product.defaultCode!.isNotEmpty
        ? '[${product.defaultCode}] ${product.name}'
        : product.name;
    ref
        .read(globalNotificationProvider)
        .showSuccess(
          context,
          title: 'Agregado',
          message: displayName,
          durationSeconds: 1,
        );
  }
}

// ============================================================================
// Tarjeta individual de producto
// ============================================================================

class _ProductCard extends StatefulWidget {
  final Product product;
  final bool canEdit;
  final VoidCallback? onTap;

  const _ProductCard({
    required this.product,
    required this.canEdit,
    this.onTap,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final product = widget.product;
    final accent = _categoryAccentColor(product.categId);

    final bgColor = _isPressed
        ? accent.withValues(alpha: 0.18)
        : _isHovered
            ? accent.withValues(alpha: 0.09)
            : theme.resources.cardBackgroundFillColorDefault;

    final borderColor = _isHovered || _isPressed
        ? accent.withValues(alpha: 0.5)
        : theme.resources.dividerStrokeColorDefault;

    return Semantics(
      label:
          '${product.name}, ${product.listPrice.toCurrency()}. Toque para agregar.',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _isPressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _isPressed = false)
            : null,
        child: MouseRegion(
          cursor: widget.canEdit
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() {
            _isHovered = false;
            _isPressed = false;
          }),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  left: BorderSide(color: accent, width: 3),
                  top: BorderSide(color: borderColor),
                  right: BorderSide(color: borderColor),
                  bottom: BorderSide(color: borderColor),
                ),
              ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sm,
                Spacing.xs,
                Spacing.xs,
                Spacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nombre del producto (2 líneas máximo)
                  //
                  // Tamaño subido de 11 a 12px para mejorar legibilidad en
                  // el grid táctil. Se retiró el código interno (que se
                  // mostraba en 9px debajo del precio): en un grid de
                  // "favoritos/frecuentes" pensado para toque rápido, el
                  // cajero reconoce el producto por nombre, no por código
                  // — mantenerlo solo apretaba las 3 líneas en una tarjeta
                  // de 48px de alto. El código sigue disponible en las
                  // pantallas de búsqueda/líneas de orden donde sí importa
                  // para desambiguar variantes.
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Precio de venta
                  Text(
                    product.listPrice.toCurrency(),
                    style: theme.typography.caption?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// Color de acento determinista según el ID de categoría.
  ///
  /// Usa una paleta de 8 colores coherente con el sistema de diseño
  /// (no colores aleatorios que cambiarían entre sesiones).
  static Color _categoryAccentColor(int? categId) {
    if (categId == null) return AppColors.primaryBackground;
    final palette = AppColors.favoriteCardPalette;
    return palette[categId % palette.length];
  }
}

// ============================================================================
// Estado vacío
// ============================================================================

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.product_variant,
            size: 48,
            color: theme.inactiveColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Sin productos disponibles',
            style: theme.typography.body?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Sincronice el catálogo de productos',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
