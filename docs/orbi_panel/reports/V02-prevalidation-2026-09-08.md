# V02 · prevalidación de plataformas

Estado: parcial; V02 depende de V01 y no se marca `done`.

Entorno: Flutter 3.47.1, Dart 3.13.1, macOS 15.6.1.

| Comprobación | Resultado | Tiempo / tamaño |
| --- | --- | --- |
| `flutter analyze` | PASS, 0 issues | 18,77 s |
| `flutter test test/ui` | PASS, 3 pruebas | 18,72 s |
| macOS release | PASS | 136,91 s · 61.353.006 bytes |
| iOS simulator debug | PASS | 32,80 s · 169.210.335 bytes |
| Web release `/orbi/` | PASS; desplegado y visible en ERP2 | JS principal 4.504.575 bytes |

El bundle que contiene los últimos ajustes del runtime de caja se integró en
Odoo mediante `38bc3fc46`. Su `main.dart.js` local y el asset preparado para
despliegue tenían SHA-256
`a6ec3826acf7fe7841bd26b9c0230fa20d7c058e94cfdb9d60395685d92de002`.
El despliegue terminó con RC 0, servicio activo, cero reinicios y HTTP 200.

La comprobación posterior abrió `https://erp2.tecnosmart.com.ec/orbi/` con una
sesión Odoo existente: título `Orbi ERP`, `flutter-view` montado y pantalla
visible con Ventas, Caja, Aprobaciones y Configuración. El navegador no expuso
los bytes autenticados del JS para calcular una segunda huella remota, por lo
que la correspondencia exacta se sustenta en la huella local/staged y el
despliegue del commit, no en una descarga remota independiente.

Windows y Linux sólo pueden certificarse en sus hosts. El build iOS debug no
equivale a release firmado ni a publicación. No se tocó `newerp`.
