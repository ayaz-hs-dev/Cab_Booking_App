import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.token,
    required super.name,
    required super.email,
    required super.phone,
    required super.role,
    required super.isOnline,
    super.currentLocation,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    LatLng? latLng;

    final geo = json['geopoint'];

    if (geo is GeoPoint) {
      // Case 1: directly stored as GeoPoint
      latLng = LatLng(geo.latitude, geo.longitude);
    } else if (geo is Map<String, dynamic>) {
      // Case 2: stored as {geohash, geopoint}
      final innerGeo = geo['geopoint'];
      if (innerGeo is GeoPoint) {
        latLng = LatLng(innerGeo.latitude, innerGeo.longitude);
      }
    }

    return UserModel(
      uid: json['uid'] ?? '',
      token: json['token'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      isOnline: json['isOnline'] ?? false,
      currentLocation: latLng,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'uid': uid,
      'token': token,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isOnline': isOnline,
    };

    if (currentLocation != null) {
      // Save as plain GeoPoint
      map['geopoint'] = GeoPoint(
        currentLocation!.latitude,
        currentLocation!.longitude,
      );
    }

    return map;
  }
}
