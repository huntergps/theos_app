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
        return const Center(child: ProgressRing());
      },
    );
  }
}
