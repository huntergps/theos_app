/// Hands [WorkspaceUnlockStore] the platform's own durable store, picked at
/// COMPILE time rather than with a `kIsWeb` branch: the web implementation
/// imports `dart:js_interop`, which does not compile for the VM or for any
/// native target, and the native one imports `flutter_secure_storage`, whose
/// web build is the very thing W04 rejects.
///
/// Both platforms persist — that is the owner's decision of 11-sep-2026,
/// «yo he dicho que navegador también guarda igual que escritorio», recorded
/// in `docs/orbi_panel/decisions/W04-el-navegador-tambien-guarda.md`. "Igual
/// que escritorio" means equivalent in guarantee, not identical in mechanism:
/// the desktop has the operating system's keychain, the browser has a
/// non-extractable AES-GCM key that the page's own code can use but cannot
/// read.
library;

export 'unlock_backend_factory_io.dart'
    if (dart.library.js_interop) 'unlock_backend_factory_web.dart';
