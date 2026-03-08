/// Core errors module - re-exports from odoo_offline_core
library;

export 'package:odoo_sdk/odoo_sdk.dart'
    show
        // Exceptions
        AppException,
        ServerException,
        NetworkException,
        CacheException,
        AuthException,
        ValidationException,
        NotFoundException,
        SyncException,
        // Failures
        Failure,
        ServerFailure,
        NetworkFailure,
        CacheFailure,
        AuthFailure,
        ValidationFailure,
        NotFoundFailure,
        SyncFailure,
        OfflineFailure;
