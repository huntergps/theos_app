# V02 · prevalidación de plataformas

Estado: parcial; V02 depende de V01 y no se marca `done`.

Entorno: Flutter 3.47.1, Dart 3.13.1, macOS 15.6.1.

| Comprobación | Resultado | Tiempo / tamaño |
| --- | --- | --- |
| `flutter analyze` | PASS, 0 issues | 18,77 s |
| `flutter test test/ui` | PASS, 3 pruebas | 18,72 s |
| macOS release | PASS | 136,91 s · 61.353.006 bytes |
| iOS simulator debug | PASS | 32,80 s · 169.210.335 bytes |
| Web release `/orbi/` | desplegado y visible en ERP2 | 47 MB; JS principal 4.501.137 bytes |

La recarga web reutilizó la sesión Odoo same-origin y montó un `flutter-view`.
Windows y Linux sólo pueden certificarse en sus hosts. El build iOS debug no
equivale a release firmado ni a publicación. No se tocó `newerp`.
