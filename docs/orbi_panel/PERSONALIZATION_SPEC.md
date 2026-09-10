# Personalización y tema compartido de Orbi

Estado: definición de producto, no implementación. Decisión del dueño: Orbi también
permite personalizar; sólo lo no personalizado hereda de Odoo.

## 1. Resolución por propiedad

`valor efectivo = personalización Orbi válida ?? valor Odoo disponible ?? valor Orbi predeterminado`

Se aplica individualmente a logo, fondo de acceso, textos configurables, colores de
marca/acento y familia tipográfica, en la medida en que su binding real los soporte.
Personalizar el acento no deja de heredar la fuente, logo o fondo. No copiar toda la
configuración remota a un perfil local como si el usuario la hubiese personalizado.

Conservar por propiedad: modo heredar/personalizado, valor local cuando corresponde,
valor remoto observado, revisión/procedencia y último valor efectivo válido. Son
conceptos de diseño, no nombres de tablas/campos Odoo nuevos.

| Caso | Resultado |
|---|---|
| Sin personalización local, Odoo define acento | Hereda acento de Odoo |
| Usuario cambia sólo acento | Usa acento local y sigue heredando el resto |
| Odoo actualiza fuente | Cambia la fuente heredada, no la personalizada |
| «Usar configuración de Odoo» en acento | Quita override de acento; resuelve Odoo o predeterminado |
| Restaurar todas las propiedades | Confirmación explícita; elimina sólo overrides de apariencia del contexto actual |
| Falta la propiedad remota | Valor predeterminado de Orbi, sin inventar un valor Odoo |
| Error al descargar configuración | Conserva última referencia válida; no interpreta fallo como eliminación remota |

Desactivar un fondo deliberadamente es distinto de «no personalizado»: si se ofrece
esa opción, debe representarse como valor local explícito, no como null heredable.
Un valor inválido no se acepta silenciosamente como personalización correcta.

## 2. Pantalla de ajustes

Sección Apariencia con vista previa y origen visible junto a cada propiedad:
«Personalizado en Orbi», «Heredado de Odoo» o «Predeterminado de Orbi».
Acciones por propiedad: personalizar y usar configuración de Odoo. Restauración
global es secundaria y no borra credenciales, borradores, datos ni colas.

Claro/oscuro/sistema es una preferencia de presentación, no otro juego de pantallas.
No asumir que Odoo expone una preferencia equivalente sin verificarla. Donde no
exista binding remoto se ofrece preferencia local con predeterminado documentado.
La vista previa no cambia la identidad del documento ni el foco de edición activo.

Las preferencias son de Orbi: guardarlas **no modifica Odoo**. Compartirlas entre
equipos requiere un contrato explícito futuro; persistencia local no implica sincronía
automática de preferencias con otros dispositivos.

## 3. Contexto, login y offline

Preferencias por usuario y contexto servidor/BD/empresa. En un equipo compartido,
cambiar de usuario retira su apariencia privada y carga la del siguiente contexto
autorizado; no hereda las elecciones del usuario anterior accidentalmente.

Antes de autenticar, sólo usar branding público de Odoo si existe un mecanismo real
y seguro que lo entregue, o identidad predeterminada/caché pública del servidor.
No exponer assets/textos privados ni descargar configuración mediante credenciales
de otro usuario. Si hay varias empresas, no adivinar su branding antes de resolver
la empresa autorizada. El alcance de personalización prelogin por equipo es un binding
por definir, no una excepción implícita al aislamiento de usuarios.

Offline conserva overrides y última configuración válida disponible, con procedencia
y antigüedad. Actualización remota refresca propiedades heredadas sin pisar overrides.
Cambio de servidor/BD nunca reutiliza URLs privadas o branding de otra organización.
Una respuesta tardía del contexto anterior se descarta de la vista.

## 4. Sistema de tema, no rediseño por pantalla

Un único conjunto de colores semánticos: superficies, texto sobre cada superficie,
bordes, selección, foco, controles y estados. Claro/oscuro resuelven esos roles con
valores adecuados. Marca y acento no deben teñir indiscriminadamente todas las superficies.
Éxito, advertencia, error y conflicto conservan significado, icono y texto además del color.

