import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sale_order_tabs_provider.g.dart';

/// Representa una pestaña abierta en el módulo de ventas
///
/// Similar a Odoo 19.0, cada orden abierta tiene su propia pestaña
class SaleOrderTab {
  /// ID único de la pestaña (para el TabView)
  final String tabId;

  /// Tipo de pestaña
  final SaleOrderTabType type;

  /// ID de la orden (null para nueva orden o listado)
  final int? orderId;

  /// Nombre para mostrar en la pestaña
  final String title;

  /// Si la orden está en modo edición
  final bool isEditing;

  /// Si tiene cambios sin guardar
  final bool hasUnsavedChanges;

  /// Datos del PDF (solo para pestañas de tipo pdfPreview)
  /// null = cargando, Uint8List = PDF listo
  final Uint8List? pdfBytes;

  /// Nombre del archivo PDF (solo para pestañas de tipo pdfPreview)
  final String? pdfFilename;

  /// Indica si el PDF está cargando (solo para pdfPreview)
  final bool isPdfLoading;

  /// Error al generar PDF (solo para pdfPreview)
  final String? pdfError;

  const SaleOrderTab({
    required this.tabId,
    required this.type,
    this.orderId,
    required this.title,
    this.isEditing = false,
    this.hasUnsavedChanges = false,
    this.pdfBytes,
    this.pdfFilename,
    this.isPdfLoading = false,
    this.pdfError,
  });

  /// Crear pestaña del listado
  factory SaleOrderTab.list() {
    return const SaleOrderTab(
      tabId: 'list',
      type: SaleOrderTabType.list,
      title: 'Órdenes de Venta',
    );
  }

  /// Crear pestaña para ver una orden existente
  factory SaleOrderTab.view(int orderId, String orderName) {
    return SaleOrderTab(
      tabId: 'view_$orderId',
      type: SaleOrderTabType.view,
      orderId: orderId,
      title: orderName,
    );
  }

  /// Crear pestaña para editar una orden existente
  factory SaleOrderTab.edit(int orderId, String orderName) {
    return SaleOrderTab(
      tabId: 'edit_$orderId',
      type: SaleOrderTabType.edit,
      orderId: orderId,
      title: orderName,
      isEditing: true,
    );
  }

