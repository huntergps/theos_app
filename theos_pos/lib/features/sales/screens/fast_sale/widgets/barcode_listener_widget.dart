import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/services/platform/global_notification_service.dart';
import '../../../screens/fast_sale/fast_sale_providers.dart';
import '../../sale_order_form/edit_dialogs.dart';

// ---------------------------------------------------------------------------
// Constantes del detector de lector de código de barras
// ---------------------------------------------------------------------------

/// Tiempo máximo entre caracteres para considerarlos parte de un mismo escaneo.
/// Los lectores HID envían caracteres cada ~1-5ms; el usuario teclea >50ms/char.
const Duration _kBarcodeCharTimeout = Duration(milliseconds: 100);

/// Tiempo máximo total desde el primer carácter hasta Enter para detectar scanner.
/// Un lector de 13 dígitos (EAN-13) tarda típicamente 30-80ms en enviar todo.
const Duration _kBarcodeTotalTimeout = Duration(milliseconds: 500);

/// Número mínimo de caracteres para considerar que es un escaneo de barcode
/// y no escritura manual del usuario.
const int _kBarcodeMinLength = 6;

/// Caracteres válidos en un código de barras EAN/UPC/Code128/QR parcial.
/// Incluye alfanuméricos, guiones y asteriscos (Code39).
final RegExp _kBarcodeCharPattern = RegExp(r'[a-zA-Z0-9\-*]');

// ---------------------------------------------------------------------------
// Widget principal
// ---------------------------------------------------------------------------

/// Widget que envuelve el layout del FastSale y detecta lectores de código
/// de barras HID (USB/Bluetooth).
///
/// ## Funcionamiento
/// Los lectores de barras actúan como teclado HID: envían cada carácter del
/// código como evento de teclado muy rápido (1-5ms entre caracteres) seguido
/// de un Enter. Este widget mantiene un buffer con timestamps para distinguir
/// escritura manual (lenta) de escaneo (rápida).
///
/// ## Criterios de detección
/// 1. Se reciben [_kBarcodeMinLength]+ caracteres alfanuméricos
/// 2. Cada carácter llega en menos de [_kBarcodeCharTimeout] desde el anterior
/// 3. La secuencia termina con Enter o el timeout [_kBarcodeTotalTimeout]
///
/// ## Comportamiento al detectar barcode
/// - 1 producto encontrado → se agrega a la orden automáticamente
/// - 0 productos → se muestra el campo de búsqueda con el código
/// - Múltiples → se abre el diálogo de selección
///
/// ## Coexistencia con atajos de teclado
/// - Los atajos F1-F12 y Ctrl/Meta+tecla se manejan en [_FastSaleScreenState]
/// - Este widget solo intercepta secuencias puras alfanuméricas + Enter
/// - Si el usuario tiene foco en un TextBox, no interfiere (los eventos llegan
///   al TextBox primero y este widget solo actúa como respaldo)
class BarcodeListenerWidget extends ConsumerStatefulWidget {
  /// El contenido de la pantalla FastSale a envolver.
  final Widget child;

  const BarcodeListenerWidget({super.key, required this.child});

  @override
  ConsumerState<BarcodeListenerWidget> createState() =>
      _BarcodeListenerWidgetState();
}