El tema existente de Orbi ya usa ThemeData/ColorScheme. Adaptarlo centralmente,
sin estilos paralelos ni colores hardcodeados en cada pantalla. Componentes propios
y rejillas Syncfusion deben mapearse a los mismos roles mediante su tema correspondiente.
No asumir que un paquete de tema configura automáticamente todos los widgets externos.

Paquetes evaluados, sin instalar: `flex_color_scheme` para tema Material centralizado;
`flex_seed_scheme` como alternativa de generación de paleta; `flex_color_picker`
opcional para elección del usuario. No agregar los tres por defecto ni fijar versiones
sin contrastar SDK y dependencias. Selección técnica recomendada, no instalación aprobada.

Fuentes: mapear la familia configurada a assets/font files compatibles y autorizados;
respetar licencia, carga, caché y fallback. No ejecutar CSS/HTML/JavaScript remoto
como configuración Flutter. Error de fuente conserva legibilidad y explica fallback
en ajustes; nunca bloquear login o venta por un recurso decorativo que no descargó.

Validar valores y contraste antes de aplicar: una elección de marca no garantiza
contraste en todos los estados. Si un recurso falla, mostrar alternativa y permitir
corregir sin perder la personalización almacenada.

## 5. Validación visual proporcionada

**No se requiere una imagen oscura por pantalla ni por tamaño.** Una lámina de
componentes comparativa y dos o tres pantallas representativas bastan para revisar
la propuesta de tema. Las imágenes nuevas se justifican cuando cambia distribución
o aparece una interacción que no se haya revisado.

La futura implementación sí se prueba en ambos temas y cuatro tamaños, sin convertir
cada combinación de prueba en un PNG adicional que deba aprobar el dueño.
Las imágenes oscuras ya generadas no sustituyen ni amplían automáticamente las
aprobaciones; conservarlas como exploración, no exigir revisar todas.

## 6. Escenarios de aceptación (no ejecutados)

1. Override sólo de acento; actualizar fuente Odoo → acento local y fuente nueva.
2. Quitar override → recupera valor Odoo; si no existe, predeterminado.
3. Cambiar A→B→A → preferencias aisladas y recuperables; ningún dato privado prelogin.
4. Reiniciar offline → misma apariencia válida y origen de valores conservado.
5. Timeout remoto → no borra configuración; cambio real/remoto eliminado se distingue.
6. Fuente/fondo inaccesible → fallback útil, sin bloquear trabajo ni falso éxito.
7. Alternar claro/oscuro/sistema → misma edición, selección, foco y dimensiones de tarea.
8. Intentar color ilegible → validación/ajuste informado, estados aún distinguibles.
9. Guardar ajustes Orbi → ningún write de configuración Odoo.
10. Cambiar servidor durante descarga → resultado anterior no se aplica al nuevo.

## 7. Contrato encontrado en el código Odoo

La inspección local encontró `res.company.pos_app_branding(known_checksums=None)`:
entrega tema y recursos de login con checksums, sujeto a acceso de lectura y empresa
permitida. No es una API anónima ni se verificó instalado en ERP2. El transporte se
validará en una base de prueba; no inventar una ruta `/orbi/branding`.

En ese código los colores se leen de parámetros globales; logo, fondo y título de
login pertenecen a la compañía. Conservar esos alcances de origen aunque las
preferencias locales se aíslen por usuario/servidor/BD/empresa.

El binding entrega tamaño base de texto, pero no una familia tipográfica configurable.
Poppins aparece como recurso fijo de `base_gpstech`. La herencia de familia sigue siendo
un requisito condicionado a encontrar o ampliar el contrato real, no una capacidad ya
demostrada. El login web personalizado tampoco demuestra acceso prelogin al método.

Estos hallazgos no cambian la prioridad: el valor remoto sólo se aplica cuando esa
propiedad no tiene personalización válida en Orbi.

## Referencias

- [Bindings inspeccionados en código Odoo; instalación por verificar](ODOO_BRANDING_BINDINGS.md).
- [FlexColorScheme](https://pub.dev/packages/flex_color_scheme).
- [FlexSeedScheme](https://pub.dev/packages/flex_seed_scheme).
- [FlexColorPicker](https://pub.dev/packages/flex_color_picker).
