part of 'offline_sync_service.dart';

/// Sync de res.partner creado offline: create con chequeo de VAT único,
/// y la cascada de reemplazo de ID negativo -> real en dependientes.
extension _OfflineSyncPartner on OfflineSyncService {
  // =========================================================================
  // RES.PARTNER SYNC HANDLERS
  // =========================================================================

  /// Process res.partner CREATE operation
  ///
  /// Values expected:
  /// - local_id: int (negative ID)
  /// - partner_uuid: String
  /// - name: String
  /// - vat: String?
  /// - email: String?
  /// - phone: String?
  /// - mobile: String?
  /// - street: String?
  /// - city: String?
  /// - country_id: int?
  ///
  /// VAT Uniqueness Check:
  /// Before creating in Odoo, checks if a partner with the same VAT already exists.
  /// If found, links to existing partner instead of creating a duplicate.
  /// This replicates l10n_ec_base._check_vat_uniqueness behavior.
  Future<void> _processPartnerCreate(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final partnerUuid = op.values['partner_uuid'] as String?;
    final vat = op.values['vat'] as String?;

    logger.d(
      '[OfflineSyncService]',
      'Processing partner create: uuid=$partnerUuid, localId=$localId, vat=$vat',
    );

    // Check if partner with same VAT already exists in Odoo
    // This handles the case where:
    // - Partner was created offline with VAT "1234567890001"
    // - While offline, someone else created the same partner in Odoo
    // - When syncing, we should link to existing instead of failing with duplicate VAT error
    if (vat != null && vat.isNotEmpty) {
      try {
        final existingInOdoo = await _odooClient!.searchRead(
          model: 'res.partner',
          domain: [
            ['vat', '=', vat],
          ],
          fields: ['id', 'name'],
          limit: 1,
        );

        if (existingInOdoo.isNotEmpty) {
          final existingId = existingInOdoo[0]['id'] as int;
          final existingName = existingInOdoo[0]['name'] as String?;

          logger.d(
            '[OfflineSyncService]',
            'Partner with VAT $vat already exists in Odoo: id=$existingId, name=$existingName. '
                'Linking to existing instead of creating.',
          );

          // Update local partner with existing Odoo ID
          if (partnerUuid != null) {
            await clientManager.updatePartnerIdByUuid(partnerUuid, existingId);
            logger.d(
              '[OfflineSyncService]',
              'Linked local partner (uuid=$partnerUuid) to existing Odoo partner: $existingId',
            );
          }

          // Propagate the real Odoo ID to any local record / queued
          // operation that still references the negative local ID (ver
          // _cascadePartnerIdReplacement). Sin esto, una orden ya creada
          // para este cliente offline queda con partner_id negativo para
          // siempre y su propio sync falla de forma permanente.
          if (localId != null) {
            await _cascadePartnerIdReplacement(localId, existingId);
          }

          // Success - no need to create, partner already exists
          return;
        }
      } catch (e) {
        logger.w(
          '[OfflineSyncService]',
          'Could not check VAT existence in Odoo, proceeding with create: $e',
        );
        // Continue with create attempt - Odoo will validate
      }
    }

    // Build Odoo values
    final odooValues = <String, dynamic>{'name': op.values['name']};

    if (vat != null) {
      odooValues['vat'] = vat;
    }
    if (op.values['email'] != null) {
      odooValues['email'] = op.values['email'];
    }
    if (op.values['phone'] != null) {
      odooValues['phone'] = op.values['phone'];
    }
    if (op.values['mobile'] != null) {
      odooValues['mobile'] = op.values['mobile'];
    }
    if (op.values['street'] != null) {
      odooValues['street'] = op.values['street'];
    }
    if (op.values['city'] != null) {
      odooValues['city'] = op.values['city'];
    }
    if (op.values['country_id'] != null) {
      odooValues['country_id'] = op.values['country_id'];
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating res.partner: uuid=$partnerUuid, localId=$localId',
    );

    final remoteId = await _odooClient!.create(
      model: 'res.partner',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create res.partner - returned null');
    }

    logger.d('[OfflineSyncService]', 'Partner created: $remoteId');

    // Update local partner with remote ID
    if (localId != null && partnerUuid != null) {
      await clientManager.updatePartnerIdByUuid(partnerUuid, remoteId);
      logger.d(
        '[OfflineSyncService]',
        'Updated local partner $localId -> $remoteId',
      );
    }

    // Propagate the real Odoo ID to dependent local records / queued ops.
    if (localId != null) {
      await _cascadePartnerIdReplacement(localId, remoteId);
    }
  }

  /// Propaga el ID real de un partner recién sincronizado a todo lo que
  /// todavía referencia su ID negativo local: registros locales
  /// (`sale_order.partner_id`, `account_payment.partner_id`) y operaciones
  /// YA encoladas cuyo payload JSON aún tiene el ID viejo.
  ///
  /// Antes de este fix, solo `sale.order` ↔ `sale.order.line` tenían este
  /// reemplazo de ID (ver `updateOrderIdInPendingOperations`). Un cliente
  /// creado offline con una orden ya asociada quedaba con `partner_id`
  /// negativo para siempre porque nadie propagaba el ID real — el create de
  /// la orden fallaba permanentemente en Odoo (ID de partner inválido).
  Future<void> _cascadePartnerIdReplacement(
    int oldPartnerId,
    int newPartnerId,
  ) async {
    await clientManager.updatePartnerIdInDependents(oldPartnerId, newPartnerId);
    final updatedOps = await _offlineQueue.updatePartnerIdInPendingOperations(
      oldPartnerId,
      newPartnerId,
    );
    if (updatedOps > 0) {
      logger.d(
        '[OfflineSyncService]',
        'Partner $oldPartnerId -> $newPartnerId: $updatedOps operación(es) '
            'en cola actualizadas con el ID real',
      );
    }
  }
}
