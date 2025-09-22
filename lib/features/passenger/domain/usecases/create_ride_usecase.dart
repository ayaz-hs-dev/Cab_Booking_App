import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class CreateRideUsecase {
  final RideRepository rideRepository;
  CreateRideUsecase({required this.rideRepository});
  Future<String> call(RideEntity ride) async =>
      await rideRepository.createRide(ride);
}
