# Verificación proporcionada y evidencia

## Niveles distintos

- Plan: referencias, dependencias y criterios coherentes.
- Código: análisis y pruebas focales de una implementación.
- Integración: componentes y servicios realmente conectados.
- Plataforma: compilación y comportamiento del binario en ese SO/navegador.
- ERP2: efectos cotejados por identidad/IDs/totales/estados reales.

Ningún nivel sustituye al siguiente. No marcar tareas terminadas porque compilan
stubs, porque HTTP devuelve 200 o porque el agente declara «todo verde».

## Comandos previstos

Los comandos de app/runtime requieren que F01 haya creado los paquetes. Registrar
SDK (`flutter --version`), comando exacto, salida final y entorno de cada ejecución.

```bash
python3 scripts/check_orbi_plan.py
python3 scripts/check_orbi_plan.py --ready
git diff --check

cd theos_panel
flutter pub get
flutter analyze
flutter test test/ui
flutter run -d macos
flutter run -d chrome
flutter run --profile -d 00008112-001268903A06601E
```

Comandos independientes desde raíz:

```bash
(cd orbi_runtime && flutter analyze)
(cd orbi_runtime && flutter test)
(cd theos_pos_core && dart analyze)
(cd theos_pos_core && dart test)
(cd odoo_sdk && dart analyze)
(cd odoo_sdk && dart test)
(cd theos_panel && flutter test integration_test/orbi_erp2_test.dart -d macos)
```

`integration_test/orbi_erp2_test.dart` es entregable de V01, no existe aún. Debe
rechazar ejecución sin destino de pruebas explícito y credenciales externas;
no descargar claves de documentos ni incluirlas en argumentos/logs.

Builds por host apropiado, desde `theos_panel`:

```bash
flutter build web --release
flutter build appbundle --release
flutter build ios --release --no-codesign
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

Windows se construye en Windows; Linux en Linux; iOS/macOS en macOS. Android/web
en host con herramientas disponibles. Build unsigned no equivale a instalación
firmada ni a publicación. W01 debe resolverse antes de certificar acceso web final.

## Pruebas mínimas por riesgo

| Cambio | Evidencia mínima |
| --- | --- |
| Tokens, márgenes, copy | Análisis y revisión visual; no nueva suite trivial |
| Campo reactivo/layout | Foco, validación dependiente, tamaño y edición conservada |
| Extracción de servicio | Pruebas existentes pertinentes + consumidores adaptados |
| Sesión/DB | Cambio de scope, rollback, reinicio, teardown y respuesta tardía |
| Inbox | Dedupe, revisión, persistencia, permisos y lease de entrega |
| Pagos/cola/fiscalidad | Atomicidad local, respuesta ambigua, concurrencia, replay, contrato real |
| Paquete compartido integrado | Suite del paquete y regresión relevante de theos_pos |

No ejecutar suite total después de cada ajuste de color. Tras cambios compartidos
finales, el integrador ejecuta las suites afectadas una vez; reabre si hay cambios
o fallos nuevos. F01 debe ampliar CI para incluir los paquetes nuevos: el Makefile
actual solo incluye cinco y no puede certificar Orbi por omisión.

## Matriz funcional obligatoria ERP2

Cada fila debe registrar actor real, configuración, pasos, resultado esperado,
resultado observado, IDs y evidencia independiente de servidor. Nunca secretos.

| Caso | Online | Offline + reinicio + replay |
| --- | --- | --- |
| Crédito puro | Aprobación, cupo/mora, bloqueo, factura/despacho | Política local provisionada y reconciliación |
| Contado | Cobro crea factura/despacho | Cobro local durable, identidad fiscal preservada |
| Mixto | is_cash e is_credit, factura al confirmar, despacho explícito | Reglas de vencimiento preservadas |
| FSC | Solicitar/aprobar, factura/despacho, entrega bloqueada sin pago | Autoridad local documentada; conciliar aprobación/entrega |
| Turno completo | Abrir, cobrar, movimientos, contar, cerrar | Persistir turno/movimientos/cierre y conflictos |
| Sin panel | Contrato base disponible | Sin dependencia indirecta de collection.panel |
| Con panel | Extensiones compatibles | Mismos candados y sin doble lógica |

Pruebas negativas: rol vendedor intenta caja, sesión ajena/cerrada, aprobación
pendiente/rechazada, cambio de compañía, doble toque, timeout después de commit
remoto, reconexión intermitente, reinicio durante envío y entrega FSC impagada.
Verificar que preparar bodega sigue permitido donde corresponda.

## Plataformas y rendimiento

Probar al menos ventanas de 360, 768, 1024 y 1440 dp; teclado visible; claro/oscuro;
texto ampliado; rotación/split view sin perder borradores. Teclado, ratón y lector
de códigos tipo teclado deben usar las mismas acciones autorizadas.

En cada SO: login/restore, consulta local, operación offline, reinicio, sync,
documento y aviso SO. En web sumar refresh, origen/almacenamiento, recursos offline,
permisos de notificación y CORS. En Windows verificar empaquetado de notificaciones.

Objetivos de ingeniería provisionales, no resultados medidos: búsqueda local
p95 <=300 ms sobre catálogo representativo documentado; actualización visible de
edición <=100 ms excluyendo debounce; frames UI/raster p95 dentro de 16.7 ms en
objetivo de 60 Hz durante scroll del recorrido seleccionado. Registrar hardware,
volumen, build y muestras. Ajustar presupuesto solo con evidencia del integrador.
Medir arranque frío/caliente, memoria, tamaño de artefacto y tamaño instalado por
plataforma. No comparar debug con release ni atribuir todo el peso a Fluent.

## Evidencia de finalización

Cada tarea entrega `reports/<ID>.md` desde REPORT_TEMPLATE.md. Solo el integrador
marca `done` después de comprobar diff, comandos y límites. `blocked` requiere
motivo y dependencia explícitos. Un archivo de informe no demuestra por sí mismo
que los comandos se ejecutaron; verificar logs/resultados indicados.

Producción (`newerp`) excluida. ERP2 admite pruebas previamente autorizadas dentro
del alcance; no usar la cuenta admin para demostrar permisos de vendedor/cajero.
Cambios de módulos/reglas/permisos no se deducen de una autorización genérica de UI.