  /// Crear pestaña para nueva orden
  factory SaleOrderTab.newOrder() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return SaleOrderTab(
      tabId: 'new_$timestamp',
      type: SaleOrderTabType.newOrder,
      title: 'Nueva orden',
      isEditing: true,
    );
  }

  /// Crear pestaña para vista previa de PDF (con datos)
  factory SaleOrderTab.pdfPreview({
    required int orderId,
    required String orderName,
    required Uint8List pdfBytes,
    required String filename,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return SaleOrderTab(
      tabId: 'pdf_${orderId}_$timestamp',
      type: SaleOrderTabType.pdfPreview,
      orderId: orderId,
      title: 'PDF: $orderName',
      pdfBytes: pdfBytes,
      pdfFilename: filename,
      isPdfLoading: false,
    );
  }

  /// Crear pestaña para vista previa de PDF en estado de carga
  factory SaleOrderTab.pdfPreviewLoading({
    required int orderId,
    required String orderName,
    required String filename,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return SaleOrderTab(
      tabId: 'pdf_${orderId}_$timestamp',
      type: SaleOrderTabType.pdfPreview,
      orderId: orderId,
      title: 'PDF: $orderName',
      pdfFilename: filename,
      isPdfLoading: true,
    );
  }

  SaleOrderTab copyWith({
    String? title,
    bool? isEditing,
    bool? hasUnsavedChanges,
    Uint8List? pdfBytes,
    String? pdfFilename,
    bool? isPdfLoading,
    String? pdfError,
  }) {
    return SaleOrderTab(
      tabId: tabId,
      type: type,
      orderId: orderId,
      title: title ?? this.title,
      isEditing: isEditing ?? this.isEditing,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      pdfBytes: pdfBytes ?? this.pdfBytes,
      pdfFilename: pdfFilename ?? this.pdfFilename,
      isPdfLoading: isPdfLoading ?? this.isPdfLoading,
      pdfError: pdfError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleOrderTab &&
          runtimeType == other.runtimeType &&
          tabId == other.tabId;

  @override
  int get hashCode => tabId.hashCode;
}

/// Tipos de pestañas disponibles
enum SaleOrderTabType {
  /// Listado de órdenes
  list,

  /// Vista de detalle (solo lectura)
  view,

  /// Edición de orden existente
  edit,

  /// Nueva orden
  newOrder,

  /// Vista previa de PDF
  pdfPreview,
}

/// Estado del sistema de pestañas
class SaleOrderTabsState {
  /// Lista de pestañas abiertas
  final List<SaleOrderTab> tabs;

  /// Índice de la pestaña activa
  final int currentIndex;

  const SaleOrderTabsState({
    required this.tabs,
    required this.currentIndex,
  });

  /// Estado inicial con solo el listado
  factory SaleOrderTabsState.initial() {
    return SaleOrderTabsState(
      tabs: [SaleOrderTab.list()],
      currentIndex: 0,
    );
  }

  /// Pestaña actualmente seleccionada
  SaleOrderTab? get currentTab =>
      currentIndex >= 0 && currentIndex < tabs.length
          ? tabs[currentIndex]
          : null;

  /// Verificar si una orden ya está abierta en alguna pestaña
  SaleOrderTab? findTabByOrderId(int orderId) {
    try {
      return tabs.firstWhere(
        (tab) => tab.orderId == orderId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Verificar si hay pestañas con cambios sin guardar
  bool get hasUnsavedChanges => tabs.any((tab) => tab.hasUnsavedChanges);

  SaleOrderTabsState copyWith({
    List<SaleOrderTab>? tabs,
    int? currentIndex,
  }) {
    return SaleOrderTabsState(
      tabs: tabs ?? this.tabs,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Notifier para manejar las pestañas de ventas
@Riverpod(keepAlive: true)
class SaleOrderTabs extends _$SaleOrderTabs {
  @override
  SaleOrderTabsState build() => SaleOrderTabsState.initial();

  /// Abrir una orden en una nueva pestaña (o activar si ya existe)
  void openOrder(int orderId, String orderName, {bool edit = false}) {
    // Buscar si ya existe una pestaña para esta orden
    final existingTab = state.findTabByOrderId(orderId);

    if (existingTab != null) {
      // Si existe, activar esa pestaña
      final index = state.tabs.indexOf(existingTab);

      // Si está pidiendo edición y la pestaña actual no está en edición,
      // actualizar la pestaña
      if (edit && !existingTab.isEditing) {
        final updatedTabs = List<SaleOrderTab>.from(state.tabs);
        updatedTabs[index] = existingTab.copyWith(isEditing: true);
        state = state.copyWith(tabs: updatedTabs, currentIndex: index);
      } else {
        state = state.copyWith(currentIndex: index);
      }
      return;
    }

    // Crear nueva pestaña
    final newTab = edit
        ? SaleOrderTab.edit(orderId, orderName)
        : SaleOrderTab.view(orderId, orderName);

    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(
      tabs: newTabs,
      currentIndex: newTabs.length - 1,
    );
  }

  /// Abrir pestaña para nueva orden
  void openNewOrder() {
    final newTab = SaleOrderTab.newOrder();
    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(
      tabs: newTabs,
      currentIndex: newTabs.length - 1,
    );
  }

  /// Abrir pestaña de vista previa de PDF (con datos listos)
  void openPdfPreview({
    required int orderId,
    required String orderName,
    required Uint8List pdfBytes,
    required String filename,
  }) {
    final newTab = SaleOrderTab.pdfPreview(
      orderId: orderId,
      orderName: orderName,
      pdfBytes: pdfBytes,
      filename: filename,
    );
    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(
      tabs: newTabs,
      currentIndex: newTabs.length - 1,
    );
  }

  /// Abrir pestaña de vista previa de PDF en estado de carga
  /// Retorna el tabId para poder actualizarlo después
  String openPdfPreviewLoading({
    required int orderId,
    required String orderName,
    required String filename,
  }) {
    final newTab = SaleOrderTab.pdfPreviewLoading(
      orderId: orderId,
      orderName: orderName,
      filename: filename,
    );
    final newTabs = [...state.tabs, newTab];
    state = state.copyWith(
      tabs: newTabs,
      currentIndex: newTabs.length - 1,
    );
    return newTab.tabId;
  }

  /// Actualizar pestaña de PDF con los bytes generados
  void updatePdfPreviewContent(String tabId, Uint8List pdfBytes) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      final updatedTabs = List<SaleOrderTab>.from(state.tabs);
      updatedTabs[index] = updatedTabs[index].copyWith(
        pdfBytes: pdfBytes,
        isPdfLoading: false,
        pdfError: null,
      );
      state = state.copyWith(tabs: updatedTabs);
    }
  }

  /// Marcar pestaña de PDF con error
  void setPdfPreviewError(String tabId, String error) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      final updatedTabs = List<SaleOrderTab>.from(state.tabs);
      updatedTabs[index] = updatedTabs[index].copyWith(
        isPdfLoading: false,
        pdfError: error,
      );
      state = state.copyWith(tabs: updatedTabs);
    }
  }

  /// Cerrar una pestaña por índice
  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;

    // No permitir cerrar la pestaña del listado
    if (state.tabs[index].type == SaleOrderTabType.list) return;

    final newTabs = List<SaleOrderTab>.from(state.tabs)..removeAt(index);

    // Ajustar el índice actual si es necesario
    int newIndex = state.currentIndex;
    if (index <= state.currentIndex) {
      newIndex = (state.currentIndex - 1).clamp(0, newTabs.length - 1);
    }

    state = state.copyWith(tabs: newTabs, currentIndex: newIndex);
  }

  /// Cerrar pestaña por tabId
  void closeTabById(String tabId) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      closeTab(index);
    }
  }

  /// Cambiar a una pestaña específica
  void setCurrentIndex(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  /// Ir a la pestaña del listado
  void goToList() {
    final listIndex = state.tabs.indexWhere(
      (tab) => tab.type == SaleOrderTabType.list,
    );
    if (listIndex != -1) {
      state = state.copyWith(currentIndex: listIndex);
    }
  }

  /// Actualizar el título de una pestaña (cuando la orden se guarda)
  void updateTabTitle(String tabId, String newTitle) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      final updatedTabs = List<SaleOrderTab>.from(state.tabs);
      updatedTabs[index] = updatedTabs[index].copyWith(title: newTitle);
      state = state.copyWith(tabs: updatedTabs);
    }
  }

  /// Marcar una pestaña como con/sin cambios
  void setUnsavedChanges(String tabId, bool hasChanges) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      final updatedTabs = List<SaleOrderTab>.from(state.tabs);
      updatedTabs[index] = updatedTabs[index].copyWith(
        hasUnsavedChanges: hasChanges,
      );
      state = state.copyWith(tabs: updatedTabs);
    }
  }

  /// Convertir pestaña de nueva orden a orden existente (después de guardar)
  void convertNewToExisting(String tabId, int orderId, String orderName) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      final updatedTabs = List<SaleOrderTab>.from(state.tabs);
      // Reemplazar con una pestaña de edición normal
      updatedTabs[index] = SaleOrderTab.edit(orderId, orderName);
      state = state.copyWith(tabs: updatedTabs);
    }
  }

  /// Cambiar modo de edición de una pestaña
  void setEditMode(String tabId, bool editing) {
    final index = state.tabs.indexWhere((tab) => tab.tabId == tabId);
    if (index != -1) {
      final updatedTabs = List<SaleOrderTab>.from(state.tabs);
      updatedTabs[index] = updatedTabs[index].copyWith(isEditing: editing);
      state = state.copyWith(tabs: updatedTabs);
    }
  }

  /// Cerrar todas las pestañas excepto el listado
  void closeAllTabs() {
    final listTab = state.tabs.firstWhere(
      (tab) => tab.type == SaleOrderTabType.list,
      orElse: () => SaleOrderTab.list(),
    );
    state = state.copyWith(tabs: [listTab], currentIndex: 0);
  }

  /// Cerrar la pestaña actual y volver al listado
  void closeCurrentTab() {
    if (state.currentTab == null) return;
    if (state.currentTab!.type == SaleOrderTabType.list) return;

    closeTab(state.currentIndex);
  }

  /// Cambiar pestaña actual de vista a edición (en lugar de abrir nueva)
  void switchCurrentToEdit() {
    if (state.currentTab == null) return;
    if (state.currentTab!.type == SaleOrderTabType.list) return;
    if (state.currentTab!.isEditing) return;

    final updatedTabs = List<SaleOrderTab>.from(state.tabs);
    updatedTabs[state.currentIndex] = state.currentTab!.copyWith(
      isEditing: true,
    );
    state = state.copyWith(tabs: updatedTabs);
  }

  /// Cambiar pestaña actual de edición a vista (después de guardar)
  void switchCurrentToView() {
    if (state.currentTab == null) return;
    if (state.currentTab!.type == SaleOrderTabType.list) return;
    if (!state.currentTab!.isEditing) return;

    final updatedTabs = List<SaleOrderTab>.from(state.tabs);
    updatedTabs[state.currentIndex] = state.currentTab!.copyWith(
      isEditing: false,
      hasUnsavedChanges: false,
    );
    state = state.copyWith(tabs: updatedTabs);
  }
}

