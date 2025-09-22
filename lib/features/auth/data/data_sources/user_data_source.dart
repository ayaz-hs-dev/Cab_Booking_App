import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';

abstract class UserDataSource {
  //-----Auth-----
  Future<String> signUpWithEmailAndPassword(String email, String password);
  Future<UserEntity?> signInWithEmailAndPassword(
    String email,
    String password,
    String role,
  );
  Future<void> signOut();
  Future<String> getCurrentUserId();

  //-----User-----

  /// Create a new user (driver or passenger)
  Future<void> createUser(UserEntity user);

  /// Get user by UID
  Future<UserEntity?> getUserById(String uid);

  /// Update user information
  Future<void> updateUser(UserEntity user);

  /// Delete user
  Future<void> deleteUser(String uid);

  /// Update driver's online status
  Future<void> updateDriverStatus(String uid, bool isOnline);

  /// Update user's current location
  Future<void> updateUserLocation(String uid, LatLng location);

  /// Get all drivers currently online (for passengers)
  Stream<List<UserEntity>> getOnlineDrivers(LatLng center, double radiusInKm);

  /// Stream user changes in real-time
  Stream<UserEntity> userStream(String uid);
}
