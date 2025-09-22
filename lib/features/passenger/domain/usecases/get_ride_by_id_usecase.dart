import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class GetRideByIdUsecase {
  final RideRepository rideRepository;

  GetRideByIdUsecase({required this.rideRepository});
  Future<RideEntity?> call(String rideId) async =>
      await rideRepository.getRideById(rideId);
}
