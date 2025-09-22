import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:taxi_app/features/passenger/data/data_sources/ride_data_source.dart';
import 'package:taxi_app/features/passenger/data/model/ride_model.dart';
import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/services/notification/firebase_messsaging_service.dart';

class RideDataSourceImpl implements RideDataSource {
  final FirebaseFirestore firestore;
  RideDataSourceImpl({required this.firestore});

  final String _ridesCollection = "rides";

  @override
  Future<String> createRide(RideEntity ride) async {
    try {
      final docRef = firestore.collection(_ridesCollection).doc();
      final rideModel = RideModel(
        rideId: docRef.id,
        passengerId: ride.passengerId,
        driverId: ride.driverId,
        pickupLocation: ride.pickupLocation,
        destinationLocation: ride.destinationLocation,
        status: ride.status,
        fare: ride.fare,
        createdAt: ride.createdAt,
        updatedAt: ride.updatedAt,
        polyline: ride.polyline, // Add polyline to model
        passengerName: ride.passengerName,
        distance: ride.distance,
      );
      await docRef.set(rideModel.toJson());
      debugPrint('✅ Ride created: ${rideModel.toJson()}');
      FCMService.sendNotification(
        ride.driverToken!,
        "New Ride Request",
        "Pickup ${ride.passengerName} at ${ride.pickupLocation.latitude}, ${ride.pickupLocation.longitude}",
      );
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating ride: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelRide(String rideId) async {
    await firestore.collection(_ridesCollection).doc(rideId).update({
      "status": "cancelled",
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignDriver(String rideId, String driverId) async {
    await firestore.collection(_ridesCollection).doc(rideId).update({
      "driverId": driverId,
      "status": "accepted",
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateRideStatus(String rideId, String status) async {
    await firestore.collection(_ridesCollection).doc(rideId).update({
      "status": status,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<RideEntity?> rideStream(String rideId) {
    try {
      return FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists) {
              return RideModel.fromJson(snapshot.data()!);
            }
            return null;
          })
          .handleError((e) {
            debugPrint("[RideStream] Error streaming ride: $e");
            throw e; // Ensure errors are propagated
          });
    } catch (e) {
      debugPrint("[RideStream] Error setting up stream: $e");
      return Stream.value(null);
    }
  }

  @override
  Future<RideEntity?> getRideById(String rideId) async {
    final doc = await firestore.collection(_ridesCollection).doc(rideId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return RideModel.fromJson({...data, 'rideId': doc.id});
  }

  @override
  Future<List<RideEntity>> getPassengerRides(String passengerId) async {
    final querySnapshot = await firestore
        .collection(_ridesCollection)
        .where('passengerId', isEqualTo: passengerId)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return RideModel.fromJson({...data, 'rideId': doc.id});
    }).toList();
  }

  @override
  Stream<List<RideEntity>> getDriverActiveRide(String driverId) {
    try {
      final driverRides = firestore
          .collection(_ridesCollection)
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['accepted', 'in_progress', 'pending'])
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs.map((doc) {
              final data = doc.data();
              return RideModel.fromJson({...data, 'rideId': doc.id});
            }).toList();
          });
      debugPrint('✅ Driver active ride fetched  $driverRides');
      return driverRides;
    } catch (e) {
      debugPrint('❌ Error getting driver active ride: $e');
      return Stream.value([]);
    }
  }

  @override
  Stream<List<RideEntity>> getAvailableRides() {
    try {
      final availableRides = firestore
          .collection(_ridesCollection)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs.map((doc) {
              final data = doc.data();
              return RideModel.fromJson({...data, 'rideId': doc.id});
            }).toList();
          });
      debugPrint('✅ Available rides fetched  $availableRides');
      return availableRides;
    } catch (e) {
      debugPrint('❌ Error getting available rides: $e');
      return Stream.value([]);
    }
  }
}
