# Coherencia de las pantallas aprobadas

Regla confirmada con el usuario el 2026-09-11. Complementa las imágenes;
no las reemplaza ni implica que la implementación ya tenga paridad visual.

- Un único tema, tipografía, escala de espaciado, botones y estados semánticos.
- Una estructura compartida de navegación, cabecera y contexto inferior,
  tomando `visual_baselines/approved/round-03/SHELL-01.png` como referencia.
- Rejillas Syncfusion en escritorio/tablet horizontal; listas y formularios
  en tablet vertical/teléfono. La búsqueda de nuevas líneas permanece inline.
- Ventas, Caja, Bodega y Envases conservan su organización funcional propia.
  Unificar componentes no significa forzar el mismo formulario a cada tarea.
- Mantener permisos efectivos conjuntos; no simular opciones ni datos para
  parecerse a una captura. Lo desconocido debe distinguirse de cero/vacío.
- Las aprobaciones conservan funciones, contenido y decisiones de interacción.
  Diferencias menores de estilo se normalizan mediante componentes compartidos.
- Contradicciones de flujo, acciones o distribución importante se muestran al
  usuario antes de elegir. Una imagen posterior no anula por sí sola otra.
- Registrar por pantalla: imagen de referencia, componente utilizado, captura
  implementada en cuatro tamaños, diferencias y estado de revisión.
- No modificar archivos de imágenes aprobadas. Una captura de pruebas técnicas
  no se registra como aprobación visual ni como prueba financiera completa.

Estado: integración de estructura común en curso; no paridad global acreditada.

## Orden de implementación confirmado

El usuario reitera el 2026-09-11 que se debe comenzar por **splash, login y
shell**, revisados como una única experiencia. No continuar refinando pantallas
de negocio antes de consolidar esa base. Referencias: ACC-01 y SHELL-01.
Conservar los cambios de negocio ya realizados sin declararlos aprobados.

La comprobación conjunta debe cubrir marca, fondo, tema claro/oscuro, tipografía,
anchos, espaciados, campos, botones, foco y transición, en los cuatro tamaños.
La fotografía del acceso y la estructura operativa del shell tienen funciones
distintas; compartir identidad no implica usar fotografía detrás de las rejillas.
ACC-02/PIN es otro flujo funcional: no simularlo con un login sin autorización.
