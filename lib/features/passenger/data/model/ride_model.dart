import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';

class RideModel extends RideEntity {
  const RideModel({
    required super.passengerId,
    required super.pickupLocation,
    required super.destinationLocation,
    required super.status,
    super.driverId,
    super.driverToken,
    super.fare,
    super.rideId,
    required super.createdAt,
    super.updatedAt,
    super.polyline,
    super.passengerName,
    super.distance,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      passengerId: json['passengerId'],
      pickupLocation: LatLng(
        json['pickupLocation']['latitude'],
        json['pickupLocation']['longitude'],
      ),
      destinationLocation: LatLng(
        json['destinationLocation']['latitude'],
        json['destinationLocation']['longitude'],
      ),
      status: json['status'],
      driverId: json['driverId'],
      driverToken: json['driverToken'],
      fare: (json['fare'] as num?)!.toDouble(),
      rideId: json['rideId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt']
              is Timestamp // Check if updatedAt is a Timestamp.
          ? (json['updatedAt'] as Timestamp)
                .toDate() // Convert Timestamp to DateTime.
          : json['updatedAt'] !=
                null // Handle string or null case.
          ? DateTime.parse(
              json['updatedAt'] as String,
            ) // Parse string to DateTime.
          : null, // Set to null if not provided.
      polyline: json['polyline'] != null
          ? (json['polyline'] as List)
                .map<LatLng>((p) => LatLng(p['lat'], p['lng']))
                .toList()
          : null,
      distance: json['distance'],
      passengerName: json['passengerName'],
    );
  }

  Map<String, dynamic> toJson() => {
    'passengerId': passengerId,
    'pickupLocation': {
      'latitude': pickupLocation.latitude,
      'longitude': pickupLocation.longitude,
    },
    'destinationLocation': {
      'latitude': destinationLocation.latitude,
      'longitude': destinationLocation.longitude,
    },
    'status': status,
    'driverId': driverId,
    'driverToken': driverToken,
    'fare': fare,
    'rideId': rideId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),

    'polyline': polyline!
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'distance': distance,
    'passengerName': passengerName,
  };
}
