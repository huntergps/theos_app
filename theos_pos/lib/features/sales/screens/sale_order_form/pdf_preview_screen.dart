/// PDF Preview Screen
///
/// Full-screen PDF viewer that opens as a tab in the sales module.
/// Provides options to print or share the PDF.
library;

import 'dart:typed_data';
import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';

/// Screen for previewing PDF documents (used as tab content)
class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;
  final String filename;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.title,
    required this.filename,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen>
    with AutomaticKeepAliveClientMixin {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = false;
  double _currentZoom = 1.0;

  // Page navigation
  int _totalPages = 0;
  int _currentPage = 1;
  int _currentPageGroup = 0; // Para paginación cuando hay más de 4 páginas
  static const int _pagesPerGroup = 4;

  // Zoom presets
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;
  static const double _zoomStep = 0.25;

  /// Keep this widget alive when switching tabs to avoid re-parsing PDF bytes
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + _zoomStep).clamp(_minZoom, _maxZoom);
    _pdfController.zoomLevel = newZoom;
    setState(() => _currentZoom = newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - _zoomStep).clamp(_minZoom, _maxZoom);
    _pdfController.zoomLevel = newZoom;
    setState(() => _currentZoom = newZoom);
  }

  void _resetZoom() {
    _pdfController.zoomLevel = 1.0;
    setState(() => _currentZoom = 1.0);
  }

  void _fitToPage() {
    // Zoom level ~0.75 fits a full A4 page on most screens
    _pdfController.zoomLevel = 0.75;
    setState(() => _currentZoom = 0.75);
  }

  /// Determina el modo de visualización según el número de páginas
  PdfPageLayoutMode _getPageLayoutMode() {
    if (_totalPages <= 1) {
      return PdfPageLayoutMode.single;
    } else if (_totalPages <= 4) {
      // Ver todas las páginas completas (2-4 páginas)
      return PdfPageLayoutMode.continuous;
    } else {
      // Más de 4 páginas: mostrar de 4 en 4
      return PdfPageLayoutMode.continuous;
    }
  }

  /// Obtiene el rango de páginas a mostrar cuando hay más de 4
  int _getStartPage() {
    if (_totalPages <= 4) {
      return 1;
    }
    return (_currentPageGroup * _pagesPerGroup) + 1;
  }

  int _getEndPage() {
    if (_totalPages <= 4) {
      return _totalPages;
    }
    final endPage = (_currentPageGroup + 1) * _pagesPerGroup;
    return endPage > _totalPages ? _totalPages : endPage;
  }

  int _getTotalPageGroups() {
    if (_totalPages <= 4) {
      return 1;
    }
    return ((_totalPages - 1) ~/ _pagesPerGroup) + 1;
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      _pdfController.jumpToPage(_currentPage - 1);
      setState(() {
        _currentPage--;
        // Actualizar grupo si es necesario
        if (_totalPages > 4) {
          _currentPageGroup = ((_currentPage - 1) ~/ _pagesPerGroup);
        }
      });
    }
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages) {
      _pdfController.jumpToPage(_currentPage + 1);
      setState(() {
        _currentPage++;
        // Actualizar grupo si es necesario
        if (_totalPages > 4) {
          _currentPageGroup = ((_currentPage - 1) ~/ _pagesPerGroup);
        }
      });
    }
  }

  void _goToPreviousGroup() {
    if (_currentPageGroup > 0) {
      setState(() {
        _currentPageGroup--;
        _currentPage = (_currentPageGroup * _pagesPerGroup) + 1;
      });
      // Ir a la primera página del grupo anterior
      _pdfController.jumpToPage(_currentPage);
      // Asegurar que el zoom esté ajustado para ver 4 páginas
      if (_currentZoom > 0.5) {
        _pdfController.zoomLevel = 0.45;
        setState(() => _currentZoom = 0.45);
      }
    }
  }

  void _goToNextGroup() {
    final totalGroups = _getTotalPageGroups();
    if (_currentPageGroup < totalGroups - 1) {
      setState(() {
        _currentPageGroup++;
        _currentPage = (_currentPageGroup * _pagesPerGroup) + 1;
      });
      // Ir a la primera página del grupo siguiente
      _pdfController.jumpToPage(_currentPage);
      // Asegurar que el zoom esté ajustado para ver 4 páginas
      if (_currentZoom > 0.5) {
        _pdfController.zoomLevel = 0.45;
        setState(() => _currentZoom = 0.45);
      }
    }
  }

  void _onPageChanged(int pageNumber) {
    setState(() {
      _currentPage = pageNumber;
      if (_totalPages > 4) {
        _currentPageGroup = ((pageNumber - 1) ~/ _pagesPerGroup);
      }
    });
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _totalPages = details.document.pages.count;
      _currentPage = 1;
      _currentPageGroup = 0;
    });
    
    // Si hay más de 4 páginas, ajustar zoom para que quepan aproximadamente 4 páginas
    if (_totalPages > 4) {
      // Zoom aproximado para que quepan 4 páginas verticalmente
      // Ajustar según el tamaño de la pantalla (aproximadamente 0.4-0.5)
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _pdfController.zoomLevel = 0.45;
          setState(() => _currentZoom = 0.45);
        }
      });
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isLoading = true);
    try {
      // Save PDF to temp file and open with system viewer (Preview.app on macOS)
      // User can then print with Cmd+P
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.filename}');
      await file.writeAsBytes(widget.pdfBytes);

      logger.d('[PdfPreview]', 'Opening PDF for print: ${file.path}');
      final result = await OpenFile.open(file.path);
      logger.d('[PdfPreview]', 'OpenFile result: ${result.type}');

      if (result.type != ResultType.done && mounted) {
        _showError('No se pudo abrir el PDF: ${result.message}');
      }
    } catch (e) {
      logger.e('[PdfPreview]', 'Error opening PDF: $e');
      if (mounted) {
        _showError('Error al abrir PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleShare() async {
    setState(() => _isLoading = true);
    try {
      // Save PDF to temp file for sharing
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.filename}');
      await file.writeAsBytes(widget.pdfBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: widget.title,
      );
    } catch (e) {
      if (mounted) {
        _showError('Error al compartir: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    CopyableInfoBar.showError(
      context,
      title: 'Error',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin to keep widget alive
    super.build(context);

    final theme = FluentTheme.of(context);
    final zoomPercent = (_currentZoom * 100).toInt();

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.pdf, size: 24, color: theme.accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: theme.typography.subtitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            // Page navigation controls (solo si hay más de 1 página)
            if (_totalPages > 1) ...[
              // Navegación por grupos (solo si hay más de 4 páginas)
              if (_totalPages > 4) ...[
                CommandBarButton(
                  icon: const Icon(FluentIcons.chevron_left),
                  label: const Text('Grupo Anterior'),
                  onPressed: _currentPageGroup > 0 ? _goToPreviousGroup : null,
                ),
                CommandBarButton(
                  icon: const Icon(FluentIcons.chevron_right),
                  label: const Text('Grupo Siguiente'),
                  onPressed: _currentPageGroup < _getTotalPageGroups() - 1
                      ? _goToNextGroup
                      : null,
                ),
                const CommandBarSeparator(),
                // Indicador de grupo
                CommandBarButton(
                  icon: const Icon(FluentIcons.page),
                  label: Text(
                    'Grupo ${_currentPageGroup + 1}/${_getTotalPageGroups()} '
                    '(${_getStartPage()}-${_getEndPage()})',
                  ),
                  onPressed: null,
                ),
                const CommandBarSeparator(),
              ],
              // Navegación por página individual
              CommandBarButton(
                icon: const Icon(FluentIcons.chevron_left),
                label: const Text('Anterior'),
                onPressed: _currentPage > 1 ? _goToPreviousPage : null,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.page),
                label: Text(
                  _totalPages > 4
                      ? 'Página $_currentPage/$_totalPages'
                      : 'Página $_currentPage/$_totalPages',
                ),
                onPressed: null,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.chevron_right),
                label: const Text('Siguiente'),
                onPressed: _currentPage < _totalPages ? _goToNextPage : null,
              ),
              const CommandBarSeparator(),
            ],
            // Zoom controls
            CommandBarButton(
              icon: const Icon(FluentIcons.fit_page),
              label: const Text('Página'),
              onPressed: _fitToPage,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.remove),
              label: const Text(''),
              onPressed: _currentZoom > _minZoom ? _zoomOut : null,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.full_screen),
              label: Text('$zoomPercent%'),
              onPressed: _resetZoom,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text(''),
              onPressed: _currentZoom < _maxZoom ? _zoomIn : null,
            ),
            const CommandBarSeparator(),
            // Actions
            CommandBarButton(
              icon: const Icon(FluentIcons.share),
              label: const Text('Compartir'),
              onPressed: _isLoading ? null : _handleShare,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.print),
              label: const Text('Imprimir'),
              onPressed: _isLoading ? null : _handlePrint,
            ),
          ],
        ),
      ),
      content: Stack(
        children: [
          // PDF Viewer
          SfPdfViewer.memory(
            widget.pdfBytes,
            key: _pdfViewerKey,
            controller: _pdfController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            pageLayoutMode: _getPageLayoutMode(),
            initialZoomLevel: 1.0,
            onZoomLevelChanged: (details) {
              setState(() => _currentZoom = details.newZoomLevel);
            },
            onPageChanged: (details) {
              _onPageChanged(details.newPageNumber);
            },
            onDocumentLoaded: (details) {
              _onDocumentLoaded(details);
            },
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
              child: const Center(
                child: ProgressRing(),
              ),
            ),
        ],
      ),
    );
  }
}
