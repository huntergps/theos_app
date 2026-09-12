import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DocumentFiscalState {
  notRequired,
  localDraft,
  submitted,
  authorized,
  rejected,
}

enum DocumentSyncState { localOnly, queued, synced, failed }

extension DocumentStateLabels on DocumentFiscalState {
  String get label => switch (this) {
    DocumentFiscalState.notRequired => 'No aplica',
    DocumentFiscalState.localDraft => 'Emitido localmente',
    DocumentFiscalState.submitted => 'Enviado al SRI',
    DocumentFiscalState.authorized => 'Autorizado por el SRI',
    DocumentFiscalState.rejected => 'Rechazado por el SRI',
  };
}

extension DocumentSyncStateLabels on DocumentSyncState {
  String get label => switch (this) {
    DocumentSyncState.localOnly => 'Solo local',
    DocumentSyncState.queued => 'Pendiente de sincronizar',
    DocumentSyncState.synced => 'Sincronizado',
    DocumentSyncState.failed => 'Sincronización fallida',
  };
}

final class CachedDocument {
  const CachedDocument({
    required this.title,
    required this.bytes,
    required this.mimeType,
    required this.fiscalState,
    required this.syncState,
  });
  final String title;
  final List<int> bytes;
  final String mimeType;
  final DocumentFiscalState fiscalState;
  final DocumentSyncState syncState;
}

/// Stable JSON representation used by the scope-local metadata cache.
///
/// Bytes are deliberately kept as base64: the cache is durable and can be
/// reopened after a process restart without depending on a renderer or a
/// platform file API. Fiscal and synchronization state remain independent.
final class CachedDocumentCodec {
  const CachedDocumentCodec._();

  static String encode(CachedDocument document) => jsonEncode({
    'title': document.title,
    'mimeType': document.mimeType,
    'bytes': base64Encode(document.bytes),
    'fiscalState': document.fiscalState.name,
    'syncState': document.syncState.name,
  });

  static CachedDocument decode(String encoded, {required String documentId}) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) throw const FormatException('Invalid document cache');
    final title = decoded['title'];
    final mimeType = decoded['mimeType'];
    final bytes = decoded['bytes'];
    if (title is! String ||
        title.trim().isEmpty ||
        mimeType is! String ||
        mimeType.trim().isEmpty ||
        bytes is! String) {
      throw const FormatException('Incomplete document cache');
    }
    final fiscalName = decoded['fiscalState'];
    final syncName = decoded['syncState'];
    if (fiscalName is! String || syncName is! String) {
      throw const FormatException('Document states are missing');
    }
    DocumentFiscalState? fiscalState;
    for (final value in DocumentFiscalState.values) {
      if (value.name == fiscalName) fiscalState = value;
    }
    DocumentSyncState? syncState;
    for (final value in DocumentSyncState.values) {
      if (value.name == syncName) syncState = value;
    }
    if (fiscalState == null || syncState == null) {
      throw const FormatException('Unknown document state');
    }
    try {
      final bytesValue = base64Decode(bytes);
      if (bytesValue.isEmpty) throw const FormatException('Empty document');
      return CachedDocument(
        title: title,
        bytes: bytesValue,
        mimeType: mimeType,
        fiscalState: fiscalState,
        syncState: syncState,
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid document bytes: $error');
    }
  }
}

abstract interface class DocumentRenderPort {
  Future<CachedDocument> loadCached(String documentId);
}

final documentRenderPortProvider = Provider<DocumentRenderPort>(
  (ref) => const _UnavailableDocumentPort(),
);

final class _UnavailableDocumentPort implements DocumentRenderPort {
  const _UnavailableDocumentPort();
  @override
  Future<CachedDocument> loadCached(String documentId) =>
      Future.error(StateError('No hay documento cacheado'));
}

class DocumentView extends StatefulWidget {
  const DocumentView({required this.port, required this.documentId, super.key});
  final DocumentRenderPort port;
  final String documentId;

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

final class _DocumentViewState extends State<DocumentView> {
  late Future<CachedDocument> _document;

  @override
  void initState() {
    super.initState();
    _document = widget.port.loadCached(widget.documentId);
  }

  @override
  void didUpdateWidget(covariant DocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.port, widget.port) ||
        oldWidget.documentId != widget.documentId) {
      _document = widget.port.loadCached(widget.documentId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CachedDocument>(
    future: _document,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: ProgressRing());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.text_document, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Documento no disponible sin conexión',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Primero sincroniza una copia desde Odoo.',
                  textAlign: TextAlign.center,
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ),
          ),
        );
      }
      final document = snapshot.data;
      if (document == null) return const Center(child: Text('Documento vacío'));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            document.title,
            style: FluentTheme.of(context).typography.title,
          ),
          Text('Estado fiscal: ${document.fiscalState.label}'),
          Text('Estado local: ${document.syncState.label}'),
          Text(
            'Formato: ${document.mimeType} · ${document.bytes.length} bytes',
          ),
        ],
      );
    },
  );
}
