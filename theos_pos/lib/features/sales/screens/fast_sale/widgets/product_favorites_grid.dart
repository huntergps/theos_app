import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, CreditIssue, PartnerBank;

import '../../../../../core/constants/app_colors.dart';
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
        _CategoryFilterBar(),

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
                  ? _EmptyProductsState()
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
              ? () => _addProduct(ref, product)
              : null,
        );
      },
    );
  }

  void _addProduct(WidgetRef ref, Product product) {
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(5),
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
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
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
                  // Código interno (si disponible, en letra pequeña)
                  if (product.hasDefaultCode)
                    Text(
                      product.defaultCode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption?.copyWith(
                        color: theme.inactiveColor.withValues(alpha: 0.6),
                        fontSize: 9,
                      ),
                    ),
                ],
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
    const palette = [
      Color(0xFF00A09D), // teal primario
      Color(0xFF0078D4), // azul Fluent
      Color(0xFF107C10), // verde
      Color(0xFF8764B8), // púrpura
      Color(0xFFCA5010), // naranja
      Color(0xFF038387), // cyan
      Color(0xFFB4009E), // magenta
      Color(0xFF004E8C), // azul marino
    ];
    return palette[categId % palette.length];
  }
}

// ============================================================================
// Estado vacío
// ============================================================================

class _EmptyProductsState extends StatelessWidget {
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
