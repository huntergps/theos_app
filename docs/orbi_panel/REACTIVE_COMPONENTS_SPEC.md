# Componentes Orbi reactivos al núcleo offline

Estado: decisiones funcionales incorporadas de la conversación y propuesta de
arquitectura. No implementación, instalación de paquetes ni pruebas ejecutadas.
Los nombres de componentes y bindings siguientes son propuestos, no APIs existentes.

## 1. Contrato principal

Widgets → acciones del núcleo → persistencia local → estado observable → widgets.
El núcleo coordina sincronización con Odoo, que mantiene autoridad sobre permisos,
reglas y documentos. Riverpod conecta la presentación al estado; no sustituye la
base persistente ni es una cola durable. Cerrar un widget no elimina una operación.

La UI no ejecuta SQL, no modifica tablas arbitrariamente, no llama directamente a
Odoo y no calcula una autorización por el nombre del rol. Solicita acciones tipadas.
Guardado local, pendiente de envío, confirmado remoto, rechazado, conflicto y
resultado incierto se distinguen. Estado comercial, fiscal y de sincronización
no se colapsan en un único indicador verde.

Los controles básicos reciben valores/callbacks o bindings; adaptadores conectados
al núcleo los hacen reactivos. No es obligatorio que cada widget sea ConsumerWidget.
Preferir composición de controles Flutter/Syncfusion a heredar sus implementaciones
o modificar fuentes externas. Usar el tema para estilos simples sin crear un wrapper
por cada control estándar. Extraer un componente cuando comparte comportamiento,
contrato de interacción o composición relevante entre pantallas.

## 2. Enlace sencillo y tipado a datos locales

Tres responsabilidades separadas:

| Capa | Contrato |
|---|---|
| Repositorio observable | Consultas locales filtradas por contexto, IDs estables, paginación y cambios |
| Controlador de registro/formulario | Edición, validación, borrador, comandos de guardado y resultado |
| Campo enlazado | Valor, editable/lectura, errores, cambio, aplicación y estado visible |

Ejemplo conceptual: `OrbiQuantityField(binding: lineForm.quantity)`.
No repetir nombres de columnas como strings ni suscripciones SQL por pantalla.
El adaptador de datos conoce el modelo; el widget no necesita conocer tabla, URL,
credenciales, transporte ni esquema de sincronización.

El binding debe distinguir valor persistido de texto en edición, vacío de cero,
precisión y formato local de representación. Cantidades e importes no comparten
automáticamente precisión ni reglas. La validación de campo no sustituye validación
del documento o servidor. Cliente/producto relacionado mantiene ID y etiqueta juntos.

Cabecera y líneas requieren guardado consistente según la operación; una acción
confirmada no se transforma en edición libre por usar el mismo formulario.
Aplicar un cambio al núcleo puede ser explícito, al salir del campo o según contrato
del formulario; no persistir un importe incompleto en cada tecla indiscriminadamente.

## 3. Reactividad sin perder trabajo

- Observar sólo el estado necesario; actualización de una imagen no reconstruye
  toda la orden. Riverpod `select` puede acotar suscripciones cuando sea útil.
- Mantener controllers de edición/foco con ciclo de vida estable; no recrearlos
  durante build, cambios de tema o adaptación de tamaño.
- Las respuestas tardías se comparan con identidad de consulta/documento/contexto;
  no reemplazan la selección nueva ni una edición activa.
- El borrador durable pertenece al núcleo. Cursor, composición de teclado y foco
  son estado de presentación, no tablas de negocio ni providers globales obligatorios.
- Liberar suscripciones y recursos cuando termina su ámbito; autoDispose no debe
  destruir datos pendientes. No usar ref/BuildContext desmontado tras await.
- No notificar, imprimir, enviar mensajes ni registrar operaciones como efecto
  de build. Una actualización de estado no equivale a nueva intención del usuario.
- Aislar servidor/BD/empresa/usuario; cambiar de persona no reasigna autoría ni
  permite sincronizar bajo otra identidad sin contrato autorizado.

`reactive_forms` puede administrar controles y validación de formulario; Riverpod
estado de aplicación y comandos. No mantener dos copias editables independientes
del mismo dato. La estrategia de puente y resolución de cambios debe probarse.
Code generation de providers es recomendable si encaja con el proyecto; confirmar
API y versiones resueltas antes de adoptar ejemplos. No se añade dependencia aquí.

## 4. Catálogo de componentes por familia

| Familia | Reutilizar | Mantener específico |
|---|---|---|
| Acceso | Campos, errores, identidad visual y estado de acceso | Workspace/PIN, credenciales y límites de sesión |
| Shell | Menú por capacidades, cabecera, pie técnico y pestañas | Punto/sesión de Caja y contextos permitidos |
| Listados | Consulta observable, filtros, selección, paginación, retorno | Columnas, acciones y permisos de cada entidad |
| Ventas | Selector de cliente, editor de líneas, ficha producto, totales | Recorrido mostrador/consultiva y confirmación comercial |
| Caja | Campos monetarios, referencias, detalle de documento y resultado | Cobro, retención, anticipo, depósito, salida, cruce y cierre |
| Bodega | Líneas de cantidad, origen/destino, parciales y escaneo | Preparar, entregar, recibir, transferir y contar |
| Envases | Líneas múltiples, presentaciones, trazabilidad y dashboard | Propiedad/custodia, contenido, tránsito y diferencias |
| Aprobaciones | Bandeja, detalle, motivo y auditoría | Resoluciones autorizadas de Odoo |
| Sync | Progreso, operación pendiente, comparación de conflicto | Resolución específica; nunca merge universal de cantidades |
| Ajustes | Secciones, controles, vista previa y origen del valor | Apariencia, seguridad y configuración operacional |
| Avisos/salidas/IA | Centro de actividades, panel adaptable, resultado | Canales y acciones existentes autorizados en Odoo |

