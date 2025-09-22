import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class UpdateRideStatusUsecase {
  final RideRepository rideRepository;
  UpdateRideStatusUsecase({required this.rideRepository});
  Future<void> call(String rideId, String status) async =>
      await rideRepository.updateRideStatus(rideId, status);
}
