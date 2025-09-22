import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';

abstract class RideRepository {
  /// Create a new ride request (passenger requesting a trip)
  Future<String> createRide(RideEntity ride);

  /// Cancel an existing ride
  Future<void> cancelRide(String rideId);

  /// Assign a driver to a ride (when a driver accepts)
  Future<void> assignDriver(String rideId, String driverId);

  /// Update ride status (pending, accepted, driver_arrived, on_trip, completed, cancelled)
  Future<void> updateRideStatus(String rideId, String status);

  /// Stream ride updates in real-time (passenger & driver both listen)
  Stream<RideEntity?> rideStream(String rideId);

  /// Get ride details by ID (single fetch, not stream)
  Future<RideEntity?> getRideById(String rideId);

  /// Get all rides for a specific passenger (history)
  Future<List<RideEntity>> getPassengerRides(String passengerId);

  /// Get all available rides
  Stream<List<RideEntity>> getAvailableRides();

  /// Get all rides for a specific driver (history)
  Stream<List<RideEntity>> getDriverActiveRide(String driverId);
}
