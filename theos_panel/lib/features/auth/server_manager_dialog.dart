import 'dart:async';
import 'dart:math' show Random;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

import '../../app/theme/orbi_theme.dart';
import 'saved_servers.dart';

/// Looks up the databases a bare Odoo server offers, before login.
///
/// Exists only so tests can substitute a fake without touching the network.
/// The real implementation ([OdooServerDatabaseDiscovery]) forwards to
/// odoo_sdk's [OdooDatabaseDiscovery], which throws
/// [DatabaseDiscoveryException] for every "not available" outcome (disabled
/// listing, unreachable server, unsupported platform) — callers must catch
/// that and fall back to manual entry, never treat it as a dead end.
abstract class ServerDatabaseDiscovery {
  Future<List<String>> listDatabases(String baseUrl);

  /// Asks which single database the domain at [baseUrl] serves, without
  /// enumerating any others. Returns `null` when the server does not single
  /// out one database — including one that has not deployed the route yet.
  Future<String?> servedDatabase(String baseUrl);
}

class OdooServerDatabaseDiscovery implements ServerDatabaseDiscovery {
  OdooServerDatabaseDiscovery([OdooDatabaseDiscovery? client])
    : _client = client ?? OdooDatabaseDiscovery();

  final OdooDatabaseDiscovery _client;

  @override
  Future<List<String>> listDatabases(String baseUrl) =>
      _client.listDatabases(baseUrl);

  @override
  Future<String?> servedDatabase(String baseUrl) =>
      _client.servedDatabase(baseUrl);
}

Future<SavedServer?> showSavedServerManager(
  BuildContext context, {
  required SavedServersStore store,
  String initialUrl = '',
  String initialDatabase = '',
  ServerDatabaseDiscovery? discovery,
}) => showDialog<SavedServer?>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ServerManagerDialog(
    store: store,
    initialUrl: initialUrl,
    initialDatabase: initialDatabase,
    discovery: discovery ?? OdooServerDatabaseDiscovery(),
  ),
);

/// Los dos pasos del gestor en ancho compacto (orden del dueño, 12-sep-2026:
/// «el formulario no es práctico para ese tipo de dispositivos»). En teléfono
/// el gestor deja de ser un `ContentDialog` con lista+editor apilados y pasa
/// a ser una página con lista y editor en pantallas separadas, cada una con
/// su propio `PageHeader` — como cualquier otra pantalla de Orbi.
enum _CompactStep { list, editor }

class _ServerManagerDialog extends StatefulWidget {
  const _ServerManagerDialog({
    required this.store,
    required this.initialUrl,
    required this.initialDatabase,
    required this.discovery,
  });
  final SavedServersStore store;
  final String initialUrl;
  final String initialDatabase;
  final ServerDatabaseDiscovery discovery;

  @override
  State<_ServerManagerDialog> createState() => _ServerManagerDialogState();
}

