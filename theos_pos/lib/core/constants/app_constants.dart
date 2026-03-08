// Constantes de la aplicacion TheosPos
// Centraliza valores magicos y configuraciones reutilizables

/// Breakpoints de pantalla para responsive design
abstract class ScreenBreakpoints {
  /// Ancho maximo para considerar pantalla mobile
  static const double mobileMaxWidth = 600;

  /// Ancho para tablet pequeña (usado en grids de 2 columnas)
  static const double tabletSmallWidth = 900;

  /// Ancho maximo para considerar pantalla tablet
  static const double tabletMaxWidth = 1200;

  /// Ancho minimo de ventana en desktop
  static const double minWindowWidth = 500;

  /// Alto minimo de ventana en desktop
  static const double minWindowHeight = 600;

  /// Ancho por defecto de ventana
  static const double defaultWindowWidth = 1280;

  /// Alto por defecto de ventana
  static const double defaultWindowHeight = 720;
}

/// Constantes para tamaños de dialogos
abstract class DialogSizes {
  /// Dialogo pequeño (busqueda simple)
  static const double smallWidth = 500;
  static const double smallHeight = 400;

  /// Dialogo mediano (formularios)
  static const double mediumWidth = 600;
  static const double mediumHeight = 500;

  /// Dialogo grande (preferencias, info producto)
  static const double largeWidth = 700;
  static const double largeHeight = 600;

  /// Dialogo extra grande (configuraciones complejas)
  static const double xlargeWidth = 900;
  static const double xlargeHeight = 700;
}

/// Constantes para UI y notificaciones
abstract class UIConstants {
  /// Numero maximo de notificaciones a mostrar en badge
  static const int maxDisplayedNotifications = 99;

  /// Filas por defecto en grids de datos
  static const int defaultPageSize = 20;

  /// Filas por defecto en grid de ordenes de venta
  static const int saleOrdersPageSize = 80;

  /// Duracion por defecto de animaciones (ms)
  static const int defaultAnimationDuration = 200;

  /// Tiempo de debounce para busqueda (ms)
  static const int searchDebounceMs = 300;
}

/// Constantes de sincronizacion y red
abstract class SyncConstants {
  /// Reintentos maximos de sincronizacion por defecto
  static const int defaultMaxRetries = 3;

  /// Intervalo de polling de notificaciones (minutos)
  static const int notificationPollIntervalMinutes = 10;

  /// Timeout de conexion por defecto (segundos)
  static const int defaultConnectionTimeout = 30;

  /// Timeout de operaciones de lectura (segundos)
  static const int defaultReadTimeout = 60;
}

/// Constantes de formato
abstract class FormatConstants {
  /// Formato de fecha por defecto
  static const String defaultDateFormat = 'dd/MM/yyyy';

  /// Formato de fecha con hora
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  /// Formato de moneda
  static const String currencySymbol = r'$';

  /// Decimales para cantidades
  static const int quantityDecimals = 2;

  /// Decimales para precios
  static const int priceDecimals = 2;
}
