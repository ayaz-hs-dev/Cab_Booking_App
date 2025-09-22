// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:latlong2/latlong.dart';

class RideEntity {
  final String? rideId;
  final String? driverId;
  final String? driverToken;
  final String passengerId;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? fare;
  final List<LatLng>? polyline; // Add polyline field
  final String? passengerName;
  final String? distance;

  const RideEntity({
    this.rideId,
    this.driverId,
    this.driverToken,
    required this.passengerId,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.fare,
    this.polyline,
    this.passengerName,
    this.distance,
  });
}
