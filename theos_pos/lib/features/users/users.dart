/// Users feature module
///
/// Centralizes all user-related functionality.
/// Follows the same pattern as clients feature.
///
/// **Models:**
/// - [User] - Freezed model wrapping ResUsersData
///
/// **Repository:**
/// - [UserRepository] - Offline-first repository for users
/// - [UserSyncRepository] - Sync repository for users
///
/// **Providers:**
/// - [userProvider] - Current user state
/// - [userRepositoryProvider] - Repository instance
library;

export 'repositories/repositories.dart';