class _ServerManagerDialogState extends State<_ServerManagerDialog> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _database = TextEditingController();
  List<SavedServer> _servers = const [];
  String? _loadError;
  // El error va pegado a su campo (orden del dueño, 12-sep-2026): cada
  // validación de _save() apunta a su propio OrbiField en vez de a un único
  // aviso genérico. _generalError es lo único que de verdad no pertenece a
  // un campo (falló guardar o eliminar contra el almacén).
  String? _nameError;
  String? _urlError;
  String? _databaseError;
  String? _generalError;
  String? _selectedId;
  String? _snapshot;
  bool _busy = false;
  bool _creating = true;
  // En ancho compacto siempre se arranca en la lista (Paso 1); nunca directo
  // al editor, ni siquiera con la lista vacía — tocar «Nuevo servidor» sigue
  // siendo el único camino al Paso 2, igual para "no hay nada guardado" que
  // para "hay diez servidores". En ancho ancho este campo no se usa.
  _CompactStep _compactStep = _CompactStep.list;

  Timer? _discoveryDebounce;
  Object? _activeDiscoveryToken;
  bool _discovering = false;
  List<String>? _discoveredDatabases;
  String? _discoveryNotice;
  bool _manualDatabaseEntry = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _url.text = widget.initialUrl;
    _database.text = widget.initialDatabase;
    _readServers();
    _snapshot ??= _formSnapshot();
    _url.addListener(_onUrlChanged);
    _onUrlChanged();
  }

  void _readServers() {
    try {
      _servers = widget.store.load();
      if (_servers.isNotEmpty) {
        final server = _servers.cast<SavedServer?>().firstWhere(
          (s) =>
              s!.url == _safeUrl(widget.initialUrl) &&
              s.database == widget.initialDatabase.trim(),
          orElse: () => _servers.first,
        )!;
        _selectedId = server.id;
        _creating = false;
        _name.text = server.name;
        _url.text = server.url;
        _database.text = server.database;
        _snapshot = _formSnapshot();
      }
    } on FormatException catch (e) {
      _loadError = 'No se pudieron leer los servidores guardados: ${e.message}';
    }
  }

  @override
  void dispose() {
    _discoveryDebounce?.cancel();
    _activeDiscoveryToken = null;
    _url.removeListener(_onUrlChanged);
    _search.dispose();
    _name.dispose();
    _url.dispose();
    _database.dispose();
    super.dispose();
  }

  /// Debounces database discovery while the URL is being typed, and resets
  /// any previous result so a stale dropdown never lingers for a URL the
  /// person already changed.
  void _onUrlChanged() {
    _discoveryDebounce?.cancel();
    _activeDiscoveryToken = null;
    final urlText = _url.text;
    setState(() {
      _discovering = false;
      _discoveredDatabases = null;
      _discoveryNotice = null;
      _manualDatabaseEntry = false;
    });
    if (SavedServersStore.validateUrl(urlText) != null) return;
    _discoveryDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _discoverDatabases(urlText),
    );
  }

  /// Reenvía el descubrimiento para la URL actual — usado por el botón
  /// «Listar bases» del dueño. Cancela cualquier debounce pendiente para que
  /// una pulsación manual no se solape con una automática.
  void _relaunchDiscovery() {
    final urlText = _url.text;
    if (SavedServersStore.validateUrl(urlText) != null) return;
    _discoveryDebounce?.cancel();
    _discoverDatabases(urlText);
  }

  Future<void> _discoverDatabases(String url) async {
    final token = Object();
    _activeDiscoveryToken = token;
    setState(() => _discovering = true);
    final trimmedUrl = url.trim();

    // Primero se pregunta si el dominio atiende una sola base
    // (`/orbi/database`, sin enumerar nada) — el caso de un servidor
    // público con `list_db = False` que niega el listado a propósito y por
    // eso `listDatabases` abajo lo ve indistinguible de "no hay red"
    // (orden del dueño, 12-sep-2026, caso mepriga.galapagos.tech).
    String? servedName;
    try {
      servedName = await widget.discovery.servedDatabase(trimmedUrl);
    } catch (_) {
      servedName = null;
    }
    if (!mounted || _activeDiscoveryToken != token) return;
    if (servedName != null) {
      setState(() {
        _discovering = false;
        _discoveredDatabases = null;
        _manualDatabaseEntry = false;
        if (_database.text.trim().isEmpty) {
          _database.text = servedName!;
        }
        _discoveryNotice = 'Este servidor atiende la base «$servedName».';
      });
      return;
    }

    List<String>? databases;
    String? notice;
    try {
      databases = await widget.discovery.listDatabases(trimmedUrl);
    } on DatabaseDiscoveryException catch (e) {
      notice = _noticeFor(e.kind);
    } catch (_) {
      notice =
          'No se pudo consultar la lista de bases de datos. '
          'Escribe el nombre manualmente.';
    }
    if (!mounted || _activeDiscoveryToken != token) return;
    setState(() {
      _discovering = false;
      if (databases == null) {
        _discoveryNotice = notice;
        return;
      }
      if (databases.isEmpty) {
        _discoveryNotice =
            'El servidor no reporta bases de datos disponibles. '
            'Escribe el nombre manualmente.';
        return;
      }
      _discoveredDatabases = databases;
      if (databases.length == 1 && _database.text.trim().isEmpty) {
        _database.text = databases.first;
      }
    });
  }

  String _noticeFor(DatabaseDiscoveryFailureKind kind) {
    switch (kind) {
      case DatabaseDiscoveryFailureKind.disabled:
        return 'El servidor tiene deshabilitado el listado de bases de '
            'datos. Escribe el nombre manualmente.';
      case DatabaseDiscoveryFailureKind.unsupportedPlatform:
        return 'Desde esta plataforma no se puede consultar la lista de '
            'bases. Escribe el nombre manualmente.';
      case DatabaseDiscoveryFailureKind.connection:
        return 'No se pudo conectar con el servidor para listar sus bases. '
            'Escribe el nombre manualmente.';
      case DatabaseDiscoveryFailureKind.protocol:
        return 'El servidor respondió de forma inesperada al listar bases. '
            'Escribe el nombre manualmente.';
    }
  }

  void _clearFieldErrors() {
    _nameError = null;
    _urlError = null;
    _databaseError = null;
    _generalError = null;
  }

  void _select(SavedServer server) {
    setState(() {
      _selectedId = server.id;
      _creating = false;
      _clearFieldErrors();
      _name.text = server.name;
      _url.text = server.url;
      _database.text = server.database;
      _snapshot = _formSnapshot();
    });
  }

  String? _safeUrl(String value) {
    try {
      return SavedServersStore.normalizeUrl(value);
    } catch (_) {
      return null;
    }
  }

  String _formSnapshot() =>
      '${_name.text}\u0000${_url.text}\u0000${_database.text}';
  bool get _hasChanges => _snapshot != _formSnapshot();

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('¿Descartar cambios?'),
            content: const Text(
              'Hay cambios sin guardar. ¿Quieres descartarlos?',
            ),
            actions: [
              HyperlinkButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Devuelven si de verdad avanzaron (false cuando la persona canceló el
  // descartar cambios) — la navegación del Paso 1 al Paso 2 en compacto
  // depende de saberlo; en ancho no le importa a nadie el valor de retorno.
  Future<bool> _selectWithGuard(SavedServer server) async {
    if (_busy || !await _confirmDiscard() || !mounted) return false;
    _select(server);
    return true;
  }

  Future<bool> _newServer() async {
    if (_busy || !await _confirmDiscard() || !mounted) return false;
    setState(() {
      _selectedId = null;
      _creating = true;
      _clearFieldErrors();
      _name.clear();
      _url.text = _servers.isEmpty ? widget.initialUrl : '';
      _database.text = _servers.isEmpty ? widget.initialDatabase : '';
      _snapshot = _formSnapshot();
    });
    return true;
  }

  /// Paso 1 → Paso 2 al tocar «Nuevo servidor» en compacto.
  Future<void> _newServerCompact() async {
    if (await _newServer() && mounted) {
      setState(() => _compactStep = _CompactStep.editor);
    }
  }

  /// Paso 1 → Paso 2 al tocar un acceso guardado en compacto.
  Future<void> _selectCompact(SavedServer server) async {
    if (await _selectWithGuard(server) && mounted) {
      setState(() => _compactStep = _CompactStep.editor);
    }
  }

  /// El botón «Atrás» del editor en compacto: misma confirmación de
  /// descartar cambios que ya usan cerrar y cambiar de servidor.
  Future<void> _backToList() async {
    if (_busy || !await _confirmDiscard() || !mounted) return;
    setState(() => _compactStep = _CompactStep.list);
  }

  /// Cierra el gestor entero devolviendo `null` — compartido por la `X` del
  /// diálogo ancho y por el botón de la cabecera del Paso 1 en compacto.
  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (!await _confirmDiscard() || !mounted) return;
    navigator.pop();
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  Future<void> _save() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final database = _database.text.trim();
    setState(_clearFieldErrors);
    if (name.isEmpty) {
      return setState(
        () => _nameError = 'Escribe un nombre para identificar el servidor.',
      );
    }
    final urlError = SavedServersStore.validateUrl(url);
    if (urlError != null) {
      return setState(() => _urlError = urlError);
    }
    if (database.isEmpty) {
      return setState(
        () => _databaseError = 'Escribe el nombre de la base de datos.',
      );
    }
    SavedServer server;
    try {
      server = SavedServer(
        id: _selectedId ?? _id(),
        name: name,
        url: url,
        database: database,
      );
    } on FormatException catch (e) {
      // Lo único que aquí sigue fallando después de validateUrl() es una
      // normalización de la URL que ese chequeo previo no cubre.
      return setState(() => _urlError = e.message);
    }
    setState(() => _busy = true);
    try {
      await widget.store.upsert(server);
      if (!mounted) return;
      _servers = widget.store.load();
      _selectedId = server.id;
      _creating = false;
      _snapshot = _formSnapshot();
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _generalError = 'No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final server = _servers.where((s) => s.id == _selectedId).firstOrNull;
    if (server == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('¿Eliminar servidor?'),
        content: const Text(
          'Sólo elimina el acceso guardado, no los datos de Odoo ni las operaciones locales.',
        ),
        actions: [
          HyperlinkButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.store.remove(server.id);
      if (!mounted) return;
      _servers = widget.store.load();
      setState(() {
        _selectedId = null;
        _creating = true;
        _name.clear();
        _url.text = _servers.isEmpty ? widget.initialUrl : '';
        _database.text = _servers.isEmpty ? widget.initialDatabase : '';
        _snapshot = _formSnapshot();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _generalError = 'No se pudo eliminar: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<SavedServer> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _servers;
    return _servers
        .where(
          (s) =>
              s.name.toLowerCase().contains(query) ||
              s.url.toLowerCase().contains(query) ||
              s.database.toLowerCase().contains(query),
        )
        .toList();
  }

  // El gestor ya no dibuja su propia superficie (orden del dueño,
  // 12-sep-2026: «todo está ya determinado por fluent_ui»). En ancho ancho
  // es un `ContentDialog` — el diálogo de Fluent — en vez de un `Card` a
  // mano dentro de `showDialog`: su fondo sale de `ContentDialogThemeData`
  // (`decoration.color = theme.menuColor`, opaco), así que el formulario de
  // acceso ya no se transparenta por detrás sin que tengamos que pintar
  // nada nosotros mismos.
  //
  // 🔴 En ancho compacto YA NO es un diálogo (orden del dueño, 12-sep-2026,
  // visto en su iPhone): un `ContentDialog` casi a pantalla completa que
  // recalculaba su `constraints.maxHeight` restando
  // `MediaQuery.viewInsetsOf(context).bottom` cambiaba de altura en cuanto
  // el teclado EMPEZABA a abrir. Ese cambio de altura hacía que
  // `_compactLayout` saltara de rama (de la fila con `Expanded` a un
  // `SingleChildScrollView` con el editor a altura fija) — dos árboles de
  // widgets distintos por debajo del mismo `TextBox`, así que su
  // `EditableText` se desmontaba y el navegador cerraba el teclado solo.
  // Confirmado en rojo contra 7b8a7a2 con foco perdido en "URL de Odoo",
  // "Nombre del servidor" y "Base de datos" en cuanto el teclado abría.
  //
  // El reemplazo es `_compactPage`: una página normal de Fluent
  // (`ScaffoldPage`/`PageHeader`), sin diálogo y sin restar `viewInsets` a
  // mano — `ScaffoldPage.resizeToAvoidBottomInset` (activo por defecto) ya
  // le hace sitio al teclado con un simple `Padding`, sin cambiar de rama de
  // layout ni desmontar nada.
  @override
  Widget build(BuildContext context) {
    // `compact` decide qué construir, así que hace falta el ancho REAL
    // disponible antes de construir nada — de ahí el `LayoutBuilder`
    // envolviendo todo. `MediaQuery.sizeOf(context).width` NO sirve aquí: en
    // las pruebas que usan `tester.binding.setSurfaceSize` (en vez de
    // `tester.view.physicalSize`) queda pegado al tamaño de ventana por
    // omisión y nunca ve el tamaño real, así que "compact" siempre daba
    // `false` y el editor terminaba exprimido dentro del layout de dos
    // paneles (medido: overflow de hasta 184 px).
    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        final compact =
            layoutConstraints.maxWidth < OrbiTheme.compactBreakpoint;
        if (compact) return _compactPage();

        return ContentDialog(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Servidores Odoo',
                  style: FluentTheme.of(context).typography.title,
                ),
              ),
              Tooltip(
                message: 'Cerrar',
                child: IconButton(
                  key: const ValueKey('server_manager_close'),
                  onPressed: _busy ? null : _close,
                  icon: const Icon(FluentIcons.chrome_close),
                ),
              ),
            ],
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadError != null) ...[
                _message(_loadError!, true),
                const SizedBox(height: OrbiTheme.space12),
              ],
              Expanded(child: _wideLayout()),
            ],
          ),
        );
      },
    );
  }

  /// El gestor en ancho compacto: una página a pantalla completa (no un
  /// diálogo), empujada por el mismo `Navigator` que abrió `showDialog` —
  /// `showDialog`/`FluentDialogRoute` ya la envuelve en su propio
  /// `SafeArea`, así que aquí no hace falta nada de eso, y con ella
  /// ocupando toda la ventana se lee como una pantalla más de Orbi, no como
  /// un recuadro flotante.
  ///
  /// Paso 1 (`_CompactStep.list`): la lista de accesos guardados con el
  /// buscador y «Nuevo servidor», con un botón para cerrar el gestor entero.
  /// Paso 2 (`_CompactStep.editor`): el editor en su propia página, con un
  /// botón «Atrás» que vuelve al Paso 1 (misma confirmación de descartar
  /// cambios que ya usa cerrar).
  Widget _compactPage() {
    final onList = _compactStep == _CompactStep.list;
    return ScaffoldPage(
      header: PageHeader(
        leading: onList
            ? null
            : Tooltip(
                message: 'Atrás',
                child: IconButton(
                  key: const ValueKey('server_manager_back_to_list'),
                  onPressed: _busy ? null : _backToList,
                  icon: const Icon(FluentIcons.back),
                ),
              ),
        title: Text(
          onList
              ? 'Servidores Odoo'
              : (_creating ? 'Nuevo servidor' : 'Editar servidor'),
        ),
        commandBar: onList
            ? Tooltip(
                message: 'Cerrar',
                child: IconButton(
                  key: const ValueKey('server_manager_close'),
                  onPressed: _busy ? null : _close,
                  icon: const Icon(FluentIcons.chrome_close),
                ),
              )
            : null,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrbiTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadError != null) ...[
              _message(_loadError!, true),
              const SizedBox(height: OrbiTheme.space12),
            ],
            Expanded(
              child: onList
                  ? _serverList(
                      onNewServer: _newServerCompact,
                      onSelect: _selectCompact,
                    )
                  : _editor(showHeading: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String message, bool error) {
    final resources = FluentTheme.of(context).resources;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OrbiTheme.space12),
      color: error
          ? resources.systemFillColorCriticalBackground
          : resources.subtleFillColorSecondary,
      child: Text(message),
    );
  }

  Widget _wideLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: 280, child: _serverList()),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: OrbiTheme.space12),
        child: Divider(direction: Axis.vertical),
      ),
      Expanded(child: _editor()),
    ],
  );

  // `OrbiForm.filling` trae su propio scroll interno (ver
  // odoo_widgets/orbi_form.dart) y necesita que su ancestro le dé una altura
  // acotada — un `SingleChildScrollView` por fuera se la da infinita y el
  // `Expanded` de `OrbiForm` revienta con "RenderFlex children have
  // non-zero flex but incoming height constraints are unbounded". Tanto
  // `_wideLayout` (dentro del `ContentDialog`) como `_compactPage` (dentro
  // de `ScaffoldPage`) ya le dan esa altura acotada desde un `Expanded`
  // propio — ver `build()`.
  //
  // La lista de accesos guardados en ambos anchos: en ancho ancho es el
  // panel izquierdo del `ContentDialog`; en ancho compacto, el Paso 1 entero
  // de `_compactPage`. [onNewServer]/[onSelect] son los únicos puntos donde
  // se diferencian — en compacto avanzan al Paso 2 además de mutar el
  // estado del formulario; en ancho ancho sólo mutan el estado, porque el
  // editor ya está visible al lado.
  Widget _serverList({
    VoidCallback? onNewServer,
    void Function(SavedServer)? onSelect,
  }) {
    final newServer = onNewServer ?? _newServer;
    final select = onSelect ?? _selectWithGuard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Accesos guardados (${_servers.length})',
                style: FluentTheme.of(context).typography.subtitle,
              ),
            ),
            Tooltip(
              message: 'Nuevo servidor',
              child: IconButton(
                key: const ValueKey('new_server'),
                onPressed: _busy ? null : newServer,
                icon: const Icon(FluentIcons.add),
              ),
            ),
          ],
        ),
        TextBox(
          key: const ValueKey('server_search'),
          controller: _search,
          placeholder: 'Buscar',
          prefix: const Padding(
            padding: EdgeInsets.symmetric(horizontal: OrbiTheme.space8),
            child: Icon(FluentIcons.search, size: 16),
          ),
        ),
        const SizedBox(height: OrbiTheme.space8),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No hay coincidencias.'))
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final server = _filtered[index];
                    return ListTile.selectable(
                      selected: server.id == _selectedId,
                      onPressed: _busy ? null : () => select(server),
                      title: Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${server.url}\n${server.database}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Base de datos: dropdown cuando el servidor ofreció varias, texto libre
  /// en cualquier otro caso (aún consultando, sin datos todavía, o el
  /// servidor no permite listar). Nunca deja a la persona sin forma de
  /// avanzar: el enlace "Escribir manualmente" siempre puede recuperar el
  /// campo de texto aunque haya un listado disponible.
  ///
  /// La etiqueta, el asterisco de obligatorio y el error van por
  /// [OrbiField] — lo único que este método sigue construyendo a mano es el
  /// contenido propio del campo (el dropdown-o-texto, el enlace "Escribir
  /// manualmente" y los avisos de descubrimiento), que no es "ayuda
  /// genérica" sino parte del control mismo.
  OrbiField _databaseField() {
    final suffix = _discovering
        ? const Padding(
            padding: EdgeInsets.all(OrbiTheme.space8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: ProgressRing(strokeWidth: 2),
            ),
          )
        : null;
    final databases = _discoveredDatabases;
    final showDropdown =
        databases != null && databases.length > 1 && !_manualDatabaseEntry;
    final caption = FluentTheme.of(context).typography.caption;
    final canRelaunch =
        !_busy &&
        !_discovering &&
        SavedServersStore.validateUrl(_url.text) == null;

    return OrbiField(
      label: 'Base de datos',
      required: true,
      error: _databaseError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: showDropdown
                    ? ComboBox<String>(
                        key: const ValueKey('server_database_dropdown'),
                        value: databases.contains(_database.text)
                            ? _database.text
                            : null,
                        isExpanded: true,
                        items: [
                          for (final db in databases)
                            ComboBoxItem(value: db, child: Text(db)),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _database.text = value ?? ''),
                      )
                    : TextBox(
                        key: const ValueKey('server_database'),
                        controller: _database,
                        enabled: !_busy,
                        suffix: suffix,
                      ),
              ),
              const SizedBox(width: OrbiTheme.space8),
              // Pedido del dueño (12-sep-2026): relanza el mismo
              // descubrimiento para la URL actual, sin esperar el debounce.
              Button(
                key: const ValueKey('server_manager_list_databases'),
                onPressed: canRelaunch ? _relaunchDiscovery : null,
                child: const Text('Listar bases'),
              ),
            ],
          ),
          if (showDropdown)
            Align(
              alignment: Alignment.centerRight,
              child: HyperlinkButton(
                key: const ValueKey('database_manual_entry'),
                onPressed: _busy
                    ? null
                    : () => setState(() => _manualDatabaseEntry = true),
                child: const Text('Escribir manualmente'),
              ),
            ),
          if (_discoveryNotice != null)
            Padding(
              padding: const EdgeInsets.only(top: OrbiTheme.space4),
              child: Text(
                _discoveryNotice!,
                key: const ValueKey('database_discovery_notice'),
                style: caption,
              ),
            )
          else if (!showDropdown && databases != null && databases.length == 1)
            Padding(
              padding: const EdgeInsets.only(top: OrbiTheme.space4),
              child: Text(
                'Se detectó una sola base de datos y fue seleccionada.',
                style: caption,
              ),
            ),
        ],
      ),
    );
  }

  /// El formulario estándar (orden del dueño, 12-sep-2026): la etiqueta va
  /// encima de cada campo, lo obligatorio se marca antes de escribir y el
  /// error queda pegado al campo que falló, no en un aviso genérico como
  /// antes. `OrbiForm.filling` necesita que quien lo envuelve le dé una
  /// altura acotada (scrollea por dentro y deja las acciones fijas) — aquí se
  /// la da el `Expanded` de este mismo método, que a su vez sólo funciona
  /// porque `_wideLayout`/`_compactPage` ya acotan su propia altura desde
  /// `build()`. Ver la nota en `_serverList`.
  ///
  /// La fila de Guardar/Usar servidor/Borrar NO pasa por `OrbiActionBar`:
  /// ese widget está pensado para el par confirmar/cancelar (dos botones,
  /// el segundo oculto entero cuando no aplica). Aquí hay tres acciones —
  /// "Usar servidor" debe seguir viéndose DESHABILITADA cuando no hay
  /// selección, no desaparecer — así que forzarla ahí habría cambiado el
  /// comportamiento en vez de sólo estandarizar dónde se dibuja.
  ///
  /// [showHeading] apaga el título propio ("Nuevo servidor"/"Editar
  /// servidor") cuando quien envuelve este método ya lo puso en su propia
  /// cabecera — el `PageHeader` del Paso 2 en `_compactPage`. En ancho ancho
  /// el título del `ContentDialog` es el genérico "Servidores Odoo", así que
  /// ahí el editor sigue poniendo el suyo.
  Widget _editor({bool showHeading = true}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showHeading) ...[
        Text(
          _creating ? 'Nuevo servidor' : 'Editar servidor',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        const SizedBox(height: OrbiTheme.space8),
      ],
      Text(
        _creating
            ? 'Guarda sólo los datos de conexión. Las credenciales se solicitan al iniciar sesión.'
            : 'Actualiza los datos de este acceso guardado.',
      ),
      if (_generalError != null) ...[
        const SizedBox(height: OrbiTheme.space12),
        _message(_generalError!, true),
      ],
      const SizedBox(height: OrbiTheme.space16),
      Expanded(
        child: OrbiForm.filling(
          sections: [
            OrbiFormSection(
              title: 'Datos de conexión',
              fields: [
                OrbiField(
                  label: 'Nombre del servidor',
                  required: true,
                  error: _nameError,
                  child: TextBox(
                    key: const ValueKey('server_name'),
                    controller: _name,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    placeholder: 'Producción',
                  ),
                ),
                OrbiField(
                  label: 'URL de Odoo',
                  required: true,
                  error: _urlError,
                  child: TextBox(
                    key: const ValueKey('server_url'),
                    controller: _url,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    placeholder: 'https://odoo.ejemplo.com',
                  ),
                ),
                _databaseField(),
              ],
            ),
          ],
          actions: Wrap(
            spacing: OrbiTheme.space8,
            runSpacing: OrbiTheme.space8,
            children: [
              FilledButton(
                key: const ValueKey('save_server'),
                onPressed: _busy ? null : _save,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.save, size: 16),
                    SizedBox(width: 8),
                    Text('Guardar'),
                  ],
                ),
              ),
              OutlinedButton(
                key: const ValueKey('use_server'),
                onPressed: _busy || _selectedId == null
                    ? null
                    : () async {
                        if (await _confirmDiscard() && mounted) {
                          Navigator.pop(
                            context,
                            _servers.firstWhere((s) => s.id == _selectedId),
                          );
                        }
                      },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.signin, size: 16),
                    SizedBox(width: 8),
                    Text('Usar servidor'),
                  ],
                ),
              ),
              if (!_creating)
                HyperlinkButton(
                  onPressed: _busy ? null : _remove,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.delete, size: 16),
                      SizedBox(width: 8),
                      Text('Borrar'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
