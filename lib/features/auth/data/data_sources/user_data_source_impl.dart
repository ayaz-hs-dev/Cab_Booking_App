import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/data/model/user_model.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'user_data_source.dart';

class UserDataSourceImpl extends UserDataSource {
  final FirebaseFirestore fireStore;
  final FirebaseAuth auth;

  UserDataSourceImpl({required this.fireStore, required this.auth});

  final userCollection = FirebaseFirestore.instance.collection('users');

  String? currentUserId;
  String? currentUserToken;

  // ---------- 🔹 AUTH ----------
  @override
  Future<String> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    currentUserId = credential.user?.uid;
    return currentUserId!;
  }

  @override
  Future<UserEntity?> signInWithEmailAndPassword(
    String email,
    String password,
    String role,
  ) async {
    debugPrint('🔵 [UserDataSource] Signing in FirebaseAuth with $email');

    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    debugPrint('✅ [UserDataSource] FirebaseAuth success, UID: $uid');

    final doc = await userCollection.doc(uid).get();

    if (!doc.exists) {
      debugPrint('❌ [UserDataSource] No Firestore doc for UID: $uid');
      throw Exception('User not found in database');
    }

    final user = UserModel.fromJson(doc.data()!);
    debugPrint('✅ [UserDataSource] Firestore doc loaded: ${user.toJson()}');

    if (user.role != role) {
      debugPrint(
        '❌ [UserDataSource] Role mismatch. Expected $role but found ${user.role}',
      );
      await auth.signOut();
      throw Exception('Role mismatch: Expected $role, found ${user.role}');
    }

    debugPrint('✅ [UserDataSource] Role verified as $role');
    return user;
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    currentUserId = null;
    debugPrint('✅ Signed out successfully');
  }

  Future<String?> getCurrentUID() async => auth.currentUser?.uid;

  // ---------- 🔹 USER CRUD ----------
  @override
  Future<void> createUser(UserEntity user) async {
    if (currentUserId == null) {
      throw Exception('No authenticated user. Please sign in first.');
    }
    if (currentUserToken == null) {
      await getToken();
    }

    final userModel = UserModel(
      uid: currentUserId!,
      token: currentUserToken,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      isOnline: user.isOnline,
      currentLocation: user.currentLocation,
    );

    await userCollection.doc(userModel.uid).set(userModel.toJson());
    debugPrint('✅ User created in Firestore: ${userModel.toJson()}');
    if (currentUserId != null) {
      debugPrint('❌ updateUserLocation called with null/empty uid');
      return;
    }
    debugPrint(
      '🟢 updateUserLocation called with uid=$currentUserId, location=${user.currentLocation}',
    );
    final geoPoint = GeoFirePoint(
      GeoPoint(user.currentLocation!.latitude, user.currentLocation!.longitude),
    );
    await userCollection.doc(currentUserId).update({"geopoint": geoPoint.data});
  }

  Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        currentUserToken = token;
        debugPrint('✅ FCM Token retrieved: $token');
        return token;
      } else {
        throw Exception('Failed to retrieve FCM token');
      }
    } catch (e) {
      debugPrint('❌ Error retrieving FCM token: $e');
      throw Exception('Error retrieving FCM token: $e');
    }
  }

  @override
  Future<String> getCurrentUserId() async {
    return auth.currentUser!.uid;
  }

  @override
  Future<UserEntity?> getUserById(String uid) async {
    final doc = await userCollection.doc(uid).get();
    if (doc.exists) {
      debugPrint('✅ User fetched by ID: $uid');
      return UserModel.fromJson(doc.data()!);
    }
    debugPrint('❌ User not found by ID: $uid');
    return null;
  }

  @override
  Future<void> updateUser(UserEntity userEntity) async {
    if (userEntity.uid == null) {
      throw Exception('User UID cannot be null for update');
    }

    final userModel = UserModel(
      uid: userEntity.uid,
      token: currentUserToken,
      name: userEntity.name,
      email: userEntity.email,
      phone: userEntity.phone,
      role: userEntity.role,
      isOnline: userEntity.isOnline,
      currentLocation: userEntity.currentLocation,
    );

    await userCollection.doc(userModel.uid).update(userModel.toJson());
    debugPrint('✅ User updated: ${userModel.uid}');
  }

  @override
  Future<void> deleteUser(String uid) async {
    await userCollection.doc(uid).delete();
    await auth.currentUser?.delete();
    debugPrint('✅ User deleted: $uid');
  }

  @override
  Future<void> updateDriverStatus(String uid, bool isOnline) async {
    if (uid.isEmpty) {
      debugPrint('❌ updateDriverStatus called with null/empty uid');
      return;
    }
    debugPrint(
      '🟢 updateDriverStatus called with uid=$uid, isOnline=$isOnline',
    );
    await userCollection.doc(uid).update({'isOnline': isOnline});
  }

  @override
  Future<void> updateUserLocation(String uid, LatLng location) async {
    if (uid.isEmpty) {
      debugPrint('❌ updateUserLocation called with null/empty uid');
      return;
    }
    debugPrint(
      '🟢 updateUserLocation called with uid=$uid, location=$location',
    );
    final geoPoint = GeoFirePoint(
      GeoPoint(location.latitude, location.longitude),
    );
    await userCollection.doc(uid).update({"geopoint": geoPoint.data});
  }

  @override
  Stream<List<UserEntity>> getOnlineDrivers(LatLng center, double radiusInKm) {
    try {
      final geoFirePoint = GeoFirePoint(
        GeoPoint(center.latitude, center.longitude),
      );

      final geoCollectionRef = GeoCollectionReference(userCollection);

      debugPrint(
        '🔍 Geo stream center: ${center.latitude}, ${center.longitude}',
      );
      debugPrint('🔍 Radius: $radiusInKm km');

      // 🔥 Use streamWithin instead of fetchWithin
      final snapshots = geoCollectionRef.subscribeWithin(
        center: geoFirePoint,
        radiusInKm: radiusInKm,
        field: 'geopoint',
        geopointFrom: (data) {
          final raw = data['geopoint'];

          if (raw is GeoPoint) {
            return raw; // Legacy direct GeoPoint
          } else if (raw is Map<String, dynamic>) {
            final inner = raw['geopoint'];
            if (inner is GeoPoint) {
              return inner;
            }
          }

          debugPrint("❌ Could not parse geopoint from: $raw");
          throw Exception("Invalid geopoint format");
        },
      );

      // Map every incoming snapshot to your UserEntity list
      return snapshots.map((docs) {
        debugPrint('📦 Docs fetched (before filtering): ${docs.length}');
        for (final doc in docs) {
          debugPrint("➡️ Raw doc: ${doc.data()}");
        }

        final drivers = docs
            .map((doc) {
              final user = UserModel.fromJson(doc.data()!);
              return user;
            })
            .where((user) {
              final ok = user.role == 'driver' && (user.isOnline ?? false);
              debugPrint(
                "🔎 Checking ${user.name}, role=${user.role}, online=${user.isOnline} => $ok",
              );
              return ok;
            })
            .toList();

        debugPrint('✅ Online drivers found after filtering: ${drivers.length}');
        return drivers;
      });
    } catch (e, st) {
      debugPrint('❌ Error in driver stream: $e');
      debugPrint('Stacktrace: $st');
      // Use Stream.error to propagate errors
      return Stream.error('Failed to stream nearby drivers: $e');
    }
  }

  @override
  Stream<UserEntity> userStream(String uid) {
    return userCollection.doc(uid).snapshots().map((doc) {
      debugPrint('📡 User stream update for $uid');
      return UserModel.fromJson(doc.data()!);
    });
  }
}
