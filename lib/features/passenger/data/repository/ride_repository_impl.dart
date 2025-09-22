import 'package:taxi_app/features/passenger/data/data_sources/ride_data_source.dart';
import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class RideRepositoryImpl implements RideRepository {
  final RideDataSource dataSource;

  RideRepositoryImpl({required this.dataSource});
  @override
  Future<void> assignDriver(String rideId, String driverId) async {
    return await dataSource.assignDriver(rideId, driverId);
  }

  @override
  Future<void> cancelRide(String rideId) async {
    return await dataSource.cancelRide(rideId);
  }

  @override
  Future<String> createRide(RideEntity ride) async {
    return await dataSource.createRide(ride);
  }

  @override
  Future<List<RideEntity>> getPassengerRides(String passengerId) async {
    return await dataSource.getPassengerRides(passengerId);
  }

  @override
  Future<RideEntity?> getRideById(String rideId) async {
    return await dataSource.getRideById(rideId);
  }

  @override
  Stream<RideEntity?> rideStream(String rideId) {
    return dataSource.rideStream(rideId);
  }

  @override
  Future<void> updateRideStatus(String rideId, String status) async {
    return await dataSource.updateRideStatus(rideId, status);
  }

  @override
  Stream<List<RideEntity>> getDriverActiveRide(String driverId) {
    return dataSource.getDriverActiveRide(driverId);
  }

  @override
  Stream<List<RideEntity>> getAvailableRides() {
    return dataSource.getAvailableRides();
  }
}
