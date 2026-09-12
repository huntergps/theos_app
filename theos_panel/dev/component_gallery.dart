import 'package:fluent_ui/fluent_ui.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/components/orbi_components.dart';
import 'package:theos_panel/ui/layouts/orbi_adaptive_layout.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  late final FormControl<String> _reactiveSearchControl;

  @override
  void initState() {
    super.initState();
    _reactiveSearchControl = FormControl<String>(value: 'Cliente ficticio');
  }

  @override
  void dispose() {
    _reactiveSearchControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPageShell(
      title: 'Galería Orbi ERP',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Logo de Orbi ERP',
              image: true,
              child: SvgPicture.asset(
                'assets/images/orbi_logo.svg',
                width: 220,
                height: 72,
                colorFilter: ColorFilter.mode(
                  FluentTheme.of(context).typography.body?.color ??
                      const Color(0xFF000000),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: OrbiTheme.space24),
            OrbiAdaptiveLayout(
              compact: _content(context, OrbiLayoutSize.compact),
              medium: _content(context, OrbiLayoutSize.medium),
              wide: _content(context, OrbiLayoutSize.wide),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, OrbiLayoutSize size) {
    final children = <Widget>[
      OrbiActionCard(
        title: 'Órdenes pendientes',
        subtitle: '12 por revisar · dato ficticio',
        onPressed: () {},
      ),
      OrbiStatusChip(
        label: 'Offline · cola pendiente',
        icon: FluentIcons.cloud_weather,
      ),
      OrbiReactiveTextField(
        control: _reactiveSearchControl,
        label: 'Buscar cliente',
      ),
      const OrbiEmptyState(
        title: 'Sin resultados',
        message: 'Prueba con otro nombre o limpia el filtro.',
      ),
      OrbiErrorState(message: 'No se pudo cargar el catálogo.', onRetry: () {}),
    ];
    if (size == OrbiLayoutSize.wide) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: OrbiTheme.space16,
        mainAxisSpacing: OrbiTheme.space16,
        childAspectRatio: 2.2,
        children: children,
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: OrbiTheme.space16),
      itemBuilder: (context, index) => children[index],
    );
  }
}

void main() => runApp(const _GalleryApp());

class _GalleryApp extends StatelessWidget {
  const _GalleryApp();

  @override
  Widget build(BuildContext context) =>
      FluentApp(theme: OrbiFluentTheme.light, home: const ComponentGallery());
}
