/// Cómo se dicen en voz alta los estados internos.
///
/// 🔴 Existe porque el nombre de un `enum` acababa impreso tal cual en la
/// pantalla: «Resultado: queued», «Cobro: synced», «Turno: open», «Estado
/// fiscal: emittedLocal». Son identificadores de código, en inglés, delante de
/// alguien que está cobrando en un mostrador.
///
/// Es el mismo defecto que el dueño reportó del acceso —volcar lo interno en
/// vez de explicar— sólo que en Caja, en Ventas y en Aprobaciones. Y era peor
/// ahí, porque un mensaje de acceso al menos se lee una vez: un estado se lee
/// todo el día.
///
/// Reglas que siguen estas etiquetas:
///
/// * **Dicen qué pasó, no cómo lo llamamos.** «Guardado en este dispositivo»
///   en lugar de `localOnly`.
/// * **No prometen más de lo que hay.** `queued` no es «enviado»: es «en
///   espera de enviarse», y esa diferencia es dinero.
/// * **`ambiguous` y `conflict` no se disfrazan.** Cuando de verdad no
///   sabemos si algo llegó, decirlo es la única opción honesta — y es
///   exactamente el caso que la cola offline trata como
///   `manual_after_ambiguous` para no duplicar un cobro.
/// * Español ecuatoriano, tuteo, sin jerga.
///
/// Todas son funciones puras y totales: un valor nuevo del `enum` rompe la
/// compilación aquí en vez de escaparse a la pantalla.
library;

import 'package:orbi_runtime/orbi_runtime.dart'
    show
        FiscalState,
        OperationSyncState,
        SaleApprovalState,
        SaleTermsClassification;

import '../features/approvals/approval_contracts.dart' show ApprovalTerms;
import '../features/collection/collection_contracts.dart'
    show CollectionResultState, CollectionShiftState;


/// Resultado de una acción de cobro.
String collectionResultLabel(CollectionResultState state) => switch (state) {
  CollectionResultState.local => 'Guardado en este dispositivo',
  // Nunca «enviado»: todavía no ha salido.
  CollectionResultState.queued => 'En espera de enviarse',
  // El caso que no se disfraza. Ver la cola durable: `manual_after_ambiguous`
  // existe precisamente para que nadie cobre dos veces por esto.
  CollectionResultState.ambiguous =>
    'Revísalo antes de volver a cobrar: no sabemos si llegó al servidor',
  CollectionResultState.synced => 'Enviado y confirmado',
  CollectionResultState.conflict => 'En conflicto con el servidor',
};

/// Estado del turno de caja.
///
/// Los tres estados intermedios importan: «abriéndose» y «cerrándose» son
/// momentos en que la operación salió pero aún no volvió, y llamarlos
/// «abierto» o «cerrado» adelantaría un hecho que todavía no ocurrió.
String shiftStateLabel(CollectionShiftState state) => switch (state) {
  CollectionShiftState.opening => 'abriéndose',
  CollectionShiftState.opened => 'abierto',
  CollectionShiftState.closing => 'cerrándose',
  CollectionShiftState.closed => 'cerrado',
  CollectionShiftState.conflict => 'en conflicto con el servidor',
};

/// Estado de sincronización de un documento.
String syncStateLabel(OperationSyncState state) => switch (state) {
  OperationSyncState.localOnly => 'Sólo en este dispositivo',
  OperationSyncState.queued => 'En espera de enviarse',
  OperationSyncState.sending => 'Enviándose',
  OperationSyncState.synced => 'Enviado y confirmado',
  OperationSyncState.conflict => 'En conflicto con el servidor',
  OperationSyncState.failed => 'No se pudo enviar',
};

/// Estado fiscal, que es independiente del transporte: un documento puede
/// estar enviado y todavía no autorizado.
String fiscalStateLabel(FiscalState state) => switch (state) {
  FiscalState.emittedLocal => 'Emitido en este dispositivo',
  FiscalState.submitted => 'Enviado al SRI',
  FiscalState.authorized => 'Autorizado',
  FiscalState.rejected => 'Rechazado por el SRI',
};

/// El mismo estado fiscal cuando puede no haber ninguno, que no es lo mismo
/// que uno vacío: significa que este documento no requiere trámite fiscal.
String fiscalStateLabelOrNone(FiscalState? state) =>
    state == null ? 'No requiere trámite fiscal' : fiscalStateLabel(state);

/// Cómo se pactó el pago, tal como lo ve una aprobación.
String approvalTermsLabel(ApprovalTerms terms) => switch (terms) {
  ApprovalTerms.cash => 'contado',
  ApprovalTerms.credit => 'crédito',
  ApprovalTerms.mixed => 'mixto',
};

/// Cómo se pactó el pago.
String termsClassificationLabel(SaleTermsClassification terms) =>
    switch (terms) {
      SaleTermsClassification.cash => 'contado',
      SaleTermsClassification.credit => 'crédito',
      SaleTermsClassification.mixed => 'mixto',
    };

/// Estado de una aprobación comercial.
String approvalStateLabel(SaleApprovalState state) => switch (state) {
  SaleApprovalState.required => 'Necesita aprobación',
  SaleApprovalState.pending => 'Esperando aprobación',
  SaleApprovalState.approved => 'Aprobada',
  SaleApprovalState.rejected => 'Rechazada',
};

/// Cómo se llama en castellano el trabajo de sincronización que falló.
///
/// El identificador que usa el runtime (`catalog:cardBrand`) es un nombre de
/// programador y no puede llegar a la pantalla. Cuando aparezca un catálogo
/// nuevo sin traducir, se devuelve el identificador tal cual: es feo a
/// propósito, para que se note y se traduzca, en vez de esconder el fallo.
String syncJobLabel(String jobId) {
  const catalogs = <String, String>{
    'partner': 'Clientes',
    'product': 'Productos',
    'paymentTerm': 'Formas de pago',
    'uom': 'Unidades de medida',
    'collectionConfig': 'Puntos de cobro',
    'collectionSession': 'Sesiones de caja',
    'tax': 'Impuestos',
    'pricelist': 'Listas de precios',
    'warehouse': 'Bodegas',
    'journal': 'Diarios',
    'cardBrand': 'Marcas de tarjeta',
    'cardDeadline': 'Plazos de tarjeta',
    'cardLote': 'Lotes de tarjeta',
    'paymentMethodLine': 'Métodos de pago',
  };
  if (jobId == 'operations') return 'Trabajo pendiente por enviar';
  if (jobId == 'backend-probe') return 'Comprobación del servidor';
  const prefix = 'catalog:';
  if (jobId.startsWith(prefix)) {
    final key = jobId.substring(prefix.length);
    return catalogs[key] ?? jobId;
  }
  return jobId;
}
