import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class AssignDriverUsecase {
  final RideRepository rideRepository;
  AssignDriverUsecase({required this.rideRepository});
  Future<void> call(String driverId, String rideId) async {
    await rideRepository.assignDriver(rideId, driverId);
  }
}
