/// Enum to identify editable cell types for Tab navigation
enum EditableCellType { quantity, discount, name, code, other }

/// Result of product code search operation
enum ProductCodeSearchResult {
  /// Product found on existing line (had product before) - navigate to quantity
  successExistingLine,

  /// Product found on new/empty line - navigate to next line code
  successNewLine,

  /// No product found with the given code (0 matches)
  notFound,

  /// Multiple products found, user selected one from dialog - for existing line
  multipleSelectedExisting,

  /// Multiple products found, user selected one from dialog - for new line
  multipleSelectedNew,

  /// User cancelled the operation (Escape or dialog cancelled)
  cancelled,

  /// Code unchanged (same as current product code)
  unchanged,
}