No construir un formulario financiero universal ni un widget que conoce todas
las tablas. Reutilizar presentación no significa compartir efectos de negocio.
Indicadores de dashboard derivan de consultas consistentes y abren ese mismo detalle;
no sumar unidades incompatibles ni crear saldos editables en la UI.

## 5. Rejillas y adaptación

Usar un adaptador Orbi sobre Syncfusion para escritorio e iPad horizontal:
columnas tipadas, celdas, selección, edición, ordenamiento, paginación y preferencias
por contexto. No reimplementar el motor de rejilla. Su licencia y versión siguen
requiriendo verificación antes de implementación/distribución.

En iPad vertical y teléfono usar listas/tarjetas/formularios, sin rejillas comprimidas.
Compartir controlador, consulta, acciones y validación entre ambas presentaciones;
no forzar mismo árbol visual. Producto se busca dentro de la línea de alta de la
rejilla, o del editor de ítem compacto, no en una barra externa de búsqueda de líneas.
Los listados de documentos sí tienen filtros y búsqueda propios.

Pie persistente wide: servidor, BD, hora recibida del servidor, conexión y sync
separadas. Compacto: indicador que abre detalle. No sustituir hora remota por reloj
local sin identificación. Tema centralizado con herencia por propiedad descrita en
[Personalización](PERSONALIZATION_SPEC.md), no imágenes oscuras por cada pantalla.

## 6. Imágenes de productos y clientes

`OrbiProductImage` y `OrbiCustomerAvatar` comparten un recurso visual con referencia
tipada al registro/imagen. El núcleo resuelve recurso local/remoto, versión y permisos.

- Caché persistente offline, miniaturas para listas y detalle bajo demanda.
- Carga diferida, descargas deduplicadas y actualización reactiva al cambiar versión.
- Distinguir sin imagen, no descargada, cargando y error; iniciales para clientes
  e icono para productos, con alternativa accesible.
- Aislar recursos privados por contexto autorizado. Caché no concede permisos.
- Ver/ampliar y cambiar/quitar son capacidades distintas.

### Cambiar o quitar desde Orbi

1. Ofrecer acción sólo según capacidad efectiva; Odoo vuelve a validar al ejecutar.
2. Elegir archivo o cámara si plataforma/permisos del dispositivo lo permiten.
3. Vista previa y validación de tipo admitido, tamaño y resolución. Límites concretos
   provienen del contrato real; no inventar compatibilidad universal de formatos.
4. Guardar blob y referencia local de forma recuperable antes de indicar «guardado».
   Archivo temporal o caché evictable no basta para una modificación pendiente.
5. Reflejar cambio local reactivamente con «pendiente» si la operación offline está
   autorizada. Si no lo está, informar que requiere conexión antes de prometer guardado.
6. Sincronizar por acción del núcleo; quitar requiere confirmación y conserva
   intención de eliminación distinta de fallo de descarga o ausencia de caché.
7. Rechazo/revocación de permiso o cambio remoto concurrente: conservar propuesta
   local protegida y mostrar resolución autorizada, sin sobrescribir silenciosamente.

La transferencia fallida puede reintentarse con identidad estable. Limpieza de caché
no borra archivos pendientes. Fallo de disco no produce falso éxito; reinicio permite
recuperar operación. No incluir imágenes privadas ni credenciales en logs/avisos OS.
Campo Odoo real, transporte, revisión y capacidad de detectar conflicto requieren
binding confirmado; no presuponer `image_1920` para cualquier modelo.

## 7. Aceptación futura, no ejecutada

| ID | Evidencia requerida |
|---|---|
| RC01 | Editar cantidad offline actualiza línea/totales sin perder foco; reinicio recupera borrador |
| RC02 | Cambio local y sync remoto distinguen persistencia, rechazo, conflicto e incertidumbre |
| RC03 | Cambio de tema/tamaño conserva registro, campo, selección y texto incompleto |
| RC04 | Respuesta tardía no pisa otra consulta/edición ni atraviesa cambio de usuario |
| RC05 | Mismo listado usa rejilla wide y tarjetas compactas con idénticos permisos/filtros |
| RC06 | Imagen cacheada visible offline; descarga actualiza sólo consumidores correspondientes |
| RC07 | Cambiar imagen autorizado, reiniciar sin red y sincronizar preserva archivo e intención |
| RC08 | Quitar con confirmación; cancelar no cambia datos; rechazo no simula éxito remoto |
| RC09 | Permiso revocado o imagen remota cambiada muestra resolución sin sobrescritura silenciosa |
| RC10 | Archivo inválido, disco lleno y limpieza de caché no pierden propuestas pendientes |
| RC11 | Cambio de usuario/empresa/BD no expone archivos privados ni reasigna operaciones |
| RC12 | Doble acción/reintento no duplica efecto; UI no escribe tablas de hechos validados |

Medir reactividad y consumo en app ejecutada, no afirmar rendimiento por contar
providers. Reutilizar [contrato de entrada](KEYBOARD_AND_INPUT_CONTRACT.md) y
[escenarios por familia](INTERACTION_ACCEPTANCE_SPEC.md).

## Referencias de arquitectura

- [Flutter: composición](https://docs.flutter.dev/resources/architectural-overview).
- [Riverpod: estado efímero](https://riverpod.dev/docs/root/do_dont).
- [Reactive Forms](https://pub.dev/packages/reactive_forms).
