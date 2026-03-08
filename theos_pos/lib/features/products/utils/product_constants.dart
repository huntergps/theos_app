// Product-related constants and utilities

/// Default limit for product searches
const int kProductSearchLimit = 20;

/// Default page size for product pagination
const int kProductPageSize = 50;

/// Cache TTL for product data (in hours)
const int kProductCacheTtlHours = 24;

/// Product type labels (Spanish)
const Map<String, String> kProductTypeLabels = {
  'consu': 'Consumible',
  'service': 'Servicio',
  'product': 'Almacenable',
};

/// Stock status labels (Spanish)
const Map<String, String> kStockStatusLabels = {
  'available': 'Disponible',
  'low': 'Bajo stock',
  'out': 'Sin stock',
};

/// Tracking type labels (Spanish)
const Map<String, String> kTrackingTypeLabels = {
  'none': 'Sin seguimiento',
  'serial': 'Por número de serie',
  'lot': 'Por lote',
};