class _BarcodeListenerWidgetState
    extends ConsumerState<BarcodeListenerWidget> {
  // Buffer de caracteres del escaneo en curso
  final StringBuffer _buffer = StringBuffer();

  // Timestamp del primer y último carácter recibido
  DateTime? _firstCharTime;
  DateTime? _lastCharTime;

  // Timer para limpiar el buffer si no llega Enter ni más caracteres
  Timer? _timeoutTimer;

  // Para evitar procesamiento doble
  bool _isProcessing = false;

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Manejo de eventos de teclado
  // ---------------------------------------------------------------------------

  /// Procesa cada evento de teclado buscando la secuencia de un scanner.
  ///
  /// Retorna [KeyEventResult.ignored] para todos los eventos que no son parte
  /// de un barcode, permitiendo que el árbol de widgets los maneje normalmente.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Solo procesamos KeyDownEvent
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Ignorar si hay un modificador activo (Ctrl, Meta, Alt) — son atajos
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    if (isCtrl || isMeta || isAlt) return KeyEventResult.ignored;

    // Ignorar teclas de función (F1-F12) — son atajos del POS
    if (_isFunctionKey(event.logicalKey)) return KeyEventResult.ignored;

    // Enter/NumpadEnter: posible fin de escaneo
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      return _handleEnterKey();
    }

    // Escape: limpiar buffer si hay uno en progreso
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_buffer.isNotEmpty) {
        _clearBuffer();
        return KeyEventResult.ignored;
      }
      return KeyEventResult.ignored;
    }

    // Backspace: limpiar buffer (el usuario está corrigiendo)
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _clearBuffer();
      return KeyEventResult.ignored;
    }

    // Obtener el carácter de texto del evento
    final char = _extractChar(event);
    if (char == null) {
      // Tecla no alfanumérica (flechas, Tab, etc.) → limpiar buffer
      if (_buffer.isNotEmpty) _clearBuffer();
      return KeyEventResult.ignored;
    }

    // Agregar al buffer y actualizar timestamps
    final now = DateTime.now();

    if (_buffer.isEmpty) {
      // Primer carácter del posible escaneo
      _firstCharTime = now;
      _lastCharTime = now;
      _buffer.write(char);
      _resetTimeoutTimer();
      // No consumir este evento — puede ser escritura normal también
      return KeyEventResult.ignored;
    }

    // Verificar que el carácter llegó dentro del timeout entre caracteres
    final elapsed = now.difference(_lastCharTime!);
    if (elapsed > _kBarcodeCharTimeout) {
      // Tardó demasiado — no es un scanner, reiniciar buffer
      _clearBuffer();
      _firstCharTime = now;
      _lastCharTime = now;
      _buffer.write(char);
      _resetTimeoutTimer();
      return KeyEventResult.ignored;
    }

    _lastCharTime = now;
    _buffer.write(char);
    _resetTimeoutTimer();

    return KeyEventResult.ignored;
  }

  /// Maneja la tecla Enter que puede finalizar un escaneo de barcode.
  KeyEventResult _handleEnterKey() {
    final code = _buffer.toString();
    // Capturar timestamps antes de limpiar el buffer
    final capturedFirst = _firstCharTime;
    final capturedLast = _lastCharTime;
    _clearBuffer();

    // Verificar mínimo de caracteres para ser un barcode
    if (code.length < _kBarcodeMinLength) {
      return KeyEventResult.ignored;
    }

    // Verificar que el tiempo total fue razonable para un scanner
    final totalTime = capturedFirst != null && capturedLast != null
        ? capturedLast.difference(capturedFirst)
        : Duration.zero;

    if (totalTime > _kBarcodeTotalTimeout) {
      // Tardó demasiado — era escritura manual del usuario en un TextBox
      return KeyEventResult.ignored;
    }

    // Verificar que no estamos ya procesando un escaneo
    if (_isProcessing) return KeyEventResult.ignored;

    // Verificar que hay una orden activa
    final activeTab = ref.read(fastSaleProvider).activeTab;
    if (activeTab == null) return KeyEventResult.ignored;

    // Procesar el barcode detectado
    _processBarcodeDetected(code);

    // Consumir el Enter para que no active otros handlers
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------------
  // Procesamiento del barcode
  // ---------------------------------------------------------------------------

  /// Procesa el código detectado: busca en Drift local y actúa según resultado.
  Future<void> _processBarcodeDetected(String code) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final notifier = ref.read(fastSaleProvider.notifier);
      final (result, matches) = await notifier.searchAndAddProductByCode(code);

      if (!mounted) return;

      switch (result) {
        case ProductSearchAddResult.success:
          // Producto encontrado y agregado — feedback visual de éxito
          ref
              .read(globalNotificationProvider)
              .showSuccess(
                context,
                title: 'Escaneado',
                message: 'Producto agregado',
                durationSeconds: 1,
              );

        case ProductSearchAddResult.incrementedQuantity:
          // Cantidad incrementada en línea existente
          ref
              .read(globalNotificationProvider)
              .showSuccess(
                context,
                title: 'Escaneado',
                message: 'Cantidad incrementada',
                durationSeconds: 1,
              );

        case ProductSearchAddResult.notFound:
          // No se encontró el producto — activar modo búsqueda con el código
          notifier.setInputMode(KeypadInputMode.search);
          notifier.setKeypadValue(code);
          requestSearchInputFocus();
          ref
              .read(globalNotificationProvider)
              .showWarning(
                context,
                title: 'Código no encontrado',
                message: code,
                durationSeconds: 3,
              );

        case ProductSearchAddResult.multipleMatches:
          // Múltiples productos — abrir diálogo de selección
          if (matches != null && matches.isNotEmpty && mounted) {
            final selected = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) =>
                  SelectProductDialog(initialSearch: code),
            );

            if (selected != null && mounted) {
              final quantity =
                  (matches.first['_quantity'] as num?)?.toDouble() ?? 1.0;
              final discount =
                  (matches.first['_discount'] as num?)?.toDouble() ?? 0.0;

              await notifier.addProduct(
                productId: selected['id'] as int,
                productName: selected['name'] as String? ?? '',
                productCode: selected['default_code'] as String?,
                quantity: quantity,
                priceUnit: (selected['list_price'] as num?)?.toDouble() ?? 0.0,
                discount: discount,
                uomId: selected['uom_id'] is List
                    ? (selected['uom_id'] as List)[0] as int
                    : selected['uom_id'] as int?,
                uomName: selected['uom_id'] is List
                    ? (selected['uom_id'] as List)[1] as String
                    : null,
                taxIds:
                    (selected['taxes_id'] as List<dynamic>?)?.cast<int>(),
              );

              if (mounted) {
                ref
                    .read(globalNotificationProvider)
                    .showSuccess(
                      context,
                      title: 'Escaneado',
                      message: selected['name'] as String? ?? 'Producto',
                      durationSeconds: 1,
                    );
              }
            }
          }

        case ProductSearchAddResult.cancelled:
          // Error interno — no hacer nada
          break;
      }
    } finally {
      _isProcessing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  /// Extrae el carácter alfanumérico de un evento de teclado.
  /// Retorna null si no es un carácter válido para barcode.
  String? _extractChar(KeyEvent event) {
    // Intentar obtener el carácter del campo keyLabel
    final label = event.character;
    if (label != null && label.length == 1 && _kBarcodeCharPattern.hasMatch(label)) {
      return label;
    }
    return null;
  }

  /// Verifica si una tecla es de función (F1-F24).
  bool _isFunctionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.f2 ||
        key == LogicalKeyboardKey.f3 ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.f6 ||
        key == LogicalKeyboardKey.f7 ||
        key == LogicalKeyboardKey.f8 ||
        key == LogicalKeyboardKey.f9 ||
        key == LogicalKeyboardKey.f10 ||
        key == LogicalKeyboardKey.f11 ||
        key == LogicalKeyboardKey.f12;
  }

  /// Reinicia el timer de timeout del buffer.
  void _resetTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_kBarcodeTotalTimeout, () {
      // Si llegaron suficientes caracteres pero no Enter, intentar procesar
      // (algunos lectores no envían Enter en ciertos modos de configuración)
      final code = _buffer.toString();
      _clearBuffer();
      if (code.length >= _kBarcodeMinLength) {
        _processBarcodeDetected(code);
      }
    });
  }

  /// Limpia el buffer y los timestamps.
  void _clearBuffer() {
    _timeoutTimer?.cancel();
    _buffer.clear();
    _firstCharTime = null;
    _lastCharTime = null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Usamos un Focus con onKeyEvent a nivel global de la pantalla.
    // skipTraversal=true para no interferir con la navegación por Tab.
    // canRequestFocus=false para no robar el foco de otros widgets.
    return Focus(
      onKeyEvent: _onKeyEvent,
      skipTraversal: true,
      canRequestFocus: false,
      child: widget.child,
    );
  }
}
