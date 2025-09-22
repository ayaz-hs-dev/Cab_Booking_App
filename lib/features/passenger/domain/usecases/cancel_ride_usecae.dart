import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class CancelRideUsecae {
  final RideRepository rideRepository;
  CancelRideUsecae({required this.rideRepository});
  Future<void> call(String rideId) async =>
      await rideRepository.cancelRide(rideId);
}
