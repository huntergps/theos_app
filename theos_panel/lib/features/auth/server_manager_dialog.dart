import 'dart:async';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

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
}

class OdooServerDatabaseDiscovery implements ServerDatabaseDiscovery {
  OdooServerDatabaseDiscovery([OdooDatabaseDiscovery? client])
    : _client = client ?? OdooDatabaseDiscovery();

  final OdooDatabaseDiscovery _client;

  @override
  Future<List<String>> listDatabases(String baseUrl) =>
      _client.listDatabases(baseUrl);
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
  String? _error;
  String? _selectedId;
  String? _snapshot;
  bool _busy = false;
  bool _creating = true;

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

  Future<void> _discoverDatabases(String url) async {
    final token = Object();
    _activeDiscoveryToken = token;
    setState(() => _discovering = true);
    List<String>? databases;
    String? notice;
    try {
      databases = await widget.discovery.listDatabases(url.trim());
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

  void _select(SavedServer server) {
    setState(() {
      _selectedId = server.id;
      _creating = false;
      _error = null;
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

  Future<void> _selectWithGuard(SavedServer server) async {
    if (_busy || !await _confirmDiscard() || !mounted) return;
    _select(server);
  }

  Future<void> _newServer() async {
    if (_busy || !await _confirmDiscard() || !mounted) return;
    setState(() {
      _selectedId = null;
      _creating = true;
      _error = null;
      _name.clear();
      _url.text = _servers.isEmpty ? widget.initialUrl : '';
      _database.text = _servers.isEmpty ? widget.initialDatabase : '';
      _snapshot = _formSnapshot();
    });
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  Future<void> _save() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final database = _database.text.trim();
    if (name.isEmpty) {
      return setState(
        () => _error = 'Escribe un nombre para identificar el servidor.',
      );
    }
    final urlError = SavedServersStore.validateUrl(url);
    if (urlError != null) {
      return setState(() => _error = urlError);
    }
    if (database.isEmpty) {
      return setState(() => _error = 'Escribe el nombre de la base de datos.');
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
      return setState(() => _error = e.message);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.upsert(server);
      if (!mounted) return;
      _servers = widget.store.load();
      _selectedId = server.id;
      _creating = false;
      _error = null;
      _snapshot = _formSnapshot();
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $error');
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
      if (mounted) setState(() => _error = 'No se pudo eliminar: $error');
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

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: Padding(
      padding: MediaQuery.sizeOf(context).width < OrbiTheme.compactBreakpoint
          ? EdgeInsets.zero
          : const EdgeInsets.all(OrbiTheme.space16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < OrbiTheme.compactBreakpoint;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: compact ? MediaQuery.sizeOf(context).height : 720,
            ),
            child: Card(
              padding: const EdgeInsets.all(OrbiTheme.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          onPressed: _busy
                              ? null
                              : () async {
                                  final navigator = Navigator.of(context);
                                  if (!await _confirmDiscard() || !mounted) {
                                    return;
                                  }
                                  navigator.pop();
                                },
                          icon: const Icon(FluentIcons.chrome_close),
                        ),
                      ),
                    ],
                  ),
                  if (_loadError != null) _message(_loadError!, true),
                  const SizedBox(height: OrbiTheme.space12),
                  Expanded(child: compact ? _compactLayout() : _wideLayout()),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

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

  Widget _compactLayout() => SingleChildScrollView(
    child: Column(
      children: [
        SizedBox(height: 190, child: _serverList()),
        const SizedBox(height: OrbiTheme.space16),
        _editor(),
      ],
    ),
  );

  Widget _serverList() => Column(
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
              onPressed: _busy ? null : _newServer,
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
                    onPressed: _busy ? null : () => _selectWithGuard(server),
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

  /// Base de datos: dropdown cuando el servidor ofreció varias, texto libre
  /// en cualquier otro caso (aún consultando, sin datos todavía, o el
  /// servidor no permite listar). Nunca deja a la persona sin forma de
  /// avanzar: el enlace "Escribir manualmente" siempre puede recuperar el
  /// campo de texto aunque haya un listado disponible.
  Widget _databaseField() {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: 'Base de datos',
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
    );
  }

  Widget _editor() => Form(
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(right: OrbiTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _creating ? 'Nuevo servidor' : 'Editar servidor',
            style: FluentTheme.of(context).typography.titleLarge,
          ),
          const SizedBox(height: OrbiTheme.space8),
          Text(
            _creating
                ? 'Guarda sólo los datos de conexión. Las credenciales se solicitan al iniciar sesión.'
                : 'Actualiza los datos de este acceso guardado.',
          ),
          const SizedBox(height: OrbiTheme.space16),
          InfoLabel(
            label: 'Nombre del servidor',
            child: TextBox(
              key: const ValueKey('server_name'),
              controller: _name,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              placeholder: 'Producción',
            ),
          ),
          const SizedBox(height: OrbiTheme.space12),
          InfoLabel(
            label: 'URL de Odoo',
            child: TextBox(
              key: const ValueKey('server_url'),
              controller: _url,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              placeholder: 'https://odoo.ejemplo.com',
            ),
          ),
          const SizedBox(height: OrbiTheme.space12),
          _databaseField(),
          if (_error != null) ...[
            const SizedBox(height: OrbiTheme.space12),
            _message(_error!, true),
          ],
          const SizedBox(height: OrbiTheme.space24),
          Wrap(
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
        ],
      ),
    ),
  );
}
