import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/data/data_sources/user_data_source.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserDataSource datataSource;

  UserRepositoryImpl({required this.datataSource});
  @override
  Future<void> createUser(UserEntity user) async {
    return await datataSource.createUser(user);
  }

  @override
  Future<void> deleteUser(String uid) async {
    return await datataSource.deleteUser(uid);
  }

  @override
  Stream<List<UserEntity>> getOnlineDrivers(LatLng center, double radiusInKm) {
    return datataSource.getOnlineDrivers(center, radiusInKm);
  }

  @override
  Future<UserEntity?> getUserById(String uid) async {
    return await datataSource.getUserById(uid);
  }

  @override
  Future<void> updateDriverStatus(String uid, bool isOnline) async {
    return datataSource.updateDriverStatus(uid, isOnline);
  }

  @override
  Future<void> updateUser(UserEntity user) async {
    return await datataSource.updateUser(user);
  }

  @override
  Future<void> updateUserLocation(String uid, LatLng location) async {
    return await datataSource.updateUserLocation(uid, location);
  }

  @override
  Stream<UserEntity> userStream(String uid) {
    return datataSource.userStream(uid);
  }

  @override
  Future<String> getCurrentUserId() async {
    return await datataSource.getCurrentUserId();
  }

  @override
  Future<UserEntity?> signInWithEmailAndPassword(
    String email,
    String password,
    String role,
  ) async {
    return await datataSource.signInWithEmailAndPassword(email, password, role);
  }

  @override
  Future<void> signOut() async {
    return await datataSource.signOut();
  }

  @override
  Future<String> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await datataSource.signUpWithEmailAndPassword(email, password);
  }
}
