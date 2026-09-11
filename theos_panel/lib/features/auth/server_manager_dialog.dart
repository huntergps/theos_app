import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme/orbi_theme.dart';
import 'saved_servers.dart';

Future<SavedServer?> showSavedServerManager(
  BuildContext context, {
  required SavedServersStore store,
  String initialUrl = '',
  String initialDatabase = '',
}) => showDialog<SavedServer?>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ServerManagerDialog(
    store: store,
    initialUrl: initialUrl,
    initialDatabase: initialDatabase,
  ),
);

class _ServerManagerDialog extends StatefulWidget {
  const _ServerManagerDialog({
    required this.store,
    required this.initialUrl,
    required this.initialDatabase,
  });
  final SavedServersStore store;
  final String initialUrl;
  final String initialDatabase;

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

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _url.text = widget.initialUrl;
    _database.text = widget.initialDatabase;
    _readServers();
    _snapshot ??= _formSnapshot();
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
    _search.dispose();
    _name.dispose();
    _url.dispose();
    _database.dispose();
    super.dispose();
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
          builder: (context) => AlertDialog(
            title: const Text('¿Descartar cambios?'),
            content: const Text(
              'Hay cambios sin guardar. ¿Quieres descartarlos?',
            ),
            actions: [
              TextButton(
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
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar servidor?'),
        content: const Text(
          'Sólo elimina el acceso guardado, no los datos de Odoo ni las operaciones locales.',
        ),
        actions: [
          TextButton(
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
  Widget build(BuildContext context) => Dialog(
    insetPadding: MediaQuery.sizeOf(context).width < OrbiTheme.compactBreakpoint
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
          child: Padding(
            padding: const EdgeInsets.all(OrbiTheme.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Servidores Odoo',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              if (!await _confirmDiscard() || !mounted) return;
                              navigator.pop();
                            },
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
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
  );

  Widget _message(String message, bool error) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OrbiTheme.space12),
    color: (error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest),
    child: Text(message),
  );

  Widget _wideLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: 280, child: _serverList()),
      const VerticalDivider(width: OrbiTheme.space24),
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('new_server'),
            onPressed: _busy ? null : _newServer,
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo servidor',
          ),
        ],
      ),
      TextField(
        key: const ValueKey('server_search'),
        controller: _search,
        decoration: const InputDecoration(
          labelText: 'Buscar',
          prefixIcon: Icon(Icons.search),
          isDense: true,
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
                  return ListTile(
                    selected: server.id == _selectedId,
                    onTap: _busy ? null : () => _selectWithGuard(server),
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

  Widget _editor() => Form(
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(right: OrbiTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _creating ? 'Nuevo servidor' : 'Editar servidor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: OrbiTheme.space8),
          Text(
            _creating
                ? 'Guarda sólo los datos de conexión. Las credenciales se solicitan al iniciar sesión.'
                : 'Actualiza los datos de este acceso guardado.',
          ),
          const SizedBox(height: OrbiTheme.space16),
          TextField(
            key: const ValueKey('server_name'),
            controller: _name,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nombre del servidor',
              hintText: 'Producción',
            ),
          ),
          const SizedBox(height: OrbiTheme.space12),
          TextField(
            key: const ValueKey('server_url'),
            controller: _url,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL de Odoo',
              hintText: 'https://odoo.ejemplo.com',
            ),
          ),
          const SizedBox(height: OrbiTheme.space12),
          TextField(
            key: const ValueKey('server_database'),
            controller: _database,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: 'Base de datos'),
          ),
          if (_error != null) ...[
            const SizedBox(height: OrbiTheme.space12),
            _message(_error!, true),
          ],
          const SizedBox(height: OrbiTheme.space24),
          Wrap(
            spacing: OrbiTheme.space8,
            runSpacing: OrbiTheme.space8,
            children: [
              FilledButton.icon(
                key: const ValueKey('save_server'),
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
              OutlinedButton.icon(
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
                icon: const Icon(Icons.login),
                label: const Text('Usar servidor'),
              ),
              if (!_creating)
                TextButton.icon(
                  onPressed: _busy ? null : _remove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
