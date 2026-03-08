/// Lifecycle state of a [DataContext].
enum ContextState {
  /// Context created but not yet initialized.
  created,

  /// Context fully initialized and ready for use.
  initialized,

  /// Context disposed — all resources released.
  disposed,
}
