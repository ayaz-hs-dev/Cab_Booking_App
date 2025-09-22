import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class RideStreamUsecase {
  final RideRepository rideRepository;
  RideStreamUsecase({required this.rideRepository});
  Stream<RideEntity?> call(String rideId) => rideRepository.rideStream(rideId);
}
