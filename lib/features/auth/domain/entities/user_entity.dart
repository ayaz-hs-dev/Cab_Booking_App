// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class UserEntity extends Equatable {
  final String? uid;
  final String? token;
  final String name;
  final String email;
  final String phone;
  final String? role;
  final bool? isOnline;
  final LatLng? currentLocation;

  const UserEntity({
    this.uid,
    this.token,
    required this.name,
    required this.email,
    required this.phone,
    this.role,
    this.isOnline,
    this.currentLocation,
  });

  @override
  List<Object?> get props => [
    uid,
    token,
    name,
    email,
    phone,
    role,
    isOnline,
    currentLocation,
  ];
}
