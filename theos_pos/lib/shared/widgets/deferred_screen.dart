import 'package:fluent_ui/fluent_ui.dart';

class DeferredScreen extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;

  const DeferredScreen({
    super.key,
    required this.loader,
    required this.builder,
  });

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.error, size: 48),
                  const SizedBox(height: 16),
                  Text('Error cargando módulo: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() {
                      _future = widget.loader();
                    }),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          return widget.builder();
        }
        return const _ShimmerLoadingPlaceholder();
      },
    );
  }
}

/// Shimmer-style loading placeholder for deferred screens
class _ShimmerLoadingPlaceholder extends StatefulWidget {
  const _ShimmerLoadingPlaceholder();

  @override
  State<_ShimmerLoadingPlaceholder> createState() =>
      _ShimmerLoadingPlaceholderState();
}

class _ShimmerLoadingPlaceholderState extends State<_ShimmerLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerValue = _controller.value;
        final color = Color.lerp(
          baseColor,
          highlightColor,
          (0.5 + 0.5 * (shimmerValue * 2 - 1).abs()).clamp(0.0, 1.0),
        )!;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header placeholder
              _shimmerBox(color, width: 200, height: 28),
              const SizedBox(height: 20),
              // Toolbar placeholder
              Row(
                children: [
                  _shimmerBox(color, width: 100, height: 32),
                  const SizedBox(width: 8),
                  _shimmerBox(color, width: 100, height: 32),
                  const Spacer(),
                  _shimmerBox(color, width: 80, height: 32),
                ],
              ),
              const SizedBox(height: 20),
              // Content rows placeholder
              for (int i = 0; i < 6; i++) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _shimmerBox(color, height: 16),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _shimmerBox(color, height: 16),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _shimmerBox(color, height: 16)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(Color color, {double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
